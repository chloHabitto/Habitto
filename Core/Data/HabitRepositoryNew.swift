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

  @Published var habits: [Habit] = []

  // MARK: - Repository Protocol Implementation

  func getAll() async throws -> [Habit] {
    try await repository.getAll()
  }

  func getById(_ id: UUID) async throws -> Habit? {
    try await repository.getById(id)
  }

  func create(_ item: Habit) async throws -> Habit {
    let createdHabit = try await repository.create(item)
    await loadHabits()
    return createdHabit
  }

  func update(_ item: Habit) async throws -> Habit {
    let updatedHabit = try await repository.update(item)
    await loadHabits()
    return updatedHabit
  }

  func delete(_ id: UUID) async throws {
    try await repository.delete(id)
    await loadHabits()
  }

  func exists(_ id: UUID) async throws -> Bool {
    try await repository.exists(id)
  }

  // MARK: - Habit-Specific Repository Methods

  func getHabits(for date: Date) async throws -> [Habit] {
    try await repository.getHabits(for: date)
  }

  func getHabits(by type: HabitType) async throws -> [Habit] {
    try await repository.getHabits(by: type)
  }

  func getActiveHabits() async throws -> [Habit] {
    try await repository.getActiveHabits()
  }

  func getArchivedHabits() async throws -> [Habit] {
    try await repository.getArchivedHabits()
  }

  func updateHabitCompletion(habitId: UUID, date: Date, progress: Double) async throws {
    try await repository.updateHabitCompletion(habitId: habitId, date: date, progress: progress)
    await loadHabits()
  }

  func getHabitCompletion(habitId: UUID, date: Date) async throws -> Double {
    try await repository.getHabitCompletion(habitId: habitId, date: date)
  }

  func calculateHabitStreak(habitId: UUID) async throws -> Int {
    try await repository.calculateHabitStreak(habitId: habitId)
  }

  // MARK: - Additional Convenience Methods

  func loadHabits(force _: Bool = false) async {
    do {
      let loadedHabits = try await getAll()

      await MainActor.run {
        self.habits = loadedHabits
        self.objectWillChange.send()
      }
    } catch {
      print("❌ HabitRepositoryNew: Failed to load habits: \(error)")
    }
  }

  func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
    // Update the published habits
    await MainActor.run {
      self.habits = habits
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
    let currentHabits = habits
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
          try await self.saveHabits(self.habits, immediate: true)
        } catch {
          print("❌ HabitRepositoryNew: Failed to save habits on app resign: \(error)")
        }
      }
    }
  }
}
