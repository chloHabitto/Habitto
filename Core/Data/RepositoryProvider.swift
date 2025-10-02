import Foundation
import SwiftData
import OSLog

// MARK: - Repository Provider Protocol
/// Protocol for providing repositories based on feature flags
protocol RepositoryProviderProtocol {
    var habitRepository: any HabitRepositoryProtocol { get }
    var xpService: any XPServiceProtocol { get }
    var dailyAwardService: DailyAwardService { get }
    var migrationRunner: MigrationRunner { get }
    
    /// Reinitializes repositories for a new user
    func reinitializeForUser(userId: String) async throws
}

// MARK: - Repository Provider Implementation
@MainActor
final class RepositoryProvider: RepositoryProviderProtocol {
    private let featureFlags: FeatureFlagProvider
    private let logger = Logger(subsystem: "com.habitto.app", category: "RepositoryProvider")
    
    // Current user context
    private var currentUserId: String?
    
    // Repositories
    private var _habitRepository: (any HabitRepositoryProtocol)?
    private var _xpService: (any XPServiceProtocol)?
    private var _dailyAwardService: DailyAwardService?
    private var _migrationRunner: MigrationRunner?
    
    init(featureFlags: FeatureFlagProvider) {
        self.featureFlags = featureFlags
    }
    
    // MARK: - Repository Access
    
    var habitRepository: any HabitRepositoryProtocol {
        get {
            if let existing = _habitRepository {
                return existing
            }
            
            let repository = createHabitRepository()
            _habitRepository = repository
            return repository
        }
    }
    
    var xpService: any XPServiceProtocol {
        get {
            if let existing = _xpService {
                return existing
            }
            
            let service = createXPService()
            _xpService = service
            return service
        }
    }
    
    var dailyAwardService: DailyAwardService {
        get {
            if let existing = _dailyAwardService {
                return existing
            }
            
            let service = DailyAwardService.shared
            _dailyAwardService = service
            return service
        }
    }
    
    var migrationRunner: MigrationRunner {
        get {
            if let existing = _migrationRunner {
                return existing
            }
            
            let runner = MigrationRunner(featureFlags: featureFlags)
            _migrationRunner = runner
            return runner
        }
    }
    
    // MARK: - User Reinitialization
    
    func reinitializeForUser(userId: String) async throws {
        logger.info("RepositoryProvider: Reinitializing for user \(userId)")
        
        // Clear existing repositories
        clearRepositories()
        
        // Set new user ID
        currentUserId = userId
        
        // Run migration if needed
        if featureFlags.isMigrationEnabled {
            try await migrationRunner.runIfNeeded(userId: userId)
        }
        
        // Clear any in-memory caches from previous user
        clearUserCaches()
        
        logger.info("RepositoryProvider: Reinitialized for user \(userId)")
    }
    
    // MARK: - Private Methods
    
    private func createHabitRepository() -> any HabitRepositoryProtocol {
        if featureFlags.useNormalizedDataPath {
            logger.info("RepositoryProvider: Creating normalized habit repository")
            return NormalizedHabitRepository(userId: currentUserId ?? "guest")
        } else {
            logger.info("RepositoryProvider: Creating legacy habit repository")
            return LegacyHabitRepository()
        }
    }
    
    private func createXPService() -> any XPServiceProtocol {
        if featureFlags.useCentralizedXP {
            logger.info("RepositoryProvider: Creating centralized XP service")
            return XPService.shared
        } else {
            logger.info("RepositoryProvider: Creating legacy XP service")
            return LegacyXPService()
        }
    }
    
    private func clearRepositories() {
        _habitRepository = nil
        _xpService = nil
        _dailyAwardService = nil
        _migrationRunner = nil
    }
    
    private func clearUserCaches() {
        // Clear singleton caches that might contain user data
        if let legacyRepo = _habitRepository as? LegacyHabitRepository {
            legacyRepo.clearCache()
        }
        
        // Clear XP manager cache
        XPManager.shared.handleUserSignOut()
        
        logger.info("RepositoryProvider: Cleared user caches")
    }
}

// MARK: - Legacy Habit Repository
/// Legacy habit repository that uses UserDefaults + SwiftData dual storage
@MainActor
final class LegacyHabitRepository: HabitRepositoryProtocol {
    private let logger = Logger(subsystem: "com.habitto.app", category: "LegacyHabitRepository")
    
    // Cache for habits
    private var cachedHabits: [Habit]?
    private var currentUserId: String?
    
    init() {
        self.currentUserId = "legacy_user"
    }
    
    func loadHabits() async throws -> [Habit] {
        if let cached = cachedHabits {
            return cached
        }
        
        // Load from UserDefaults (legacy storage)
        let userDefaults = UserDefaults.standard
        guard let habitsData = userDefaults.data(forKey: "SavedHabits"),
              let habits = try? JSONDecoder().decode([Habit].self, from: habitsData) else {
            logger.info("LegacyHabitRepository: No habits found in UserDefaults")
            cachedHabits = []
            return []
        }
        
        cachedHabits = habits
        logger.info("LegacyHabitRepository: Loaded \(habits.count) habits from UserDefaults")
        return habits
    }
    
    func saveHabits(_ habits: [Habit]) async throws {
        // Save to UserDefaults (legacy storage)
        let userDefaults = UserDefaults.standard
        let habitsData = try JSONEncoder().encode(habits)
        userDefaults.set(habitsData, forKey: "SavedHabits")
        
        cachedHabits = habits
        logger.info("LegacyHabitRepository: Saved \(habits.count) habits to UserDefaults")
    }
    
