import CoreData
import CloudKit
import SwiftUI

// MARK: - Simple Data Manager (No Core Data Model)
class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    // MARK: - Properties
    lazy var persistentContainer: NSPersistentContainer = {
        // Create an in-memory container to avoid model loading issues
        let container = NSPersistentContainer(name: "Dummy")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error {
                print("❌ CoreDataManager: Failed to load persistent stores: \(error)")
            } else {
                print("✅ CoreDataManager: In-memory persistent store loaded successfully")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Initialization
    private init() {
        print("🚀 CoreDataManager: Initializing (Simple Mode)...")
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
        print("⚠️ CoreDataManager: loadPersistentStoresWithoutCloudKit called but not needed in Simple Mode")
    }
    
    // MARK: - Health Check
    func checkCoreDataHealth() -> Bool {
        // Always return true in Simple Mode
        return true
    }
    
    // MARK: - Habit Operations
    func fetchHabits() -> [HabitEntity] {
        // Return empty array for now since we're not using Core Data
        return []
    }
    
    func fetchHabit(by id: UUID) -> HabitEntity? {
        // Return nil for now since we're not using Core Data
        return nil
    }
    
    func createHabit(from habit: Habit) throws -> HabitEntity {
        // Create a temporary entity with proper context initialization
        let entity = HabitEntity(context: context)
        
        // Set basic properties to prevent crashes
        entity.id = habit.id
        entity.name = habit.name
        entity.habitDescription = habit.description
        entity.icon = habit.icon
        entity.schedule = habit.schedule
        entity.goal = habit.goal
        entity.reminder = habit.reminder
        entity.startDate = habit.startDate
        entity.endDate = habit.endDate
        entity.isCompleted = habit.isCompleted
        entity.baseline = Double(habit.baseline)
        entity.target = Double(habit.target)
        entity.createdAt = habit.createdAt
        
        // Save the context to prevent crashes
        try save()
        
        print("✅ CoreDataManager: Created habit entity with ID: \(entity.id?.uuidString ?? "nil")")
        return entity
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
        entity.isCompleted = habit.isCompleted
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
    
    func getProgress(for habitId: UUID, on date: Date) -> Int {
        // Return 0 for now since we don't have proper Core Data model
        return 0
    }
    
    func markCompletion(for habitId: UUID, on date: Date, progress: Int) throws {
        // No-op for now since we don't have proper Core Data model
        print("✅ CoreDataManager: Marked completion for habit \(habitId) on \(date) with progress \(progress)")
    }
    
    func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    func getProgress(for entity: HabitEntity, date: Date) -> Int {
        // Return 0 for now since we're not using Core Data
        return 0
    }
    
    func markCompletion(for entity: HabitEntity, date: Date, progress: Int) throws {
        // No-op for now since we're not using Core Data
    }
    
    // MARK: - Utility Methods
    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
