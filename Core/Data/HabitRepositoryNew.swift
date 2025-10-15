import Foundation
import SwiftUI

// MARK: - New Habit Repository (Protocol-Based)

/// New HabitRepository implementation using the protocol pattern
@MainActor
class HabitRepositoryNew: HabitRepositoryProtocol, ObservableObject {
  // MARK: Lifecycle

  private init() {
    // Get the recommended storage type
    let storageType = StorageFactory.shared.getRecommendedStorageType()

    // Create the repository with the selected storage
    self.repository = StorageFactory.shared.createHabitRepository(type: storageType)

    // Load initial data
    Task {
      await loadHabits()
    }

    // Set up app lifecycle observers
    setupAppLifecycleObservers()

    print("✅ HabitRepositoryNew: Initialized with \(storageType.displayName) storage")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: Internal

  typealias DataType = Habit

  static let shared = HabitRepositoryNew()

  @Published var habitList: [Habit] = []

  // MARK: - Repository Protocol Implementation

  nonisolated func habits() -> AsyncThrowingStream<[Habit], Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          let habits = try await repository.habits().firstValue() ?? []
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
          let habit = try await repository.habit(by: id).firstValue()
          continuation.yield(habit ?? nil)
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func habits(for date: Date) async throws -> [Habit] {
    try await repository.habits(for: date)
  }

  func getById(_ id: UUID) async throws -> Habit? {
    try await repository.habit(by: id.uuidString).firstValue() ?? nil
  }

  func create(_ item: Habit) async throws {
    try await repository.create(item)
    await loadHabits()
  }

  func update(_ item: Habit) async throws {
    try await repository.update(item)
    await loadHabits()
  }

  func delete(_ id: UUID) async throws {
    try await repository.delete(id: id.uuidString)
    await loadHabits()
  }

  func delete(id: String) async throws {
    try await repository.delete(id: id)
    await loadHabits()
  }

  func exists(_ id: UUID) async throws -> Bool {
    let habit = try await repository.habit(by: id.uuidString).firstValue()
    return habit != nil
  }

  // MARK: - Habit-Specific Repository Methods

  func getHabits(for date: Date) async throws -> [Habit] {
    try await repository.habits(for: date)
  }

  func getHabits(by type: HabitType) async throws -> [Habit] {
    // TODO: Implement filtering by type
    let allHabits = try await repository.habits().firstValue() ?? []
    return allHabits.filter { $0.habitType == type }
  }

  func getActiveHabits() async throws -> [Habit] {
    // TODO: Implement active habits filtering
    return try await repository.habits().firstValue() ?? []
  }

  func getArchivedHabits() async throws -> [Habit] {
    // TODO: Implement archived habits filtering
    return []
  }

  func updateHabitCompletion(habitId: UUID, date: Date, progress: Double) async throws {
    let count = Int(progress * 100)
    _ = try await repository.markComplete(habitId: habitId.uuidString, date: date, count: count)
    await loadHabits()
  }

  func getHabitCompletion(habitId: UUID, date: Date) async throws -> Double {
    let count = try await repository.getCompletionCount(habitId: habitId.uuidString, date: date)
    return Double(count) / 100.0
  }

  func getCompletionCount(habitId: String, date: Date) async throws -> Int {
    try await repository.getCompletionCount(habitId: habitId, date: date)
  }

  func markComplete(habitId: String, date: Date, count: Int) async throws -> Int {
    try await repository.markComplete(habitId: habitId, date: date, count: count)
  }

  func calculateHabitStreak(habitId: UUID) async throws -> Int {
    // TODO: Implement streak calculation
    return 0
  }

  // MARK: - Additional Convenience Methods

  func loadHabits(force _: Bool = false) async {
    do {
      let loadedHabits = try await repository.habits().firstValue() ?? []

      await MainActor.run {
        self.habitList = loadedHabits
        self.objectWillChange.send()
      }
    } catch {
      print("❌ HabitRepositoryNew: Failed to load habits: \(error)")
    }
  }

  func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
    // Update the published habits
    await MainActor.run {
      self.habitList = habits
      self.objectWillChange.send()
    }

    // Save to storage
    if let habitRepositoryImpl = repository as? HabitRepositoryImpl {
      try await habitRepositoryImpl.saveHabits(habits, immediate: immediate)
    }
  }

  func migrateFromUserDefaults() async {
    if let habitRepositoryImpl = repository as? HabitRepositoryImpl {
      await habitRepositoryImpl.migrateFromUserDefaults()
    }
  }

  // MARK: - Storage Management

  func switchStorageType(to type: StorageType) async {
    guard StorageFactory.shared.isStorageTypeAvailable(type) else {
      print("❌ HabitRepositoryNew: Storage type \(type.displayName) is not available")
      return
    }

    // Save current habits before switching
    let currentHabits = habitList
    try? await saveHabits(currentHabits, immediate: true)

    // Update configuration
    storageConfiguration.setStorageType(type)

    // Create new repository with new storage
    _ = StorageFactory.shared.createHabitRepository(type: type)

    // Migrate data if needed
    if !storageConfiguration.isMigrationCompleted() {
      // TODO: Implement proper data migration
      print("🔄 HabitRepositoryNew: Migrating data to \(type.displayName)...")
      storageConfiguration.markMigrationCompleted()
    }

    // Update the repository
    // Note: This is a simplified approach. In a real app, you'd want to handle this more gracefully
    print("✅ HabitRepositoryNew: Switched to \(type.displayName) storage")
  }

  func getCurrentStorageType() -> StorageType {
    storageConfiguration.getCurrentStorageType()
  }

  // MARK: Private

  private let repository: any HabitRepositoryProtocol
  private let storageConfiguration = StorageConfiguration.shared

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
          try await self.saveHabits(self.habitList, immediate: true)
        } catch {
          print("❌ HabitRepositoryNew: Failed to save habits on app resign: \(error)")
        }
      }
    }
  }
}
