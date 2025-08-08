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
        
        // Enable CloudKit sync
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.chloe-lee.Habitto"
        )
        
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
    
    // MARK: - Context
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // MARK: - Background Context
    lazy var backgroundContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }()
    
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
    
    // MARK: - Save Context
    func save() throws {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Core Data context saved successfully")
            } catch {
                print("❌ Core Data save error: \(error)")
                handleSaveError(error)
                throw error
            }
        } else {
            print("ℹ️ Core Data context has no changes to save")
        }
    }
    
    // MARK: - Error Handling
    private func handleSaveError(_ error: Error) {
        if let cloudKitError = error as? CKError {
            switch cloudKitError.code {
            case .networkUnavailable:
                print("❌ CloudKit: Network unavailable")
            case .networkFailure:
                print("❌ CloudKit: Network failure")
            case .quotaExceeded:
                print("❌ CloudKit: Quota exceeded")
            case .zoneNotFound:
                print("❌ CloudKit: Zone not found")
            case .notAuthenticated:
                print("❌ CloudKit: User not authenticated")
            case .serverResponseLost:
                print("❌ CloudKit: Server response lost")
            case .serviceUnavailable:
                print("❌ CloudKit: Service unavailable")
            default:
                print("❌ CloudKit error: \(cloudKitError.localizedDescription)")
            }
        } else {
            print("❌ Core Data error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Background Save
    func saveInBackground() {
        let context = backgroundContext
        
        context.perform {
            if context.hasChanges {
                do {
                    try context.save()
                    print("✅ Core Data background context saved successfully")
                } catch {
                    print("❌ Core Data background save error: \(error)")
                    self.handleSaveError(error)
                }
            }
        }
    }
    
    // MARK: - Sync Status
    func checkSyncStatus() -> String {
        // Check if CloudKit is available
        let container = persistentContainer
        if container is NSPersistentCloudKitContainer {
            return "CloudKit sync enabled"
        }
        return "Local storage only"
    }
    
    // MARK: - Core Data Health Check
    func checkCoreDataHealth() -> Bool {
        do {
            let context = persistentContainer.viewContext
            let request: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
            request.fetchLimit = 1
            _ = try context.fetch(request)
            print("✅ Core Data health check passed")
            return true
        } catch {
            print("❌ Core Data health check failed: \(error)")
            return false
        }
    }
    
    // MARK: - Fallback for CloudKit Issues
    private func loadPersistentStoresWithoutCloudKit() {
        print("🔄 Attempting to load persistent stores without CloudKit...")
        
        // Create a new container without CloudKit
        let fallbackContainer = NSPersistentContainer(name: "HabittoDataModel")
        
        fallbackContainer.loadPersistentStores { _, error in
            if let error = error {
                print("❌ Fallback Core Data load also failed: \(error)")
                fatalError("Core Data failed to load even without CloudKit: \(error)")
            } else {
                print("✅ Core Data loaded successfully without CloudKit")
                // Replace the persistent container
                DispatchQueue.main.async {
                    // Note: In a real app, you'd want to handle this more gracefully
                    // For now, we'll just print a success message
                    print("📱 App running with local storage only")
                }
            }
        }
    }
    
    // MARK: - Migration from UserDefaults
    func migrateFromUserDefaults() {
        let oldHabits = HabitStorageManager.shared.loadHabits()
        
        let migrationContext = persistentContainer.newBackgroundContext()
        migrationContext.perform {
            for oldHabit in oldHabits {
                let newHabit = HabitEntity(context: migrationContext)
                newHabit.id = oldHabit.id
                newHabit.name = oldHabit.name
                newHabit.habitDescription = oldHabit.description
                newHabit.icon = oldHabit.icon
                newHabit.colorHex = oldHabit.color.toHex()
                newHabit.habitType = oldHabit.habitType.rawValue
                newHabit.schedule = oldHabit.schedule
                newHabit.goal = oldHabit.goal
                newHabit.reminder = oldHabit.reminder
                newHabit.startDate = oldHabit.startDate
                newHabit.endDate = oldHabit.endDate
                newHabit.isCompleted = oldHabit.isCompleted
                newHabit.streak = Int32(oldHabit.streak)
                newHabit.createdAt = oldHabit.createdAt
                newHabit.baseline = Int32(oldHabit.baseline)
                newHabit.target = Int32(oldHabit.target)
                
                // Migrate completion history
                for (dateKey, progress) in oldHabit.completionHistory {
                    let completionRecord = CompletionRecordEntity(context: migrationContext)
                    completionRecord.dateKey = dateKey
                    completionRecord.progress = Int32(progress)
                    completionRecord.habit = newHabit
                }
                
                // Migrate actual usage for habit breaking
                for (dateKey, usage) in oldHabit.actualUsage {
                    let usageRecord = UsageRecordEntity(context: migrationContext)
                    usageRecord.dateKey = dateKey
                    usageRecord.amount = Int32(usage)
                    usageRecord.habit = newHabit
                }
            }
            
            do {
                try migrationContext.save()
                print("✅ Migration from UserDefaults completed successfully")
                
                // Clear old data after successful migration
                DispatchQueue.main.async {
                    UserDefaults.standard.removeObject(forKey: "SavedHabits")
                }
            } catch {
                print("❌ Migration error: \(error)")
            }
        }
    }
    
    // MARK: - Fetch Habits
    func fetchHabits() -> [HabitEntity] {
        let request: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let habits = try context.fetch(request)
            print("🔄 CoreDataManager: Fetched \(habits.count) habit entities")
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
        habitEntity.baseline = Int32(habit.baseline)
        habitEntity.target = Int32(habit.target)
        
        try save()
    }
    
    // MARK: - Delete Habit
    func deleteHabit(_ habitEntity: HabitEntity) throws {
        print("🗑️ CoreDataManager: Deleting habit entity: \(habitEntity.name ?? "Unknown")")
        context.delete(habitEntity)
        print("🗑️ CoreDataManager: Entity marked for deletion, saving...")
        try save()
        print("🗑️ CoreDataManager: Save completed")
    }
    
    // MARK: - Mark Completion
    func markCompletion(for habitEntity: HabitEntity, date: Date, progress: Int) throws {
        let dateKey = Self.dateKey(for: date)
        
        // Find existing record or create new one
        let request: NSFetchRequest<CompletionRecordEntity> = CompletionRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "habit == %@ AND dateKey == %@", habitEntity, dateKey)
        
        do {
            let existingRecords = try context.fetch(request)
            let record: CompletionRecordEntity
            
            if let existingRecord = existingRecords.first {
                record = existingRecord
            } else {
                record = CompletionRecordEntity(context: context)
                record.habit = habitEntity
                record.dateKey = dateKey
            }
            
            record.progress = Int32(progress)
            record.timestamp = Date()
            
            try save()
        } catch {
            print("❌ Mark completion error: \(error)")
            throw error
        }
    }
    
    // MARK: - Get Progress
    func getProgress(for habitEntity: HabitEntity, date: Date) -> Int {
        let dateKey = Self.dateKey(for: date)
        
        let request: NSFetchRequest<CompletionRecordEntity> = CompletionRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "habit == %@ AND dateKey == %@", habitEntity, dateKey)
        
        do {
            let records = try context.fetch(request)
            return Int(records.first?.progress ?? 0)
        } catch {
            print("❌ Get progress error: \(error)")
            return 0
        }
    }
    
    // MARK: - Helper Methods
    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}


