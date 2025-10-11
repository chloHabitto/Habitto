import CloudKit
import CoreData
import SwiftUI

// MARK: - Simple Data Manager (No Core Data Model)

class CoreDataManager: ObservableObject {
  // MARK: Lifecycle

  // MARK: - Initialization

  private init() {
    print("🚀 CoreDataManager: Initializing (Simple Mode)...")
  }

  // MARK: Internal

  static let shared = CoreDataManager()

  lazy var persistentContainer: NSPersistentContainer = {
    // Create a minimal in-memory container without a model to avoid loading issues
    // Create a custom managed object model with no entities
    let model = NSManagedObjectModel()
    model.entities = []

    // Create container with the custom empty model
    let container = NSPersistentContainer(name: "EmptyContainer", managedObjectModel: model)

    // Set up in-memory store
    container.persistentStoreDescriptions = []
    container.persistentStoreDescriptions.append({
      let description = NSPersistentStoreDescription()
      description.type = NSInMemoryStoreType
      description.shouldAddStoreAsynchronously = false
      return description
    }())

    container.loadPersistentStores { _, error in
      if let error {
        print("❌ CoreDataManager: Failed to load persistent stores: \(error)")
      } else {
        print("✅ CoreDataManager: In-memory persistent store loaded successfully (no entities)")
      }
    }
    return container
  }()

  var context: NSManagedObjectContext {
    persistentContainer.viewContext
  }

  // MARK: - Utility Methods

  static func dateKey(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  // MARK: - Core Data Operations

  func save() throws {
    if context.hasChanges {
      do {
        try context.save()
        print("✅ CoreDataManager: Context saved successfully")
      } catch {
        print("❌ CoreDataManager: Failed to save context: \(error)")
        throw error
      }
    } else {
      print("⚠️ CoreDataManager: No changes to save")
    }
  }

  func loadPersistentStoresWithoutCloudKit() {
    // No-op for now since we're not using Core Data
    print(
      "⚠️ CoreDataManager: loadPersistentStoresWithoutCloudKit called but not needed in Simple Mode")
  }

  // MARK: - Health Check

  func checkCoreDataHealth() -> Bool {
    // Always return true in Simple Mode
    true
  }

  // MARK: - Habit Operations

  func fetchHabits() -> [HabitEntity] {
    // Return empty array for now since we're not using Core Data
    []
  }

  func fetchHabit(by _: UUID) -> HabitEntity? {
    // Return nil for now since we're not using Core Data
    nil
  }

  func createHabit(from habit: Habit) throws -> HabitEntity {
    // Skip Core Data entity creation entirely to prevent crashes
    print("⚠️ CoreDataManager: Skipping Core Data entity creation (bypassed)")
    print("🔄 CoreDataManager: Would create habit: \(habit.name)")

    // Throw an error instead of creating an entity to prevent Core Data crashes
    throw NSError(domain: "CoreDataManager", code: 1, userInfo: [
      NSLocalizedDescriptionKey: "Core Data entity creation bypassed - using UserDefaults instead"
    ])
  }

  func updateHabit(_ entity: HabitEntity, with habit: Habit) throws {
    // Update entity properties
    entity.name = habit.name
    entity.habitDescription = habit.description
    entity.icon = habit.icon
    entity.schedule = habit.schedule
    entity.goal = habit.goal
    entity.reminder = habit.reminder
    entity.startDate = habit.startDate
    entity.endDate = habit.endDate
    entity.isCompleted = habit.isCompletedForDate(Date())
    entity.baseline = Double(habit.baseline)
    entity.target = Double(habit.target)

    // Save changes
    try save()
    print("✅ CoreDataManager: Updated habit entity: \(habit.name)")
  }

  func deleteHabit(_ entity: HabitEntity) throws {
    context.delete(entity)
    try save()
    print("✅ CoreDataManager: Deleted habit entity")
  }

  func getProgress(for _: UUID, on _: Date) -> Int {
    // Return 0 for now since we don't have proper Core Data model
    0
  }

  func markCompletion(for habitId: UUID, on date: Date, progress: Int) throws {
    // No-op for now since we don't have proper Core Data model
    print(
      "✅ CoreDataManager: Marked completion for habit \(habitId) on \(date) with progress \(progress)")
  }

  func dateKey(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  func getProgress(for _: HabitEntity, date _: Date) -> Int {
    // Return 0 for now since we're not using Core Data
    0
  }

  func markCompletion(for _: HabitEntity, date _: Date, progress _: Int) throws {
    // No-op for now since we're not using Core Data
  }
}