    func toggleHabitCompletion(_ habit: Habit, for date: Date) async throws {
        // Legacy completion logic
        logger.info("LegacyHabitRepository: Toggling completion for habit \(habit.name)")
        
        // This would contain the legacy completion logic
        // For now, just log the action
    }
    
    func clearCache() {
        cachedHabits = nil
        logger.info("LegacyHabitRepository: Cleared cache")
    }
}

// MARK: - Normalized Habit Repository
/// Normalized habit repository that uses SwiftData with proper user scoping
@MainActor
final class NormalizedHabitRepository: HabitRepositoryProtocol {
    private let logger = Logger(subsystem: "com.habitto.app", category: "NormalizedHabitRepository")
    private let userId: String
    private var modelContext: ModelContext
    
    init(userId: String) {
        self.userId = userId
        self.modelContext = ModelContext(SwiftDataContainer.shared.modelContainer)
    }
    
    func loadHabits() async throws -> [Habit] {
        // Load habits from SwiftData with user scoping
        let request = FetchDescriptor<HabitData>(
            predicate: #Predicate { $0.userId == userId }
        )
        
        let habitDataArray = try modelContext.fetch(request)
        
        // Convert HabitData to Habit (legacy format for compatibility)
        let habits = habitDataArray.map { habitData in
            // This would contain the conversion logic
            // For now, return a placeholder
            return Habit(
                name: habitData.name,
                habitDescription: habitData.habitDescription,
                icon: habitData.icon,
                color: .blue, // Convert from colorData
                habitType: .formation, // Convert from string
                schedule: habitData.schedule,
                goal: habitData.goal,
                reminder: habitData.reminder,
                startDate: habitData.startDate,
                endDate: habitData.endDate
            )
        }
        
        logger.info("NormalizedHabitRepository: Loaded \(habits.count) habits for user \(userId)")
        return habits
    }
    
    func saveHabits(_ habits: [Habit]) async throws {
        // Save habits to SwiftData with user scoping
        for habit in habits {
            // Check if habit already exists
            let existingRequest = FetchDescriptor<HabitData>(
                predicate: #Predicate { $0.id == habit.id && $0.userId == userId }
            )
            let existing = try modelContext.fetch(existingRequest)
            
            if existing.isEmpty {
                // Create new HabitData
                let habitData = HabitData(
                    id: habit.id,
                    userId: userId,
                    name: habit.name,
                    habitDescription: habit.habitDescription,
                    icon: habit.icon,
                    colorData: Data(), // Convert from color
                    habitType: habit.habitType.rawValue,
                    schedule: habit.schedule,
                    goal: habit.goal,
                    reminder: habit.reminder,
                    startDate: habit.startDate,
                    endDate: habit.endDate,
                    isCompleted: habit.isCompleted,
                    streak: habit.streak
                )
                
                modelContext.insert(habitData)
            }
        }
        
        try modelContext.save()
        logger.info("NormalizedHabitRepository: Saved \(habits.count) habits for user \(userId)")
    }
    
    func toggleHabitCompletion(_ habit: Habit, for date: Date) async throws {
        // Normalized completion logic using XPService
        logger.info("NormalizedHabitRepository: Toggling completion for habit \(habit.name)")
        
        let dateKey = DateKey.key(for: date)
        
        // Create completion record
        let completionRecord = CompletionRecord(
            userId: userId,
            habitId: habit.id,
            date: date,
            dateKey: dateKey,
            isCompleted: !habit.isCompleted(for: date)
        )
        
        modelContext.insert(completionRecord)
        try modelContext.save()
        
        // Award XP if all habits completed
        let xpService = XPService.shared
        let _ = try await xpService.awardDailyCompletionIfEligible(userId: userId, dateKey: dateKey)
    }
}

// MARK: - Legacy XP Service
/// Legacy XP service that uses XPManager
final class LegacyXPService: XPServiceProtocol {
    private let logger = Logger(subsystem: "com.habitto.app", category: "LegacyXPService")
    
    func awardDailyCompletionIfEligible(userId: String, dateKey: String) async throws -> Int {
        logger.info("LegacyXPService: Awarding daily completion for user \(userId)")
        
        // Use legacy XPManager
        let xpManager = XPManager.shared
        xpManager.debugForceAwardXP(50) // Legacy XP amount
        
        return 50
    }
    
    func revokeDailyCompletionIfIneligible(userId: String, dateKey: String) async throws -> Int {
        logger.info("LegacyXPService: Revoking daily completion for user \(userId)")
        
        // Legacy revocation logic
        return 0
    }
    
    func getUserProgress(userId: String) async throws -> UserProgress {
        logger.info("LegacyXPService: Getting user progress for user \(userId)")
        
        // Use legacy XPManager
        let xpManager = XPManager.shared
        return xpManager.userProgress
    }
    
    func getDailyAward(userId: String, dateKey: String) async throws -> DailyAward? {
        logger.info("LegacyXPService: Getting daily award for user \(userId)")
        
        // Legacy daily award logic
        return nil
    }
}

// MARK: - Habit Repository Protocol
protocol HabitRepositoryProtocol {
    func loadHabits() async throws -> [Habit]
    func saveHabits(_ habits: [Habit]) async throws
    func toggleHabitCompletion(_ habit: Habit, for date: Date) async throws
}
