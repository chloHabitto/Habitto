import Foundation
import SwiftData
import OSLog

// MARK: - Repository Provider Protocol
/// Protocol for providing repositories based on feature flags
@MainActor
protocol RepositoryProviderProtocol {
    var habitRepository: any HabitRepositoryProtocol { get }
    var xpService: any XPServiceProtocol { get }
    var dailyAwardService: DailyAwardService { get }
    var migrationRunner: MigrationRunner { get }
    
    /// Reinitializes repositories for a new user
    func reinitializeForUser(userId: String) async throws
}

// MARK: - Repository Provider Implementation
/// Main repository provider that creates the appropriate repositories based on feature flags
@MainActor
final class RepositoryProvider: RepositoryProviderProtocol {
    private let logger = Logger(subsystem: "com.habitto.app", category: "RepositoryProvider")
    
    // Repositories
    private var _habitRepository: (any HabitRepositoryProtocol)?
    private var _xpService: (any XPServiceProtocol)?
    private var _dailyAwardService: DailyAwardService?
    private var _migrationRunner: MigrationRunner?
    
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
            
            let service = DailyAwardService(modelContext: ModelContext(SwiftDataContainer.shared.modelContainer))
            _dailyAwardService = service
            return service
        }
    }
    
    var migrationRunner: MigrationRunner {
        get {
            if let existing = _migrationRunner {
                return existing
            }
            
            let runner = MigrationRunner.shared
            _migrationRunner = runner
            return runner
        }
    }
    
    // MARK: - Initialization
    
    init() {
        logger.info("RepositoryProvider: Initialized")
    }
    
    // MARK: - User Management
    
    func reinitializeForUser(userId: String) async throws {
        logger.info("RepositoryProvider: Reinitializing for user \(userId)")
        
        // Clear existing repositories
        _habitRepository = nil
        _xpService = nil
        _dailyAwardService = nil
        
        // Run migration if needed
        try await migrationRunner.runIfNeeded(userId: userId)
        
        // Create new repositories for the user
        _ = habitRepository
        _ = xpService
        _ = dailyAwardService
        
        logger.info("RepositoryProvider: Reinitialized for user \(userId)")
    }
    
    func clearUserData() async {
        logger.info("RepositoryProvider: Clearing user data")
        
        // Clear repositories
        _habitRepository = nil
        _xpService = nil
        _dailyAwardService = nil
        
        // Clear XP manager cache
        XPManager.shared.handleUserSignOut()
        
        logger.info("RepositoryProvider: Cleared user caches")
    }
    
    // MARK: - Private Methods
    
    private func createHabitRepository() -> any HabitRepositoryProtocol {
        let featureFlags = FeatureFlagManager.shared.provider
        
        if featureFlags.useNormalizedDataPath {
            logger.info("RepositoryProvider: Creating normalized habit repository")
            return NormalizedHabitRepository(userId: "current_user")
        } else {
            logger.info("RepositoryProvider: Creating legacy habit repository")
            return LegacyHabitRepository()
        }
    }
    
    private func createXPService() -> any XPServiceProtocol {
        let featureFlags = FeatureFlagManager.shared.provider
        
        if featureFlags.useCentralizedXP {
            logger.info("RepositoryProvider: Creating centralized XP service")
            return XPService.shared
        } else {
            logger.info("RepositoryProvider: Creating legacy XP service")
            return LegacyXPService()
        }
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
    
    // MARK: - RepositoryProtocol Conformance
    
    func getAll() async throws -> [Habit] {
        return try await getActiveHabits()
    }
    
    func getById(_ id: UUID) async throws -> Habit? {
        let habits = try await getActiveHabits()
        return habits.first { $0.id == id }
    }
    
    func create(_ item: Habit) async throws -> Habit {
        // TODO: Implement habit creation
        throw DataStorageError.operationNotSupported("Method not implemented")
    }
    
    func update(_ item: Habit) async throws -> Habit {
        // TODO: Implement habit update
        throw DataStorageError.operationNotSupported("Method not implemented")
    }
    
    func delete(_ id: UUID) async throws {
        // TODO: Implement habit deletion
        throw DataStorageError.operationNotSupported("Method not implemented")
    }
    
    func exists(_ id: UUID) async throws -> Bool {
        let habit = try await getById(id)
        return habit != nil
    }
    
    func loadHabits() async throws -> [Habit] {
        if let cached = cachedHabits {
            return cached
        }
        
        // Load from UserDefaults (legacy storage)
        let userDefaults = UserDefaults.standard
        if let data = userDefaults.data(forKey: "habits"),
           let habits = try? JSONDecoder().decode([Habit].self, from: data) {
            cachedHabits = habits
            return habits
        }
        
        cachedHabits = []
        return []
    }
    
    // MARK: - HabitRepositoryProtocol Conformance
    
    func getHabits(for date: Date) async throws -> [Habit] {
        return try await loadHabits()
    }
    
    func getHabits(by type: HabitType) async throws -> [Habit] {
        let habits = try await loadHabits()
        return habits.filter { $0.habitType == type }
    }
    
    func getActiveHabits() async throws -> [Habit] {
        let habits = try await loadHabits()
        // TODO: Implement isActive property or logic
        return habits
    }
    
    func getArchivedHabits() async throws -> [Habit] {
        _ = try await loadHabits()
        // TODO: Implement isActive property or logic
        return []
    }
    
    func updateHabitCompletion(_ habit: Habit, for date: Date, isCompleted: Bool) async throws {
        // Implementation would go here
    }
    
    func updateHabitCompletion(habitId: UUID, date: Date, progress: Double) async throws {
        // TODO: Implement habit completion update
        throw DataStorageError.operationNotSupported("Method not implemented")
    }
    
    func getHabitCompletion(habitId: UUID, date: Date) async throws -> Double {
        // TODO: Implement habit completion retrieval
        return 0.0
    }
    
    func calculateHabitStreak(habitId: UUID) async throws -> Int {
        // Implementation would go here
        return 0
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
    
    // MARK: - RepositoryProtocol Conformance
    
    func getAll() async throws -> [Habit] {
        return try await getActiveHabits()
    }
    
    func getById(_ id: UUID) async throws -> Habit? {
        let habits = try await getActiveHabits()
        return habits.first { $0.id == id }
    }
    
    func create(_ item: Habit) async throws -> Habit {
        // TODO: Implement habit creation
        throw DataStorageError.operationNotSupported("Method not implemented")
    }
    
    func update(_ item: Habit) async throws -> Habit {
        // TODO: Implement habit update
        throw DataStorageError.operationNotSupported("Method not implemented")
    }
    
    func delete(_ id: UUID) async throws {
        // TODO: Implement habit deletion
        throw DataStorageError.operationNotSupported("Method not implemented")
    }
    
    func exists(_ id: UUID) async throws -> Bool {
        let habit = try await getById(id)
        return habit != nil
    }
    
    func loadHabits() async throws -> [Habit] {
        // Load habits from SwiftData with user scoping
        let request = FetchDescriptor<HabitData>(
            predicate: #Predicate { $0.userId == self.userId }
        )
        
        let habitDataList = try modelContext.fetch(request)
        return habitDataList.map { $0.toHabit() }
    }
    
    // MARK: - HabitRepositoryProtocol Conformance
    
    func getHabits(for date: Date) async throws -> [Habit] {
        return try await loadHabits()
    }
    
    func getHabits(by type: HabitType) async throws -> [Habit] {
        let habits = try await loadHabits()
        return habits.filter { $0.habitType == type }
    }
    
    func getActiveHabits() async throws -> [Habit] {
        let habits = try await loadHabits()
        // TODO: Implement isActive property or logic
        return habits
    }
    
    func getArchivedHabits() async throws -> [Habit] {
        return []
    }
    
    func updateHabitCompletion(_ habit: Habit, for date: Date, isCompleted: Bool) async throws {
        // Implementation would go here
    }
    
    func updateHabitCompletion(habitId: UUID, date: Date, progress: Double) async throws {
        // TODO: Implement habit completion update
        throw DataStorageError.operationNotSupported("Method not implemented")
    }
    
    func getHabitCompletion(habitId: UUID, date: Date) async throws -> Double {
        // TODO: Implement habit completion retrieval
        return 0.0
    }
    
    func calculateHabitStreak(habitId: UUID) async throws -> Int {
        // Implementation would go here
        return 0
    }
}

// MARK: - Legacy XP Service
/// Legacy XP service that uses XPManager
final class LegacyXPService: XPServiceProtocol {
    private let logger = Logger(subsystem: "com.habitto.app", category: "LegacyXPService")
    
    func awardDailyCompletionIfEligible(userId: String, dateKey: String) async throws -> Int {
        logger.info("LegacyXPService: Getting daily award for user \(userId)")
        
        // Legacy daily award logic
        return 0
    }
    
    func revokeDailyCompletionIfIneligible(userId: String, dateKey: String) async throws -> Int {
        logger.info("LegacyXPService: Revoking daily award for user \(userId)")
        
        // Legacy daily award logic
        return 0
    }
    
    func getUserProgress(userId: String) async throws -> UserProgress {
        logger.info("LegacyXPService: Getting user progress for user \(userId)")
        
        // Legacy user progress logic
        return UserProgress(userId: userId)
    }
    
    func getDailyAward(userId: String, dateKey: String) async throws -> DailyAward? {
        logger.info("LegacyXPService: Getting daily award for user \(userId) on \(dateKey)")
        
        // Legacy daily award logic
        return nil
    }
}