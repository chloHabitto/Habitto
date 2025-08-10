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
        
        print("🔍 CoreDataManager: save() called, context.hasChanges = \(context.hasChanges)")
        
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
        
        // FIX: Explicitly fetch the completionHistory relationship to ensure it's loaded
        request.relationshipKeyPathsForPrefetching = ["completionHistory"]
        
        do {
            let habits = try context.fetch(request)
            print("🔍 CoreDataManager: Fetched \(habits.count) habits with prefetched relationships")
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
        let dateKey = Self.dateKey(for: date)
        print("🔍 CoreDataManager: markCompletion called for habit '\(habitEntity.name ?? "Unknown")' on \(dateKey) with progress \(progress)")
        
        // Check if a completion record already exists for this date
        if let existingRecords = habitEntity.completionHistory as? Set<CompletionRecordEntity>,
           let existingRecord = existingRecords.first(where: { $0.dateKey == dateKey }) {
            // Update existing record
            print("🔄 CoreDataManager: Updating existing completion record")
            existingRecord.progress = Int32(progress)
        } else {
            // Create new completion record
            print("🆕 CoreDataManager: Creating new completion record")
            let completionRecord = CompletionRecordEntity(context: context)
            completionRecord.dateKey = dateKey
            completionRecord.progress = Int32(progress)
            completionRecord.habit = habitEntity
            
            // FIX: Properly set up the bidirectional relationship
            // This ensures Core Data recognizes the change to habitEntity
            if let currentHistory = habitEntity.completionHistory as? Set<CompletionRecordEntity> {
                var updatedHistory = currentHistory
                updatedHistory.insert(completionRecord)
                habitEntity.completionHistory = updatedHistory as NSSet
                print("🔗 CoreDataManager: Updated existing completionHistory relationship with \(updatedHistory.count) records")
            } else {
                habitEntity.completionHistory = NSSet(array: [completionRecord])
                print("🔗 CoreDataManager: Created new completionHistory relationship with 1 record")
            }
        }
        
        print("💾 CoreDataManager: About to save context...")
        try save()
        print("✅ CoreDataManager: markCompletion completed successfully")
    }
    
    // MARK: - Get Progress
    func getProgress(for habitEntity: HabitEntity, date: Date) -> Int {
        let dateKey = Self.dateKey(for: date)
        
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
    
    // MARK: - Performance Optimizations
    
    /// Batch update multiple habits for better performance
    func batchUpdateHabits(_ habits: [Habit]) throws {
        let backgroundContext = persistentContainer.newBackgroundContext()
        backgroundContext.performAndWait {
            for habit in habits {
                // Find existing habit entity or create new one
                let request: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", habit.id as CVarArg)
                request.fetchLimit = 1
                
                if let existingHabit = try? backgroundContext.fetch(request).first {
                    // Update existing habit
                    existingHabit.name = habit.name
                    existingHabit.habitDescription = habit.description
                    existingHabit.icon = habit.icon
                    existingHabit.colorHex = habit.color.toHex()
                    existingHabit.schedule = habit.schedule
                    existingHabit.goal = habit.goal
                    existingHabit.habitType = habit.habitType.rawValue
                    existingHabit.startDate = habit.startDate
                    existingHabit.endDate = habit.endDate
                    existingHabit.reminder = habit.reminder
                    existingHabit.createdAt = habit.createdAt
                    existingHabit.isCompleted = habit.isCompleted
                    existingHabit.streak = Int32(habit.streak)
                    existingHabit.baseline = Int32(habit.baseline)
                    existingHabit.target = Int32(habit.target)
                } else {
                    // Create new habit entity
                    let habitEntity = HabitEntity(context: backgroundContext)
                    habitEntity.id = habit.id
                    habitEntity.name = habit.name
                    habitEntity.habitDescription = habit.description
                    habitEntity.icon = habit.icon
                    habitEntity.colorHex = habit.color.toHex()
                    habitEntity.schedule = habit.schedule
                    habitEntity.goal = habit.goal
                    habitEntity.habitType = habit.habitType.rawValue
                    habitEntity.startDate = habit.startDate
                    habitEntity.endDate = habit.endDate
                    habitEntity.reminder = habit.reminder
                    habitEntity.createdAt = habit.createdAt
                    habitEntity.isCompleted = habit.isCompleted
                    habitEntity.streak = Int32(habit.streak)
                    habitEntity.baseline = Int32(habit.baseline)
                    habitEntity.target = Int32(habit.target)
                }
            }
            
            // Save all changes at once
            try? backgroundContext.save()
        }
    }
    
    /// Optimized fetch request with batch size and prefetching
    func fetchHabitsOptimized() -> [HabitEntity] {
        let request: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        // Performance optimization: Batch size and prefetching
        request.fetchBatchSize = 20
        request.relationshipKeyPathsForPrefetching = [
            "completionHistory", 
            "usageRecords"
        ]
        
        // Performance optimization: Only fetch active habits
        request.predicate = NSPredicate(format: "endDate == nil OR endDate >= %@", Date() as NSDate)
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Optimized fetch error: \(error)")
            return []
        }
    }
    
    /// Fetch habits with specific type for better performance
    func fetchHabitsByType(_ type: HabitType) -> [HabitEntity] {
        let request: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
        request.predicate = NSPredicate(format: "habitType == %@", type.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchBatchSize = 20
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Type-based fetch error: \(error)")
            return []
        }
    }
    
    /// Background context operation for heavy data processing
    func performBackgroundOperation(_ operation: @escaping (NSManagedObjectContext) throws -> Void) {
        let backgroundContext = persistentContainer.newBackgroundContext()
        backgroundContext.perform {
            do {
                try operation(backgroundContext)
                try backgroundContext.save()
                
                // Performance optimization: Clear streak cache after data changes
                DispatchQueue.main.async {
                    StreakDataCalculator.clearCache()
                }
            } catch {
                print("❌ Background operation error: \(error)")
            }
        }
    }
    
    /// Clear streak cache when habits are updated
    func clearStreakCache() {
        DispatchQueue.main.async {
            StreakDataCalculator.clearCache()
        }
    }
}




