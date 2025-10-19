import Foundation
import SwiftUI

// MARK: - HabitRepositoryImpl

/// Implementation of the habit repository protocol using dependency injection
class HabitRepositoryImpl: HabitRepositoryProtocol, ObservableObject {
  // MARK: Lifecycle

  init(
    storage: any HabitStorageProtocol,
    cloudKitManager: CloudKitManager = CloudKitManager.shared)
  {
    self.storage = storage
    self.cloudKitManager = cloudKitManager

    // Initialize CloudKit sync (feature flag protected)
    Task {
      let isEnabled = await MainActor.run {
        // TODO: Add cloudKitSync feature flag to FeatureFlagProvider
        // FeatureFlagManager.shared.provider.cloudKitSync
        false // Temporarily disabled
      }
      if isEnabled {
        cloudKitManager.initializeCloudKitSync()
        print("🚩 HabitRepositoryImpl: CloudKit sync enabled by feature flag")
      } else {
        print("🚩 HabitRepositoryImpl: CloudKit sync disabled by feature flag")
      }
    }

    // Load initial data
    Task {
      await loadHabits()
    }

    // Monitor app lifecycle
    setupAppLifecycleObservers()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: Internal

  typealias DataType = Habit

  @Published var habitList: [Habit] = []

  // MARK: - Repository Protocol Implementation

  func getAll() async throws -> [Habit] {
    try await storage.loadHabits()
  }

  func habits() -> AsyncThrowingStream<[Habit], Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          let habits = try await storage.loadHabits()
          continuation.yield(habits)
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func getById(_ id: UUID) async throws -> Habit? {
    try await storage.loadHabit(id: id)
  }

  func habit(by id: String) -> AsyncThrowingStream<Habit?, Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          guard let uuid = UUID(uuidString: id) else {
            continuation.yield(nil)
            continuation.finish()
            return
          }
          let habit = try await storage.loadHabit(id: uuid)
          continuation.yield(habit)
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func create(_ item: Habit) async throws {
    try await storage.saveHabit(item, immediate: true)
    await loadHabits()
  }

  func update(_ item: Habit) async throws {
    try await storage.saveHabit(item, immediate: true)
    await loadHabits()
  }

  func delete(_ id: UUID) async throws {
    try await storage.deleteHabit(id: id)
    await loadHabits()
  }

  func delete(id: String) async throws {
    guard let uuid = UUID(uuidString: id) else {
      throw RepositoryError.invalidData
    }
    try await storage.deleteHabit(id: uuid)
    await loadHabits()
  }

  func exists(_ id: UUID) async throws -> Bool {
    try await storage.loadHabit(id: id) != nil
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

  func habits(for date: Date) async throws -> [Habit] {
    return try await getHabits(for: date)
  }

  func getHabits(by type: HabitType) async throws -> [Habit] {
    let allHabits = try await getAll()
    return allHabits.filter { $0.habitType == type }
  }

  func getActiveHabits() async throws -> [Habit] {
    let allHabits = try await getAll()
    return allHabits.filter { !$0.currentCompletionStatus }
  }

  func getArchivedHabits() async throws -> [Habit] {
    let allHabits = try await getAll()
    return allHabits.filter { $0.currentCompletionStatus }
  }

  func updateHabitCompletion(habitId: UUID, date: Date, progress: Double) async throws {
    guard var habit = try await getById(habitId) else {
      throw RepositoryError.habitNotFound
    }

    let dateKey = Habit.dateKey(for: date)
    habit.completionHistory[dateKey] = Int(progress * 100) // Store as percentage

    // Note: updateStreakWithReset() was removed in Phase 4. Streak is now computed-only.
    // The streak will be automatically calculated when accessed via computedStreak()

    _ = try await update(habit)
  }

  func getHabitCompletion(habitId: UUID, date: Date) async throws -> Double {
    guard let habit = try await getById(habitId) else {
      throw RepositoryError.habitNotFound
    }

    let dateKey = Habit.dateKey(for: date)
    let progress = habit.completionHistory[dateKey] ?? 0
    return Double(progress) / 100.0 // Convert from percentage
  }

  func getCompletionCount(habitId: String, date: Date) async throws -> Int {
    guard let uuid = UUID(uuidString: habitId) else {
      throw RepositoryError.invalidData
    }
    guard let habit = try await getById(uuid) else {
      throw RepositoryError.habitNotFound
    }

    let dateKey = Habit.dateKey(for: date)
    let progress = habit.completionHistory[dateKey] ?? 0
    return Int(Double(progress) / 100.0) // Convert from percentage to count
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
    if !force, Date().timeIntervalSince(lastHabitsUpdate) < updateDebounceInterval {
      return
    }

    do {
      let loadedHabits = try await storage.loadHabits()

      await MainActor.run {
        self.habitList = loadedHabits
        self.lastHabitsUpdate = Date()
        self.objectWillChange.send()
      }
    } catch {
      print("❌ HabitRepositoryImpl: Failed to load habits: \(error)")
    }
  }

  func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
    // Feature flag protection: Check if data operations are enabled
    let isEnabled = await MainActor.run {
      // TODO: Add migrationKillSwitch feature flag to FeatureFlagProvider
      // FeatureFlagManager.shared.provider.migrationKillSwitch
      false // Temporarily disabled
    }
    guard isEnabled else {
      print("🚩 HabitRepositoryImpl: Data operations disabled by feature flag")
      // Record telemetry for feature flag kill
      await EnhancedMigrationTelemetryManager.shared.recordEvent(
        .killSwitchTriggered,
        errorCode: "feature_flag_disabled",
        success: false)
      throw DataError.featureDisabled("Data operations disabled by feature flag")
    }

    try await storage.saveHabits(habits, immediate: immediate)

    await MainActor.run {
      self.habitList = habits
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

  func markComplete(habitId: String, date: Date, count: Int) async throws -> Int {
    guard let uuid = UUID(uuidString: habitId) else {
      throw RepositoryError.invalidData
    }
    guard var habit = try await getById(uuid) else {
      throw RepositoryError.habitNotFound
    }

    let dateKey = Habit.dateKey(for: date)
    habit.completionHistory[dateKey] = count
    habit.completionStatus[dateKey] = count > 0
    
    try await update(habit)
    return count
  }

  // MARK: Private

  private let storage: any HabitStorageProtocol
  private let cloudKitManager: CloudKitManager // TODO: Use for CloudKit sync operations

  // Performance optimization: Cache expensive operations
  private var lastHabitsUpdate = Date()
  private let updateDebounceInterval: TimeInterval = 0.5

  // MARK: - App Lifecycle Management

  private func setupAppLifecycleObservers() {
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main)
    { [weak self] _ in
      Task {
        await self?.loadHabits(force: true)
      }
    }

    NotificationCenter.default.addObserver(
      forName: UIApplication.willResignActiveNotification,
      object: nil,
      queue: .main)
    { [weak self] _ in
      guard let self else { return }
      Task {
        do {
          try await self.storage.saveHabits(self.habitList, immediate: true)
        } catch {
          print("❌ HabitRepositoryImpl: Failed to save habits on app resign: \(error)")
        }
      }
    }
  }
}

// MARK: - RepositoryError

enum RepositoryError: Error, LocalizedError {
  case habitNotFound
  case invalidData
  case storageError(Error)

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .habitNotFound:
      "Habit not found"
    case .invalidData:
      "Invalid data provided"
    case .storageError(let error):
      "Storage error: \(error.localizedDescription)"
    }
  }
}
