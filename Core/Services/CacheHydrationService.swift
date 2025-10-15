import Foundation
import SwiftData
import Combine

/// Service for one-way hydration from Firestore to SwiftData cache
///
/// Key Principles:
/// - ONE-WAY ONLY: Firestore → SwiftData (never the reverse)
/// - DISPOSABLE: Cache can be cleared/rebuilt anytime
/// - REAL-TIME: Uses Firestore snapshot listeners
/// - AUTOMATIC: Starts on init, stops on deinit
///
/// Usage:
/// ```swift
/// let hydrationService = CacheHydrationService.shared
/// // Automatically starts hydrating on init
/// ```
@MainActor
class CacheHydrationService: ObservableObject {
    // MARK: - Singleton
    
    static let shared = CacheHydrationService()
    
    // MARK: - Published State
    
    @Published private(set) var isHydrating: Bool = false
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var cacheStatus: CacheStatus = .empty
    
    enum CacheStatus {
        case empty
        case hydrating
        case synced
        case error(String)
    }
    
    // MARK: - Dependencies
    
    private let repository: FirestoreRepository
    private let modelContainer: ModelContainer
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        repository: FirestoreRepository? = nil,
        modelContainer: ModelContainer? = nil
    ) {
        self.repository = repository ?? FirestoreRepository.shared
        
        // Create cache container with specific schema
        do {
            let schema = Schema([
                HabitCache.self,
                CompletionCache.self,
                StreakCache.self,
                XPStateCache.self,
                CacheMetadata.self
            ])
            
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none  // ✅ No CloudKit for cache
            )
            
            self.modelContainer = try modelContainer ?? ModelContainer(
                for: schema,
                configurations: [config]
            )
            
            print("✅ CacheHydrationService: Initialized with dedicated cache container")
            
            // Start hydration
            startHydration()
            
        } catch {
            print("❌ CacheHydrationService: Failed to create cache container: \(error)")
            self.modelContainer = SwiftDataContainer.shared.modelContainer
            self.cacheStatus = .error("Failed to initialize: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Clear all cache data (cache is disposable)
    func clearCache() async throws {
        let context = ModelContext(modelContainer)
        
        // Delete all cached data
        try context.delete(model: HabitCache.self)
        try context.delete(model: CompletionCache.self)
        try context.delete(model: StreakCache.self)
        try context.delete(model: XPStateCache.self)
        
        try context.save()
        
        print("🗑️ CacheHydrationService: Cache cleared")
        cacheStatus = .empty
    }
    
    /// Force full re-sync
    func forceSync() async throws {
        try await clearCache()
        startHydration()
    }
    
    // MARK: - Private Methods - Hydration
    
    private func startHydration() {
        print("🔄 CacheHydrationService: Starting cache hydration...")
        cacheStatus = .hydrating
        isHydrating = true
        
        // Listen to habits
        hydrateHabits()
        
        // Listen to completions (today only for performance)
        hydrateCompletions()
        
        // Listen to streaks
        hydrateStreaks()
        
        // Listen to XP state
        hydrateXPState()
    }
    
    private func hydrateHabits() {
        repository.$habits
            .receive(on: DispatchQueue.main)
            .sink { [weak self] firestoreHabits in
                Task { @MainActor in
                    // Convert FirestoreHabit to Habit for cache
                    let habits = firestoreHabits.map { $0.toHabit() }
                    await self?.updateHabitsCache(habits)
                }
            }
            .store(in: &cancellables)
    }
    
    private func hydrateCompletions() {
        // Listen to today's completions for performance
        repository.$completions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completions in
                Task { @MainActor in
                    let dateFormatter = LocalDateFormatter()
                    let today = dateFormatter.dateToString(dateFormatter.todayDate())
                    await self?.updateCompletionsCache(localDate: today, completions: completions)
                }
            }
            .store(in: &cancellables)
    }
    
    private func hydrateStreaks() {
        repository.$streaks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] streaks in
                Task { @MainActor in
                    await self?.updateStreaksCache(streaks)
                }
            }
            .store(in: &cancellables)
    }
    
    private func hydrateXPState() {
        repository.$xpState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] xpState in
                Task { @MainActor in
                    await self?.updateXPStateCache(xpState)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Private Methods - Cache Updates
    
    private func updateHabitsCache(_ habits: [Habit]) async {
        let context = ModelContext(modelContainer)
        
        do {
            // Get existing cache
            let existingIds = try context.fetch(FetchDescriptor<HabitCache>()).map { $0.id }
            
            // Update or insert habits
            for habit in habits {
                if let existing = try context.fetch(
                    FetchDescriptor<HabitCache>(
                        predicate: #Predicate { $0.id == habit.id }
                    )
                ).first {
                    // Update existing
                    existing.name = habit.name
                    existing.color = habit.color
                    existing.type = habit.type
                    existing.active = habit.active
                    existing.lastSyncedAt = Date()
                } else {
                    // Insert new
                    let cached = HabitCache.from(habit)
                    context.insert(cached)
                }
            }
            
            // Remove deleted habits
            let currentIds = Set(habits.map { $0.id })
            for existingId in existingIds where !currentIds.contains(existingId) {
                if let toDelete = try context.fetch(
                    FetchDescriptor<HabitCache>(
                        predicate: #Predicate { $0.id == existingId }
                    )
                ).first {
                    context.delete(toDelete)
                }
            }
            
            try context.save()
            
            print("✅ CacheHydrationService: Hydrated \(habits.count) habits")
            updateSyncStatus()
            
        } catch {
            print("❌ CacheHydrationService: Failed to hydrate habits: \(error)")
            cacheStatus = .error(error.localizedDescription)
        }
    }
    
    private func updateCompletionsCache(localDate: String, completions: [String: Completion]) async {
        let context = ModelContext(modelContainer)
        
        do {
            for (habitId, completion) in completions {
                if let existing = try context.fetch(
                    FetchDescriptor<CompletionCache>(
                        predicate: #Predicate { 
                            $0.habitId == habitId && $0.localDate == localDate 
                        }
                    )
                ).first {
                    // Update existing
                    existing.count = completion.count
                    existing.lastSyncedAt = Date()
                } else {
                    // Insert new
                    let cached = CompletionCache.from(
                        habitId: habitId,
                        localDate: localDate,
                        completion: completion
                    )
                    context.insert(cached)
                }
            }
            
            try context.save()
            
            print("✅ CacheHydrationService: Hydrated \(completions.count) completions for \(localDate)")
            updateSyncStatus()
            
        } catch {
            print("❌ CacheHydrationService: Failed to hydrate completions: \(error)")
        }
    }
    
    private func updateStreaksCache(_ streaks: [String: Streak]) async {
        let context = ModelContext(modelContainer)
        
        do {
            for (habitId, streak) in streaks {
                if let existing = try context.fetch(
                    FetchDescriptor<StreakCache>(
                        predicate: #Predicate { $0.habitId == habitId }
                    )
                ).first {
                    // Update existing
                    existing.current = streak.current
                    existing.longest = streak.longest
                    existing.lastCompletionDate = streak.lastCompletionDate
                    existing.lastSyncedAt = Date()
                } else {
                    // Insert new
                    let cached = StreakCache.from(habitId: habitId, streak: streak)
                    context.insert(cached)
                }
            }
            
            try context.save()
            
            print("✅ CacheHydrationService: Hydrated \(streaks.count) streaks")
            updateSyncStatus()
            
        } catch {
            print("❌ CacheHydrationService: Failed to hydrate streaks: \(error)")
        }
    }
    
    private func updateXPStateCache(_ xpState: XPState?) async {
        guard let xpState = xpState else { return }
        
        let context = ModelContext(modelContainer)
        
        do {
            if let existing = try context.fetch(
                FetchDescriptor<XPStateCache>(
                    predicate: #Predicate { $0.id == "current" }
                )
            ).first {
                // Update existing
                existing.totalXP = xpState.totalXP
                existing.level = xpState.level
                existing.currentLevelXP = xpState.currentLevelXP
                existing.lastUpdated = xpState.lastUpdated
                existing.lastSyncedAt = Date()
            } else {
                // Insert new
                let cached = XPStateCache.from(xpState)
                context.insert(cached)
            }
            
            try context.save()
            
            print("✅ CacheHydrationService: Hydrated XP state")
            updateSyncStatus()
            
        } catch {
            print("❌ CacheHydrationService: Failed to hydrate XP state: \(error)")
        }
    }
    
    private func updateSyncStatus() {
        cacheStatus = .synced
        lastSyncTime = Date()
        isHydrating = false
    }
}

// MARK: - Cache Query Helper

@MainActor
class CacheQuery {
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer? = nil) {
        self.modelContainer = modelContainer ?? CacheHydrationService.shared.modelContainer
    }
    
    /// Get all cached habits (fast, for list views)
    func getHabits() throws -> [HabitCache] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<HabitCache>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Get active cached habits only
    func getActiveHabits() throws -> [HabitCache] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<HabitCache>(
            predicate: #Predicate { $0.active == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Get cached completions for a date
    func getCompletions(for localDate: String) throws -> [CompletionCache] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CompletionCache>(
            predicate: #Predicate { $0.localDate == localDate }
        )
        return try context.fetch(descriptor)
    }
    
    /// Get cached streak for a habit
    func getStreak(habitId: String) throws -> StreakCache? {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<StreakCache>(
            predicate: #Predicate { $0.habitId == habitId }
        )
        return try context.fetch(descriptor).first
    }
    
    /// Get cached XP state
    func getXPState() throws -> XPStateCache? {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<XPStateCache>()
        return try context.fetch(descriptor).first
    }
}

