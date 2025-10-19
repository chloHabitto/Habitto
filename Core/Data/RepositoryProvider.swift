import Foundation
import OSLog
import SwiftData

// MARK: - RepositoryProviderProtocol

/// Protocol for providing repositories based on feature flags
@MainActor
protocol RepositoryProviderProtocol {
  var habitRepository: any HabitRepositoryProtocol { get }
  // TODO: Update to use new XPService when integrated
  // var xpService: any XPServiceProtocol { get }
  var dailyAwardService: DailyAwardService { get }
  var migrationRunner: MigrationRunner { get }

  /// Reinitializes repositories for a new user
  func reinitializeForUser(userId: String) async throws
}

// MARK: - RepositoryProvider

/// Main repository provider that creates the appropriate repositories based on feature flags
@MainActor
final class RepositoryProvider: RepositoryProviderProtocol {
  // MARK: Lifecycle

  // MARK: - Initialization

  init() {
    logger.info("RepositoryProvider: Initialized")
  }

  // MARK: Internal

  // MARK: - Repository Access

  var habitRepository: any HabitRepositoryProtocol {
    if let existing = _habitRepository {
      return existing
    }

    let repository = createHabitRepository()
    _habitRepository = repository
    return repository
  }

  // TODO: Update to use new XPService when integrated
  /*
  var xpService: any XPServiceProtocol {
    if let existing = _xpService {
      return existing
    }

    let service = createXPService()
    _xpService = service
    return service
  }
  */

  var dailyAwardService: DailyAwardService {
    if let existing = _dailyAwardService {
      return existing
    }

    // Use new Firebase-based DailyAwardService
    let service = DailyAwardService.shared
    _dailyAwardService = service
    return service
  }

  var migrationRunner: MigrationRunner {
    if let existing = _migrationRunner {
      return existing
    }

    let runner = MigrationRunner.shared
    _migrationRunner = runner
    return runner
  }

  // MARK: - User Management

  func reinitializeForUser(userId: String) async throws {
    logger.info("RepositoryProvider: Reinitializing for user \(userId)")

    // Clear existing repositories
    _habitRepository = nil
    // TODO: Re-enable when new XPService is integrated
    // _xpService = nil
    _dailyAwardService = nil

    // Run migration if needed
    try await migrationRunner.runIfNeeded(userId: userId)

    // Create new repositories for the user
    _ = habitRepository
    // TODO: Re-enable when new XPService is integrated
    // _ = xpService
    _ = dailyAwardService

    logger.info("RepositoryProvider: Reinitialized for user \(userId)")
  }

  func clearUserData() async {
    logger.info("RepositoryProvider: Clearing user data")

    // Clear repositories
    _habitRepository = nil
    // TODO: Re-enable when new XPService is integrated
    // _xpService = nil
    _dailyAwardService = nil

    // Clear XP manager cache
    XPManager.shared.handleUserSignOut()

    logger.info("RepositoryProvider: Cleared user caches")
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "RepositoryProvider")

  // Repositories
  private var _habitRepository: (any HabitRepositoryProtocol)?
  // TODO: Update to use new XPService when integrated
  // private var _xpService: (any XPServiceProtocol)?
  private var _dailyAwardService: DailyAwardService?
  private var _migrationRunner: MigrationRunner?

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

  // TODO: Update to use new XPService when integrated
  /*
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
  */
}

// MARK: - LegacyHabitRepository

/// Legacy habit repository that uses UserDefaults + SwiftData dual storage
@MainActor
final class LegacyHabitRepository: HabitRepositoryProtocol {
  // MARK: Lifecycle

  init() {
    self.currentUserId = "legacy_user"
  }

  // MARK: Internal

  // MARK: - RepositoryProtocol Conformance

  func getAll() async throws -> [Habit] {
    try await getActiveHabits()
  }

  func getById(_ id: UUID) async throws -> Habit? {
    let habits = try await getActiveHabits()
    return habits.first { $0.id == id }
  }

  func create(_ habit: Habit) async throws {
    // TODO: Implement habit creation
    throw DataStorageError.operationNotSupported("Method not implemented")
  }

  func update(_ habit: Habit) async throws {
    // TODO: Implement habit update
    throw DataStorageError.operationNotSupported("Method not implemented")
  }

  func delete(_: UUID) async throws {
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
       let habits = try? JSONDecoder().decode([Habit].self, from: data)
    {
      cachedHabits = habits
      return habits
    }

    cachedHabits = []
    return []
  }

  // MARK: - HabitRepositoryProtocol Conformance

