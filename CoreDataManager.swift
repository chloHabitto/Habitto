import CoreData
import CloudKit
import SwiftUI

// MARK: - Core Data Manager
class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "HabittoDataModel")
        
        // Configure Core Data store
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        // Configure Core Data options with CloudKit
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Temporarily disable CloudKit sync to test local persistence
        // description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
        //     containerIdentifier: "iCloud.com.chloe-lee.Habitto"
        // )
        
        // Load the persistent stores
        container.loadPersistentStores { _, error in
            if let error = error {
                print("❌ Core Data load error: \(error)")
                
                // Check if it's a CloudKit container error
                if let nsError = error as NSError?,
                   nsError.domain == "CKErrorDomain" && nsError.code == 1014 {
                    print("⚠️ CloudKit container not configured. Falling back to local storage.")
                    print("📋 Please create CloudKit container: iCloud.com.chloe-lee.Habitto")
                    
                    // Try to load without CloudKit
                    self.loadPersistentStoresWithoutCloudKit()
                } else {
                    fatalError("Core Data failed to load persistent stores: \(error)")
                }
            } else {
                print("✅ Core Data persistent stores loaded successfully")
            }
        }
        
        return container
    }()
    
    // MARK: - Properties
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Setup
    func setupNotifications() {
        // Local context changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(managedObjectContextObjectsDidChange),
            name: NSManagedObjectContext.didSaveObjectsNotification,
            object: nil
        )
        
        // CloudKit remote changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(persistentStoreRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
        
        // CloudKit import/export notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(persistentHistoryChange),
            name: NSManagedObjectContext.didSaveObjectsNotification,
            object: nil
        )
    }
    
    @objc func managedObjectContextObjectsDidChange(_ notification: Notification) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    @objc func persistentStoreRemoteChange(_ notification: Notification) {
        print("🔄 CloudKit remote change detected")
        DispatchQueue.main.async {
            self.objectWillChange.send()
            // Refresh the view context to get latest changes
            self.context.refreshAllObjects()
        }
    }
    
    @objc func persistentHistoryChange(_ notification: Notification) {
        print("🔄 CloudKit history change detected")
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Core Data Health Check
    func checkCoreDataHealth() -> Bool {
        do {
            // Try to perform a simple fetch to test Core Data
            let request: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
            request.fetchLimit = 1
            _ = try context.fetch(request)
            return true
        } catch {
            print("❌ CoreDataManager: Core Data health check failed: \(error)")
            return false
        }
    }
    
    // MARK: - Load Persistent Stores Without CloudKit
    private func loadPersistentStoresWithoutCloudKit() {
        print("🔄 CoreDataManager: Loading persistent stores without CloudKit...")
        
        // Create a new container without CloudKit
        let container = NSPersistentContainer(name: "HabittoDataModel")
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("❌ CoreDataManager: Failed to load persistent stores without CloudKit: \(error)")
                fatalError("Core Data failed to load persistent stores: \(error)")
            } else {
                print("✅ CoreDataManager: Persistent stores loaded without CloudKit")
                // Update the persistent container reference
                self.persistentContainer = container
            }
        }
    }

    // MARK: - Force Save All Changes
    func forceSaveAllChanges() {
        print("🔄 CoreDataManager: Force saving all changes...")
        
        do {
            try context.save()
            print("✅ CoreDataManager: View context saved")
        } catch {
            print("❌ CoreDataManager: Failed to save view context: \(error)")
        }
        
        print("✅ CoreDataManager: All changes saved")
    }
    
    // MARK: - Save
    func save() throws {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            try context.save()
            print("✅ CoreDataManager: Context saved successfully")
        } else {
            print("ℹ️ CoreDataManager: No pending changes to save")
        }
    }
    
    // MARK: - Fetch Habits
    func fetchHabits() -> [HabitEntity] {
        let request: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let habits = try context.fetch(request)
            return habits
        } catch {
            print("❌ Fetch habits error: \(error)")
            return []
        }
    }
    
    // MARK: - Create Habit
    func createHabit(from habit: Habit) throws -> HabitEntity {
        let habitEntity = HabitEntity(context: context)
        habitEntity.id = habit.id
        habitEntity.name = habit.name
        habitEntity.habitDescription = habit.description
        habitEntity.icon = habit.icon
        habitEntity.colorHex = habit.color.toHex()
        habitEntity.habitType = habit.habitType.rawValue
        habitEntity.schedule = habit.schedule
        habitEntity.goal = habit.goal
        habitEntity.reminder = habit.reminder
        habitEntity.startDate = habit.startDate
        habitEntity.endDate = habit.endDate
        habitEntity.isCompleted = habit.isCompleted
        habitEntity.streak = Int32(habit.streak)
        habitEntity.createdAt = habit.createdAt
        habitEntity.baseline = Int32(habit.baseline)
        habitEntity.target = Int32(habit.target)
        
        try save()
        return habitEntity
    }
    
    // MARK: - Delete Habit
    func deleteHabit(_ habitEntity: HabitEntity) throws {
        context.delete(habitEntity)
        try save()
    }
    
    // MARK: - Update Habit
    func updateHabit(_ habitEntity: HabitEntity, with habit: Habit) throws {
        habitEntity.name = habit.name
        habitEntity.habitDescription = habit.description
        habitEntity.icon = habit.icon
        habitEntity.colorHex = habit.color.toHex()
        habitEntity.habitType = habit.habitType.rawValue
        habitEntity.schedule = habit.schedule
        habitEntity.goal = habit.goal
        habitEntity.reminder = habit.reminder
        habitEntity.startDate = habit.startDate
        habitEntity.endDate = habit.endDate
        habitEntity.isCompleted = habit.isCompleted
        habitEntity.streak = Int32(habit.streak)
        habitEntity.createdAt = habit.createdAt
        habitEntity.baseline = Int32(habit.baseline)
        habitEntity.target = Int32(habit.target)
        
        try save()
    }
    
    // MARK: - Mark Completion
    func markCompletion(for habitEntity: HabitEntity, date: Date, progress: Int) throws {
        let dateKey = DateUtils.dateKey(for: date)
        
        // Check if a completion record already exists for this date
        if let existingRecords = habitEntity.completionHistory as? Set<CompletionRecordEntity>,
           let existingRecord = existingRecords.first(where: { $0.dateKey == dateKey }) {
            // Update existing record
            existingRecord.progress = Int32(progress)
        } else {
            // Create new completion record
            let completionRecord = CompletionRecordEntity(context: context)
            completionRecord.dateKey = dateKey
            completionRecord.progress = Int32(progress)
            completionRecord.habit = habitEntity
        }
        
        try save()
    }
    
    // MARK: - Get Progress
    func getProgress(for habitEntity: HabitEntity, date: Date) -> Int {
        let dateKey = DateUtils.dateKey(for: date)
        
        if let completionRecords = habitEntity.completionHistory as? Set<CompletionRecordEntity>,
           let record = completionRecords.first(where: { $0.dateKey == dateKey }) {
            return Int(record.progress)
        }
        
        return 0
    }
    
    // MARK: - Helper Methods
    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}




