import Foundation
import SwiftUI

// MARK: - Habit Repository Implementation
/// Implementation of the habit repository protocol using dependency injection
class HabitRepositoryImpl: HabitRepositoryProtocol, ObservableObject {
    typealias DataType = Habit
    
    @Published var habits: [Habit] = []
    
    private let storage: any HabitStorageProtocol
    private let cloudKitManager: CloudKitManager
    
    // Performance optimization: Cache expensive operations
    private var lastHabitsUpdate: Date = Date()
    private let updateDebounceInterval: TimeInterval = 0.5
    
    init(storage: any HabitStorageProtocol, cloudKitManager: CloudKitManager = CloudKitManager.shared) {
        self.storage = storage
        self.cloudKitManager = cloudKitManager
        
        // Initialize CloudKit sync
        cloudKitManager.initializeCloudKitSync()
        
        // Load initial data
        Task {
            await loadHabits()
        }
        
        // Monitor app lifecycle
        setupAppLifecycleObservers()
    }
    
    // MARK: - Repository Protocol Implementation
    
    func getAll() async throws -> [Habit] {
        return try await storage.loadHabits()
    }
    
    func getById(_ id: UUID) async throws -> Habit? {
        return try await storage.loadHabit(id: id)
    }
    
    func create(_ item: Habit) async throws -> Habit {
        try await storage.saveHabit(item, immediate: true)
        await loadHabits()
        return item
    }
    
    func update(_ item: Habit) async throws -> Habit {
        try await storage.saveHabit(item, immediate: true)
        await loadHabits()
        return item
    }
    
    func delete(_ id: UUID) async throws {
        try await storage.deleteHabit(id: id)
        await loadHabits()
    }
    
    func exists(_ id: UUID) async throws -> Bool {
        return try await storage.loadHabit(id: id) != nil
    }
    
    // MARK: - Habit-Specific Repository Methods
    
    func getHabits(for date: Date) async throws -> [Habit] {
        let allHabits = try await getAll()
        return allHabits.filter { habit in
            // Filter habits that are active on the given date
            let startDate = habit.startDate
            let endDate = habit.endDate ?? Date.distantFuture
            return date >= startDate && date <= endDate
        }
    }
    
    func getHabits(by type: HabitType) async throws -> [Habit] {
        let allHabits = try await getAll()
        return allHabits.filter { $0.habitType == type }
    }
    
    func getActiveHabits() async throws -> [Habit] {
        let allHabits = try await getAll()
        return allHabits.filter { !$0.isCompleted }
    }
    
    func getArchivedHabits() async throws -> [Habit] {
        let allHabits = try await getAll()
        return allHabits.filter { $0.isCompleted }
    }
    
    func updateHabitCompletion(habitId: UUID, date: Date, progress: Double) async throws {
        guard var habit = try await getById(habitId) else {
            throw RepositoryError.habitNotFound
        }
        
        let dateKey = DateUtils.dateKey(for: date)
        habit.completionHistory[dateKey] = Int(progress * 100) // Store as percentage
        
        try await update(habit)
    }
    
    func getHabitCompletion(habitId: UUID, date: Date) async throws -> Double {
        guard let habit = try await getById(habitId) else {
            throw RepositoryError.habitNotFound
        }
        
        let dateKey = DateUtils.dateKey(for: date)
        let progress = habit.completionHistory[dateKey] ?? 0
        return Double(progress) / 100.0 // Convert from percentage
    }
    
    func calculateHabitStreak(habitId: UUID) async throws -> Int {
        guard let habit = try await getById(habitId) else {
            throw RepositoryError.habitNotFound
        }
        
        return habit.calculateTrueStreak()
    }
    
    // MARK: - Additional Convenience Methods
    
    func loadHabits(force: Bool = false) async {
        // Performance optimization: Debounce updates
        if !force && Date().timeIntervalSince(lastHabitsUpdate) < updateDebounceInterval {
            return
        }
        
        do {
            let loadedHabits = try await storage.loadHabits()
            
            await MainActor.run {
                self.habits = loadedHabits
                self.lastHabitsUpdate = Date()
                self.objectWillChange.send()
            }
        } catch {
            print("❌ HabitRepositoryImpl: Failed to load habits: \(error)")
        }
    }
    
    func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
        try await storage.saveHabits(habits, immediate: immediate)
        
        await MainActor.run {
            self.habits = habits
            self.objectWillChange.send()
        }
    }
    
    func migrateFromUserDefaults() async {
        // This method handles migration from UserDefaults to the current storage
        // Implementation depends on the specific migration strategy
        print("🔄 HabitRepositoryImpl: Starting migration from UserDefaults...")
        
        // For now, this is a no-op since we're already using UserDefaults
        // In the future, this would migrate from UserDefaults to Core Data
        print("✅ HabitRepositoryImpl: Migration completed (no-op for UserDefaults)")
    }
    
    // MARK: - App Lifecycle Management
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.loadHabits(force: true)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task {
                do {
                    try await self.storage.saveHabits(self.habits, immediate: true)
                } catch {
                    print("❌ HabitRepositoryImpl: Failed to save habits on app resign: \(error)")
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Repository Errors
enum RepositoryError: Error, LocalizedError {
    case habitNotFound
    case invalidData
    case storageError(Error)
    
    var errorDescription: String? {
        switch self {
        case .habitNotFound:
            return "Habit not found"
        case .invalidData:
            return "Invalid data provided"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        }
    }
}