  func getHabits(for _: Date) async throws -> [Habit] {
    try await loadHabits()
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

  func updateHabitCompletion(_: Habit, for _: Date, isCompleted _: Bool) async throws {
    // Implementation would go here
  }

  func updateHabitCompletion(habitId _: UUID, date _: Date, progress _: Double) async throws {
    // TODO: Implement habit completion update
    throw DataStorageError.operationNotSupported("Method not implemented")
  }

  func getHabitCompletion(habitId _: UUID, date _: Date) async throws -> Double {
    // TODO: Implement habit completion retrieval
    0.0
  }

  func calculateHabitStreak(habitId _: UUID) async throws -> Int {
    // Implementation would go here
    0
  }

  // MARK: - HabitRepositoryProtocol Required Methods

  nonisolated func habits() -> AsyncThrowingStream<[Habit], Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          let habits = try await loadHabits()
          continuation.yield(habits)
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  nonisolated func habit(by id: String) -> AsyncThrowingStream<Habit?, Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          guard let uuid = UUID(uuidString: id) else {
            continuation.yield(nil)
            continuation.finish()
            return
          }
          let habit = try await getById(uuid)
          continuation.yield(habit)
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func habits(for date: Date) async throws -> [Habit] {
    return try await getHabits(for: date)
  }

  func delete(id: String) async throws {
    guard let uuid = UUID(uuidString: id) else {
      throw DataStorageError.operationNotSupported("Invalid habit ID")
    }
    try await delete(uuid)
  }

  func markComplete(habitId: String, date: Date, count: Int) async throws -> Int {
    // TODO: Implement habit completion
    throw DataStorageError.operationNotSupported("Method not implemented")
  }

  func getCompletionCount(habitId: String, date: Date) async throws -> Int {
    // TODO: Implement completion count retrieval
    return 0
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "LegacyHabitRepository")

  // Cache for habits
  private var cachedHabits: [Habit]?
  private var currentUserId: String?
}

// MARK: - NormalizedHabitRepository

/// Normalized habit repository that uses SwiftData with proper user scoping
@MainActor
final class NormalizedHabitRepository: HabitRepositoryProtocol {
  // MARK: Lifecycle

  init(userId: String) {
    self.userId = userId
    self.modelContext = ModelContext(SwiftDataContainer.shared.modelContainer)
  }

  // MARK: Internal

  // MARK: - RepositoryProtocol Conformance

  func getAll() async throws -> [Habit] {
    try await getActiveHabits()
  }

  func getById(_ id: UUID) async throws -> Habit? {
    let habits = try await getActiveHabits()
    return habits.first { $0.id == id }
  }

  func create(_ habit: Habit) async throws {
    // TODO: Implement habit creation
    throw DataStorageError.operationNotSupported("Method not implemented")
  }

  func update(_ habit: Habit) async throws {
    // TODO: Implement habit update
    throw DataStorageError.operationNotSupported("Method not implemented")
  }

  func delete(_: UUID) async throws {
    // TODO: Implement habit deletion
    throw DataStorageError.operationNotSupported("Method not implemented")
  }

  func exists(_ id: UUID) async throws -> Bool {
    let habit = try await getById(id)
    return habit != nil
  }

  func loadHabits() async throws -> [Habit] {
    // Load habits from SwiftData with user scoping
    let currentUserId = userId
    let request = FetchDescriptor<HabitData>(
      predicate: #Predicate { $0.userId == currentUserId })

    let habitDataList = try modelContext.fetch(request)
    return habitDataList.map { $0.toHabit() }
  }

  // MARK: - HabitRepositoryProtocol Conformance

  func getHabits(for _: Date) async throws -> [Habit] {
    try await loadHabits()
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
    []
  }

  func updateHabitCompletion(_: Habit, for _: Date, isCompleted _: Bool) async throws {
    // Implementation would go here
  }

  func updateHabitCompletion(habitId _: UUID, date _: Date, progress _: Double) async throws {
    // TODO: Implement habit completion update
    throw DataStorageError.operationNotSupported("Method not implemented")
  }

  func getHabitCompletion(habitId _: UUID, date _: Date) async throws -> Double {
    // TODO: Implement habit completion retrieval
    0.0
  }

  func calculateHabitStreak(habitId _: UUID) async throws -> Int {
    // Implementation would go here
    0
  }

  // MARK: - HabitRepositoryProtocol Required Methods

  nonisolated func habits() -> AsyncThrowingStream<[Habit], Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          let habits = try await loadHabits()
          continuation.yield(habits)
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  nonisolated func habit(by id: String) -> AsyncThrowingStream<Habit?, Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          guard let uuid = UUID(uuidString: id) else {
            continuation.yield(nil)
            continuation.finish()
            return
          }
          let habit = try await getById(uuid)
          continuation.yield(habit)
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func habits(for date: Date) async throws -> [Habit] {
    return try await getHabits(for: date)
  }

  func delete(id: String) async throws {
    guard let uuid = UUID(uuidString: id) else {
      throw DataStorageError.operationNotSupported("Invalid habit ID")
    }
    try await delete(uuid)
  }

  func markComplete(habitId: String, date: Date, count: Int) async throws -> Int {
    // TODO: Implement habit completion
    throw DataStorageError.operationNotSupported("Method not implemented")
  }

  func getCompletionCount(habitId: String, date: Date) async throws -> Int {
    // TODO: Implement completion count retrieval
    return 0
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "NormalizedHabitRepository")
  private let userId: String
  private var modelContext: ModelContext
}

// MARK: - LegacyXPService
// TODO: Update to use new XPService when integrated
/*
/// Legacy XP service that uses XPManager
final class LegacyXPService: XPServiceProtocol {
  // MARK: Internal

  func awardDailyCompletionIfEligible(userId: String, dateKey _: String) async throws -> Int {
    logger.info("LegacyXPService: Getting daily award for user \(userId)")

    // Legacy daily award logic
    return 0
  }

  func revokeDailyCompletionIfIneligible(userId: String, dateKey _: String) async throws -> Int {
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

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "LegacyXPService")
}
*/
