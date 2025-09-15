import CoreData
import SwiftUI
import UserNotifications

// MARK: - Temporary Core Data Entity Stubs (Missing from model)
// These are temporary stubs until the Core Data model is restored

class HabitEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var reminders: NSSet?
    @NSManaged var completionHistory: NSSet?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var lastCompleted: Date?
    @NSManaged var isArchived: Bool
    @NSManaged var color: String?
    @NSManaged var emoji: String?
    @NSManaged var streak: Int32
    @NSManaged var frequency: String?
    @NSManaged var targetAmount: Double
    @NSManaged var unit: String?
    @NSManaged var difficultyLevel: Int16
    @NSManaged var notes: String?
    @NSManaged var isActive: Bool
    @NSManaged var reminderEnabled: Bool
    @NSManaged var weekdays: String?
    @NSManaged var scheduleDays: String?
    @NSManaged var scheduleTime: Date?
    @NSManaged var habitType: String?
    @NSManaged var timeOfDay: String?
    @NSManaged var category: String?
    @NSManaged var difficultyLogs: NSSet?
    @NSManaged var colorHex: String?
    @NSManaged var habitDescription: String?
    @NSManaged var icon: String?
    @NSManaged var schedule: String?
    @NSManaged var goal: String?
    @NSManaged var reminder: String?
    @NSManaged var startDate: Date?
    @NSManaged var endDate: Date?
    @NSManaged var isCompleted: Bool
    @NSManaged var baseline: Double
    @NSManaged var target: Double
    @NSManaged var usageRecords: NSSet?
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<HabitEntity> {
        return NSFetchRequest<HabitEntity>(entityName: "HabitEntity")
    }
}

class ReminderItemEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var time: Date?
    @NSManaged var isActive: Bool
    @NSManaged var message: String?
    @NSManaged var habit: HabitEntity?
}

class CompletionRecordEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var timestamp: Date?
    @NSManaged var progress: Double
    @NSManaged var date: Date?
    @NSManaged var habit: HabitEntity?
    @NSManaged var notes: String?
    @NSManaged var isCompleted: Bool
    @NSManaged var dateKey: String?
    @NSManaged var timeBlock: String?
}

class DifficultyLogEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var timestamp: Date?
    @NSManaged var difficultyLevel: Int16
    @NSManaged var difficulty: Int16  // Legacy property
    @NSManaged var context: String?
    @NSManaged var habit: HabitEntity?
    @NSManaged var notes: String?
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DifficultyLogEntity> {
        return NSFetchRequest<DifficultyLogEntity>(entityName: "DifficultyLogEntity")
    }
}

class UsageRecordEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var timestamp: Date?
    @NSManaged var action: String?
    @NSManaged var habit: HabitEntity?
    @NSManaged var dateKey: String?
    @NSManaged var amount: Double
}

class NoteEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var content: String?
    @NSManaged var timestamp: Date?
    @NSManaged var habit: HabitEntity?
    @NSManaged var title: String?
    @NSManaged var tags: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
}

// MARK: - Core Data Adapter
class CoreDataAdapter: ObservableObject {
    static let shared = CoreDataAdapter()
    
    @Published var habits: [Habit] = []
    
    private let coreDataManager = CoreDataManager.shared
    private let cloudKitManager = CloudKitManager.shared
    
    private init() {
        initializeSync()
        
        // Check Core Data health
        if coreDataManager.checkCoreDataHealth() {
            print("✅ CoreDataAdapter: Core Data is healthy, loading habits...")
            loadHabits(force: true)
            
            // Clean up any existing duplicate habits
            cleanupDuplicateHabits()
            
            // Only migrate from UserDefaults if Core Data is empty and this is the first load
            if habits.isEmpty {
                print("⚠️ CoreDataAdapter: No habits found in Core Data, checking UserDefaults for migration...")
                let userDefaultsHabits = HabitStorageManager.shared.loadHabits()
                if !userDefaultsHabits.isEmpty {
                    print("🔄 CoreDataAdapter: Found \(userDefaultsHabits.count) habits in UserDefaults, migrating...")
                    migrateFromUserDefaults()
                }
            }
        } else {
            print("⚠️ CoreDataAdapter: Core Data health check failed, falling back to UserDefaults...")
            let userDefaultsHabits = HabitStorageManager.shared.loadHabits()
            habits = userDefaultsHabits
            print("✅ CoreDataAdapter: Loaded \(habits.count) habits from UserDefaults")
        }
    }
    
    // MARK: - Initialize Sync
    private func initializeSync() {
        // Initialize CloudKit sync
        cloudKitManager.initializeCloudKitSync()
        
        // Monitor app lifecycle to reload data when app becomes active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    // MARK: - App Lifecycle Handling
    @objc private func appDidBecomeActive() {
        print("🔄 CoreDataAdapter: App became active, reloading habits...")
        
        // Force reload habits from Core Data
        loadHabits(force: true)
        
        // Also check for any pending changes
        // Note: CoreDataManager doesn't have saveIfNeeded method
        
        print("✅ CoreDataAdapter: Habits reloaded after app became active")
    }
    
    // MARK: - Debug Methods
    func debugHabitsState() {
        print("🔍 CoreDataAdapter: Debug - Current habits state:")
        print("  - Published habits count: \(habits.count)")
        print("  - Core Data entities count: \(coreDataManager.fetchHabits().count)")
        
        // List all published habits
        print("📋 Published habits:")
        for (index, habit) in habits.enumerated() {
            print("  \(index): \(habit.name) (ID: \(habit.id), reminders: \(habit.reminders.count))")
        }
        
        // List all Core Data entities
        let entities = coreDataManager.fetchHabits()
        print("📋 Core Data entities:")
        for (index, entity) in entities.enumerated() {
            let remindersCount = (entity.reminders as? Set<ReminderItemEntity>)?.count ?? 0
            print("  \(index): \(entity.name ?? "nil") (ID: \(entity.id?.uuidString ?? "nil"), reminders: \(remindersCount))")
        }
        
        // Check for any habits without IDs
        let invalidHabits = habits.filter { $0.id == UUID() }
        if !invalidHabits.isEmpty {
            print("⚠️ CoreDataAdapter: Found \(invalidHabits.count) habits with default UUIDs")
        }
        
        // Check for duplicate IDs
        var seenIds: Set<UUID> = []
        var duplicates: [Habit] = []
        for habit in habits {
            if seenIds.contains(habit.id) {
                duplicates.append(habit)
            } else {
                seenIds.insert(habit.id)
            }
        }
        
        if !duplicates.isEmpty {
            print("⚠️ CoreDataAdapter: Found \(duplicates.count) duplicate habits:")
            for duplicate in duplicates {
                print("    - \(duplicate.name) (ID: \(duplicate.id))")
            }
        }
        
        print("✅ CoreDataAdapter: Debug completed")
    }
    
    // Emergency recovery method
    func recoverMissingHabits() {
        print("🚨 CoreDataAdapter: Starting emergency habit recovery...")
        
        // Force reload all entities from Core Data
        let entities = coreDataManager.fetchHabits()
        print("🔍 Found \(entities.count) entities in Core Data")
        
        // Try to convert each entity individually to catch any errors
        var recoveredHabits: [Habit] = []
        for (index, entity) in entities.enumerated() {
            let habit = entity.toHabit()
            recoveredHabits.append(habit)
            print("✅ Recovered habit \(index): \(habit.name)")
        }
        
        // Update the habits array
        DispatchQueue.main.async {
            self.habits = recoveredHabits
            self.objectWillChange.send()
            print("🚨 Recovery complete: \(recoveredHabits.count) habits recovered")
        }
    }
    
    // MARK: - Load Habits
    func loadHabits(force: Bool = false) {
        print("🔄 CoreDataAdapter: loadHabits called (force: \(force))")
        
        // Always load if force is true, or if habits is empty
        if !force && !habits.isEmpty {
            print("ℹ️ CoreDataAdapter: Skipping load - habits not empty and not forced")
            return
        }
        
        let entities = coreDataManager.fetchHabits()
        print("🔍 CoreDataAdapter: Fetched \(entities.count) entities from Core Data")
        
        // Debug each entity before conversion
        for (index, entity) in entities.enumerated() {
            print("🔍 Entity \(index): name=\(entity.name ?? "nil"), id=\(entity.id?.uuidString ?? "nil")")
            if let reminders = entity.reminders as? Set<ReminderItemEntity> {
                print("  📅 Has \(reminders.count) reminders")
                for reminder in reminders {
                    print("    - Reminder: id=\(reminder.id?.uuidString ?? "nil"), time=\(reminder.time?.description ?? "nil"), active=\(reminder.isActive)")
                }
            } else {
                print("  📅 No reminders or reminders is nil")
            }
        }
        
        let loadedHabits = entities.map { $0.toHabit() }
        
        print("🔍 CoreDataAdapter: Converted to \(loadedHabits.count) habits")
        
        // Debug each converted habit
        for (index, habit) in loadedHabits.enumerated() {
            print("🔍 Habit \(index): name=\(habit.name), id=\(habit.id), reminders=\(habit.reminders.count)")
        }
        
        // Deduplicate habits by ID to prevent duplicates
        var uniqueHabits: [Habit] = []
        var seenIds: Set<UUID> = []
        
        for habit in loadedHabits {
            if !seenIds.contains(habit.id) {
                uniqueHabits.append(habit)
                seenIds.insert(habit.id)
            } else {
                print("⚠️ CoreDataAdapter: Found duplicate habit with ID: \(habit.id), name: \(habit.name) - skipping")
            }
        }
        
        // Always update on main thread and notify observers
        DispatchQueue.main.async {
            self.habits = uniqueHabits
            print("✅ CoreDataAdapter: Updated habits array with \(uniqueHabits.count) unique habits")
            
            // Debug final habits array
            for (index, habit) in uniqueHabits.enumerated() {
                print("🔍 Final Habit \(index): name=\(habit.name), id=\(habit.id)")
            }
            
            // Notify observers that habits have changed
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Save Difficulty Rating
    func saveDifficultyRating(habitId: UUID, date: Date, difficulty: Int32) {
        let context = coreDataManager.persistentContainer.viewContext
        
        // Create new DifficultyLogEntity
        let difficultyLog = DifficultyLogEntity(context: context)
        difficultyLog.difficulty = Int16(difficulty)
        difficultyLog.timestamp = date
        difficultyLog.context = "Daily completion rating"
        
        // Find the habit and associate it
        if let habitEntity = coreDataManager.fetchHabit(by: habitId) {
            difficultyLog.habit = habitEntity
        }
        
        // Save to Core Data
        do {
            try context.save()
            print("✅ CoreDataAdapter: Saved difficulty rating \(difficulty) for habit \(habitId) on \(date)")
        } catch {
            print("❌ CoreDataAdapter: Failed to save difficulty rating: \(error)")
        }
    }
    
    // MARK: - Fetch Difficulty Data
    func fetchDifficultiesForHabit(_ habitId: UUID, month: Int, year: Int) -> [Double] {
        let context = coreDataManager.persistentContainer.viewContext
        let request: NSFetchRequest<DifficultyLogEntity> = DifficultyLogEntity.fetchRequest()
        
        // Create date range for the specified month and year
        let calendar = Calendar.current
        var startDateComponents = DateComponents()
        startDateComponents.year = year
        startDateComponents.month = month
        startDateComponents.day = 1
        startDateComponents.hour = 0
        startDateComponents.minute = 0
        startDateComponents.second = 0
        
        guard let startDate = calendar.date(from: startDateComponents) else { return [] }
        
        var endDateComponents = DateComponents()
        endDateComponents.year = year
        endDateComponents.month = month + 1
        endDateComponents.day = 1
        endDateComponents.hour = 0
        endDateComponents.minute = 0
        endDateComponents.second = 0
        
        guard let endDate = calendar.date(from: endDateComponents) else { return [] }
        
        // Filter by habit ID and date range
        request.predicate = NSPredicate(
            format: "habit.id == %@ AND timestamp >= %@ AND timestamp < %@",
            habitId as CVarArg,
            startDate as NSDate,
            endDate as NSDate
        )
        
        do {
            let results = try context.fetch(request)
            return results.map { Double($0.difficulty) }
        } catch {
            print("❌ CoreDataAdapter: Failed to fetch difficulties: \(error)")
            return []
        }
    }
    
    func fetchAllDifficulties(month: Int, year: Int) -> [Double] {
        let context = coreDataManager.persistentContainer.viewContext
        let request: NSFetchRequest<DifficultyLogEntity> = DifficultyLogEntity.fetchRequest()
        
        // Create date range for the specified month and year
        let calendar = Calendar.current
        var startDateComponents = DateComponents()
        startDateComponents.year = year
        startDateComponents.month = month
        startDateComponents.day = 1
        startDateComponents.hour = 0
        startDateComponents.minute = 0
        startDateComponents.second = 0
        
        guard let startDate = calendar.date(from: startDateComponents) else { return [] }
        
        var endDateComponents = DateComponents()
        endDateComponents.year = year
        endDateComponents.month = month + 1
        endDateComponents.day = 1
        endDateComponents.hour = 0
        endDateComponents.minute = 0
        endDateComponents.second = 0
        
        guard let endDate = calendar.date(from: endDateComponents) else { return [] }
        
        // Filter by date range
        request.predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp < %@",
            startDate as NSDate,
            endDate as NSDate
        )
        
        do {
            let results = try context.fetch(request)
            return results.map { Double($0.difficulty) }
        } catch {
            print("❌ CoreDataAdapter: Failed to fetch all difficulties: \(error)")
            return []
        }
    }
    
    // MARK: - Save Habits
    func saveHabits(_ habits: [Habit]) {
        do {
            print("🔄 CoreDataAdapter: saveHabits called with \(habits.count) habits")
            
            // FIX: Instead of deleting all habits, update existing ones to preserve completion records
            let existingEntities = coreDataManager.fetchHabits()
            
            for habit in habits {
                if let existingEntity = existingEntities.first(where: { $0.id == habit.id }) {
                    // Update existing habit (preserves completion records)
                    try coreDataManager.updateHabit(existingEntity, with: habit)
                    print("🔄 CoreDataAdapter: Updated existing habit: \(habit.name)")
                } else {
                    // Create new habit if it doesn't exist
                    _ = try coreDataManager.createHabit(from: habit)
                    print("🆕 CoreDataAdapter: Created new habit: \(habit.name)")
                }
            }
            
            // Remove habits that no longer exist
            for entity in existingEntities {
                if !habits.contains(where: { $0.id == entity.id }) {
                    try coreDataManager.deleteHabit(entity)
                    print("🗑️ CoreDataAdapter: Deleted habit: \(entity.name ?? "Unknown")")
                }
            }
            
            loadHabits(force: true)
            print("✅ CoreDataAdapter: Habits saved/updated successfully")
        } catch {
            print("❌ CoreDataAdapter: Failed to save habits in Core Data: \(error)")
            print("🔄 CoreDataAdapter: Falling back to UserDefaults...")
            
            // Fallback to UserDefaults
            HabitStorageManager.shared.saveHabits(habits, immediate: true)
            self.habits = habits
            print("✅ CoreDataAdapter: Habits saved to UserDefaults")
        }
    }
    
    // MARK: - Create Habit
    func createHabit(_ habit: Habit) {
        print("🔄 CoreDataAdapter: Creating habit: \(habit.name)")
        print("🔄 CoreDataAdapter: Current habits count before creation: \(habits.count)")
        
        // Try to create in Core Data first
        do {
            let createdEntity = try coreDataManager.createHabit(from: habit)
            print("🔄 CoreDataAdapter: Habit created in Core Data with ID: \(createdEntity.id?.uuidString ?? "nil")")
            
            // ✅ FIX: Immediately add the habit to the published array for instant UI update
            // This ensures the UI shows the new habit immediately
            DispatchQueue.main.async {
                var updatedHabits = self.habits
                updatedHabits.append(habit)
                self.habits = updatedHabits
                print("✅ CoreDataAdapter: Habit immediately added to published array, new count: \(self.habits.count)")
                
                // Also reload from Core Data to ensure consistency
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🔄 CoreDataAdapter: Reloading habits from Core Data for consistency...")
                    self.loadHabits(force: true)
                }
            }
            
        } catch {
            print("❌ CoreDataAdapter: Failed to create habit in Core Data: \(error)")
            print("🔄 CoreDataAdapter: Falling back to UserDefaults...")
            
            // Fallback to UserDefaults
            var currentHabits = HabitStorageManager.shared.loadHabits()
            currentHabits.append(habit)
            HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
            
            // Update the published habits on main thread
            DispatchQueue.main.async {
                self.habits = currentHabits
                print("✅ CoreDataAdapter: Habit saved to UserDefaults, total: \(self.habits.count)")
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Update Habit
    func updateHabit(_ habit: Habit) {
        print("🔄 CoreDataAdapter: updateHabit called for: \(habit.name) (ID: \(habit.id))")
        print("🔄 CoreDataAdapter: Habit has \(habit.reminders.count) reminders")
        
        let habitEntities = coreDataManager.fetchHabits()
        print("🔍 CoreDataAdapter: Found \(habitEntities.count) entities in database")
        
        if let entity = habitEntities.first(where: { $0.id == habit.id }) {
            print("✅ CoreDataAdapter: Found matching entity for habit: \(habit.name)")
            print("🔍 CoreDataAdapter: Entity before update - reminders count: \((entity.reminders as? Set<ReminderItemEntity>)?.count ?? 0)")
            
            do {
                try coreDataManager.updateHabit(entity, with: habit)
                print("✅ CoreDataAdapter: Habit updated in Core Data")
                print("🔍 CoreDataAdapter: Entity after update - reminders count: \((entity.reminders as? Set<ReminderItemEntity>)?.count ?? 0)")
                loadHabits(force: true)
            } catch {
                print("❌ CoreDataAdapter: Failed to update habit in Core Data: \(error)")
                print("🔄 CoreDataAdapter: Falling back to UserDefaults...")
                
                // Fallback to UserDefaults
                var currentHabits = HabitStorageManager.shared.loadHabits()
                if let index = currentHabits.firstIndex(where: { $0.id == habit.id }) {
                    currentHabits[index] = habit
                    HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
                    habits = currentHabits
                    print("✅ CoreDataAdapter: Habit updated in UserDefaults")
                }
            }
        } else {
            print("❌ CoreDataAdapter: No matching entity found for habit: \(habit.name)")
            print("🔍 CoreDataAdapter: Available entity IDs:")
            for entity in habitEntities {
                print("  - Entity: \(entity.name ?? "nil") (ID: \(entity.id?.uuidString ?? "nil"))")
            }
            print("🔄 CoreDataAdapter: Trying to find by name instead...")
            
            // Try to find by name as a fallback
            if let entity = habitEntities.first(where: { $0.name == habit.name }) {
                print("✅ CoreDataAdapter: Found entity by name: \(entity.name ?? "nil")")
                do {
                    try coreDataManager.updateHabit(entity, with: habit)
                    print("✅ CoreDataAdapter: Habit updated in Core Data by name")
                    loadHabits(force: true)
                } catch {
                    print("❌ CoreDataAdapter: Failed to update habit by name in Core Data: \(error)")
                }
            } else {
                print("❌ CoreDataAdapter: No entity found by name either for habit: \(habit.name)")
            }
        }
    }
    
    // MARK: - Delete Habit
    func deleteHabit(_ habit: Habit) {
        print("🗑️ CoreDataAdapter: Starting delete for habit: \(habit.name)")
        
        // Remove all notifications for this habit first
        NotificationManager.shared.removeAllNotifications(for: habit)
        print("🗑️ CoreDataAdapter: Removed all notifications for habit: \(habit.name)")
        
        // Immediately remove from published habits for instant UI update
        DispatchQueue.main.async {
            var updatedHabits = self.habits
            updatedHabits.removeAll { $0.id == habit.id }
            self.habits = updatedHabits
            print("🗑️ CoreDataAdapter: Habit immediately removed from published habits, new count: \(self.habits.count)")
        }
        
        let habitEntities = coreDataManager.fetchHabits()
        
        if let entity = habitEntities.first(where: { $0.id == habit.id }) {
            print("🗑️ CoreDataAdapter: Found matching entity, deleting...")
            do {
                try coreDataManager.deleteHabit(entity)
                print("🗑️ CoreDataAdapter: Entity deleted from Core Data")
                
                // Also remove from UserDefaults backup to prevent restoration
                var currentHabits = HabitStorageManager.shared.loadHabits()
                currentHabits.removeAll { $0.id == habit.id }
                HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
                print("🗑️ CoreDataAdapter: Habit also removed from UserDefaults backup")
            } catch {
                print("❌ CoreDataAdapter: Failed to delete habit in Core Data: \(error)")
                print("🔄 CoreDataAdapter: Falling back to UserDefaults...")
                
                // Fallback to UserDefaults
                var currentHabits = HabitStorageManager.shared.loadHabits()
                currentHabits.removeAll { $0.id == habit.id }
                HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
                print("✅ CoreDataAdapter: Habit deleted from UserDefaults")
            }
        } else {
            print("❌ CoreDataAdapter: No matching entity found for habit: \(habit.name)")
            print("❌ CoreDataAdapter: Trying to find by name instead...")
            
            // Try to find by name as a fallback
            if let entity = habitEntities.first(where: { $0.name == habit.name }) {
                print("🗑️ CoreDataAdapter: Found entity by name, deleting...")
                do {
                    try coreDataManager.deleteHabit(entity)
                    print("🗑️ CoreDataAdapter: Entity deleted by name from Core Data")
                    
                    // Also remove from UserDefaults backup to prevent restoration
                    var currentHabits = HabitStorageManager.shared.loadHabits()
                    currentHabits.removeAll { $0.name == habit.name }
                    HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
                    print("🗑️ CoreDataAdapter: Habit also removed from UserDefaults backup by name")
                } catch {
                    print("❌ CoreDataAdapter: Failed to delete habit by name in Core Data: \(error)")
                }
            } else {
                print("❌ CoreDataAdapter: No entity found by name either for habit: \(habit.name)")
            }
        }
    }
    
    // MARK: - Toggle Habit Completion
    func toggleHabitCompletion(_ habit: Habit, for date: Date) {
        let habitEntities = coreDataManager.fetchHabits()
        if let entity = habitEntities.first(where: { $0.id == habit.id }) {
            let currentProgress = coreDataManager.getProgress(for: entity, date: date)
            let newProgress = currentProgress > 0 ? 0 : 1
            
            do {
                try coreDataManager.markCompletion(for: entity, date: date, progress: newProgress)
                loadHabits(force: true)
            } catch {
                print("❌ CoreDataAdapter: Failed to toggle habit completion in Core Data: \(error)")
                print("🔄 CoreDataAdapter: Falling back to UserDefaults...")
                
                // Fallback to UserDefaults - this is more complex for completion tracking
                // For now, just log the error and continue
                print("⚠️ CoreDataAdapter: Completion tracking fallback not implemented for UserDefaults")
            }
        }
    }
    
    // MARK: - Force Save All Changes
    func forceSaveAllChanges() {
        print("🔄 CoreDataAdapter: Force saving all changes...")
        
        // Force save Core Data
        do {
            try coreDataManager.save()
            print("✅ CoreDataAdapter: Core Data changes saved")
        } catch {
            print("❌ CoreDataAdapter: Failed to save Core Data: \(error)")
        }
        
        // Also backup to UserDefaults as a safety measure
        backupToUserDefaults()
        
        print("✅ CoreDataAdapter: All changes saved")
    }
    
    // MARK: - Set Progress
    func setProgress(for habit: Habit, date: Date, progress: Int) {
        let dateKey = CoreDataManager.dateKey(for: date)
        print("🔄 CoreDataAdapter: Setting progress to \(progress) for habit '\(habit.name)' on \(dateKey)")
        
        let habitEntities = coreDataManager.fetchHabits()
        if let entity = habitEntities.first(where: { $0.id == habit.id }) {
            do {
                // First, update the completion record
                try coreDataManager.markCompletion(for: entity, date: date, progress: progress)
                print("✅ CoreDataAdapter: Progress set to \(progress) for habit '\(habit.name)' on \(dateKey)")
                
                // Save the context
                try coreDataManager.save()
                print("✅ CoreDataAdapter: Context saved after marking completion")
                
                // Update the local habits array to reflect the change immediately
                if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                    var updatedHabits = habits
                    updatedHabits[index].completionHistory[dateKey] = progress
                    print("🔍 CoreDataAdapter: Before update - habits[\(index)].completionHistory[\(dateKey)] = \(habits[index].completionHistory[dateKey] ?? 0)")
                    habits = updatedHabits
                    print("🔍 CoreDataAdapter: After update - habits[\(index)].completionHistory[\(dateKey)] = \(habits[index].completionHistory[dateKey] ?? 0)")
                    
                    // Explicitly notify subscribers that the object will change
                    objectWillChange.send()
                    print("✅ CoreDataAdapter: Local habits array updated and objectWillChange sent")
                }
                
                // Also backup to UserDefaults as a safety measure
                var currentHabits = HabitStorageManager.shared.loadHabits()
                if let index = currentHabits.firstIndex(where: { $0.id == habit.id }) {
                    currentHabits[index].completionHistory[dateKey] = progress
                    HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
                    print("✅ CoreDataAdapter: Progress also backed up to UserDefaults")
                }
                
                // Post notification that progress was updated
                NotificationCenter.default.post(name: NSNotification.Name("HabitProgressUpdated"), object: nil, userInfo: [
                    "habitId": habit.id,
                    "date": date,
                    "progress": progress
                ])
                
            } catch {
                print("❌ CoreDataAdapter: Failed to set progress in Core Data: \(error)")
                print("🔄 CoreDataAdapter: Falling back to UserDefaults...")
                
                // Fallback to UserDefaults
                var currentHabits = HabitStorageManager.shared.loadHabits()
                if let index = currentHabits.firstIndex(where: { $0.id == habit.id }) {
                    currentHabits[index].completionHistory[dateKey] = progress
                    HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
                    habits = currentHabits
                    
                    // Explicitly notify subscribers that the object will change
                    objectWillChange.send()
                    print("✅ CoreDataAdapter: Progress saved to UserDefaults and objectWillChange sent")
                }
            }
        } else {
            print("❌ CoreDataAdapter: No matching entity found for habit: \(habit.name)")
            print("🔄 CoreDataAdapter: Falling back to UserDefaults...")
            
            // Fallback to UserDefaults
            var currentHabits = HabitStorageManager.shared.loadHabits()
            if let index = currentHabits.firstIndex(where: { $0.id == habit.id }) {
                currentHabits[index].completionHistory[dateKey] = progress
                HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
                habits = currentHabits
                
                // Explicitly notify subscribers that the object will change
                objectWillChange.send()
                print("✅ CoreDataAdapter: Progress saved to UserDefaults and objectWillChange sent")
            }
        }
    }
    
    // MARK: - Get Progress
    func getProgress(for habit: Habit, date: Date) -> Int {
        let habitEntities = coreDataManager.fetchHabits()
        if let entity = habitEntities.first(where: { $0.id == habit.id }) {
            return coreDataManager.getProgress(for: entity, date: date)
        }
        return 0
    }
    
    // MARK: - Fetch Completion Records with Timestamps
    func fetchCompletionRecordsWithTimestamps(for habit: Habit) -> [CompletionRecordEntity] {
        let habitEntities = coreDataManager.fetchHabits()
        guard let entity = habitEntities.first(where: { $0.id == habit.id }) else {
            print("❌ CoreDataAdapter: No matching entity found for habit: \(habit.name)")
            return []
        }
        
        if let completionRecords = entity.completionHistory as? Set<CompletionRecordEntity> {
            let sortedRecords = completionRecords.sorted { record1, record2 in
                guard let timestamp1 = record1.timestamp, let timestamp2 = record2.timestamp else {
                    return false
                }
                return timestamp1 > timestamp2
            }
            print("✅ CoreDataAdapter: Fetched \(sortedRecords.count) completion records with timestamps for habit '\(habit.name)'")
            return sortedRecords
        }
        
        print("⚠️ CoreDataAdapter: No completion records found for habit: \(habit.name)")
        return []
    }
    
    // MARK: - Fetch All Completion Records with Timestamps
    func fetchAllCompletionRecordsWithTimestamps() -> [CompletionRecordEntity] {
        let habitEntities = coreDataManager.fetchHabits()
        var allRecords: [CompletionRecordEntity] = []
        
        for entity in habitEntities {
            if let completionRecords = entity.completionHistory as? Set<CompletionRecordEntity> {
                allRecords.append(contentsOf: completionRecords)
            }
        }
        
        let sortedRecords = allRecords.sorted { record1, record2 in
            guard let timestamp1 = record1.timestamp, let timestamp2 = record2.timestamp else {
                return false
            }
            return timestamp1 > timestamp2
        }
        
        print("✅ CoreDataAdapter: Fetched \(sortedRecords.count) total completion records with timestamps")
        return sortedRecords
    }
    
    // MARK: - Fetch Completion Records by Habit Type
    func fetchCompletionRecordsByHabitType(_ habitType: HabitType) -> [CompletionRecordEntity] {
        let habitEntities = coreDataManager.fetchHabits()
        var typeRecords: [CompletionRecordEntity] = []
        
        for entity in habitEntities {
            if entity.habitType == habitType.rawValue,
               let completionRecords = entity.completionHistory as? Set<CompletionRecordEntity> {
                typeRecords.append(contentsOf: completionRecords)
            }
        }
        
        let sortedRecords = typeRecords.sorted { record1, record2 in
            guard let timestamp1 = record1.timestamp, let timestamp2 = record2.timestamp else {
                return false
            }
            return timestamp1 > timestamp2
        }
        
        print("✅ CoreDataAdapter: Fetched \(sortedRecords.count) completion records with timestamps for habit type: \(habitType)")
        return sortedRecords
    }
    
    // MARK: - Fetch Difficulty Logs for Habit
    func fetchDifficultyLogs(for habit: Habit) -> [DifficultyLogEntity] {
        let habitEntities = coreDataManager.fetchHabits()
        guard let entity = habitEntities.first(where: { $0.id == habit.id }) else {
            print("❌ CoreDataAdapter: No matching entity found for habit: \(habit.name)")
            return []
        }
        
        if let difficultyLogs = entity.difficultyLogs as? Set<DifficultyLogEntity> {
            let sortedLogs = difficultyLogs.sorted { log1, log2 in
                guard let timestamp1 = log1.timestamp, let timestamp2 = log2.timestamp else {
                    return false
                }
                return timestamp1 > timestamp2
            }
            print("✅ CoreDataAdapter: Fetched \(sortedLogs.count) difficulty logs for habit '\(habit.name)'")
            return sortedLogs
        }
        
        print("⚠️ CoreDataAdapter: No difficulty logs found for habit: \(habit.name)")
        return []
    }
    
    // MARK: - Fetch All Difficulty Logs
    func fetchAllDifficultyLogs() -> [DifficultyLogEntity] {
        let habitEntities = coreDataManager.fetchHabits()
        var allLogs: [DifficultyLogEntity] = []
        
        for entity in habitEntities {
            if let difficultyLogs = entity.difficultyLogs as? Set<DifficultyLogEntity> {
                allLogs.append(contentsOf: difficultyLogs)
            }
        }
        
        let sortedLogs = allLogs.sorted { log1, log2 in
            guard let timestamp1 = log1.timestamp, let timestamp2 = log2.timestamp else {
                return false
            }
            return timestamp1 > timestamp2
        }
        
        print("✅ CoreDataAdapter: Fetched \(sortedLogs.count) total difficulty logs")
        return sortedLogs
    }
    
    // MARK: - Clean Up Duplicates
    func cleanupDuplicateHabits() {
        print("🔄 CoreDataAdapter: Starting duplicate cleanup...")
        
        let entities = coreDataManager.fetchHabits()
        var seenIds: Set<UUID> = []
        var duplicatesToRemove: [HabitEntity] = []
        
        for entity in entities {
            if let id = entity.id {
                if seenIds.contains(id) {
                    duplicatesToRemove.append(entity)
                    print("⚠️ CoreDataAdapter: Found duplicate habit entity with ID: \(id), name: \(entity.name ?? "Unknown") - will be removed")
                } else {
                    seenIds.insert(id)
                }
            }
        }
        
        if !duplicatesToRemove.isEmpty {
            print("🔄 CoreDataAdapter: Removing \(duplicatesToRemove.count) duplicate habits...")
            
            for duplicate in duplicatesToRemove {
                do {
                    try coreDataManager.deleteHabit(duplicate)
                    print("✅ CoreDataAdapter: Removed duplicate habit: \(duplicate.name ?? "Unknown")")
                } catch {
                    print("❌ CoreDataAdapter: Failed to remove duplicate habit: \(error)")
                }
            }
            
            // Reload habits after cleanup
            loadHabits(force: true)
            print("✅ CoreDataAdapter: Duplicate cleanup completed, total habits: \(habits.count)")
        } else {
            print("✅ CoreDataAdapter: No duplicate habits found")
        }
    }
    
    // MARK: - Migrate from UserDefaults
    func migrateFromUserDefaults() {
        print("🔄 CoreDataAdapter: Starting migration from UserDefaults...")
        
        let userDefaultsHabits = HabitStorageManager.shared.loadHabits()
        print("🔄 CoreDataAdapter: Found \(userDefaultsHabits.count) habits in UserDefaults")
        
        // Check for existing habits in Core Data to avoid duplicates
        let existingEntities = coreDataManager.fetchHabits()
        let existingIds = Set(existingEntities.compactMap { $0.id })
        
        var migratedCount = 0
        var skippedCount = 0
        
        for habit in userDefaultsHabits {
            // Skip if habit already exists in Core Data
            if existingIds.contains(habit.id) {
                print("⚠️ CoreDataAdapter: Habit '\(habit.name)' already exists in Core Data, skipping migration")
                skippedCount += 1
                continue
            }
            
            do {
                _ = try coreDataManager.createHabit(from: habit)
                print("✅ CoreDataAdapter: Migrated habit: \(habit.name)")
                migratedCount += 1
            } catch {
                print("❌ CoreDataAdapter: Failed to migrate habit '\(habit.name)': \(error)")
            }
        }
        
        // Reload habits after migration
        loadHabits(force: true)
        print("✅ CoreDataAdapter: Migration completed - \(migratedCount) habits migrated, \(skippedCount) skipped, total habits: \(habits.count)")
    }
    
    // MARK: - Backup to UserDefaults
    func backupToUserDefaults() {
        HabitStorageManager.shared.saveHabits(habits, immediate: true)
        print("✅ CoreDataAdapter: Habits backed up to UserDefaults")
    }
}

// MARK: - HabitEntity Extensions
extension HabitEntity {
    func toHabit() -> Habit {
        let habitType = HabitType(rawValue: self.habitType ?? "formation") ?? .formation
        let color = Color.fromHex(self.colorHex ?? "#1C274C")
        
        // Convert completion history
        var completionHistory: [String: Int] = [:]
        print("🔍 CoreDataAdapter: Raw completionHistory property: \(String(describing: self.completionHistory))")
        
        if let completionRecords = self.completionHistory as? Set<CompletionRecordEntity> {
            print("🔍 CoreDataAdapter: Converting \(completionRecords.count) completion records for habit '\(self.name ?? "Unknown")'")
            for record in completionRecords {
                if let dateKey = record.dateKey {
                    let progress = Int(record.progress)
                    completionHistory[dateKey] = progress
                    print("  📅 Converting: \(dateKey) -> \(progress)")
                }
            }
        } else {
            print("🔍 CoreDataAdapter: No completion records found for habit '\(self.name ?? "Unknown")'")
            print("🔍 CoreDataAdapter: completionHistory type: \(type(of: self.completionHistory))")
            print("🔍 CoreDataAdapter: completionHistory is NSSet: \(self.completionHistory != nil)")
        }
        
        // Convert actual usage
        var actualUsage: [String: Int] = [:]
        if let usageRecords = self.usageRecords as? Set<UsageRecordEntity> {
            for record in usageRecords {
                if let dateKey = record.dateKey {
                    actualUsage[dateKey] = Int(record.amount)
                }
            }
        }
        
        // Convert reminders
        var reminders: [ReminderItem] = []
        if let reminderEntities = self.reminders as? Set<ReminderItemEntity> {
            for entity in reminderEntities {
                let reminder = ReminderItem(
                    id: entity.id ?? UUID(),
                    time: entity.time ?? Date(),
                    isActive: entity.isActive
                )
                reminders.append(reminder)
            }
        }
        
        return Habit(
            id: self.id ?? UUID(),
            name: self.name ?? "",
            description: self.habitDescription ?? "",
            icon: self.icon ?? "None",
            color: color,
            habitType: habitType,
            schedule: (self.schedule ?? "Everyday").capitalized,
            goal: self.goal ?? "1 time",
            reminder: self.reminder ?? "No reminder",
            startDate: self.startDate ?? Date(),
            endDate: self.endDate,
            isCompleted: self.isCompleted,
            streak: Int(self.streak),
            createdAt: self.createdAt ?? Date(),
            reminders: reminders,
            baseline: Int(self.baseline),
            target: Int(self.target),
            completionHistory: completionHistory,
            actualUsage: actualUsage
        )
    }
}

// MARK: - ReminderItemEntity Extensions
extension ReminderItemEntity {
    func toReminderItem() -> ReminderItem {
        return ReminderItem(
            id: self.id ?? UUID(),
            time: self.time ?? Date(),
            isActive: self.isActive
        )
    }
}

// MARK: - CompletionRecordEntity Extensions
extension CompletionRecordEntity {
    func toCompletionRecord() -> (dateKey: String, progress: Int) {
        return (
            dateKey: self.dateKey ?? "",
            progress: Int(self.progress)
        )
    }
}

// MARK: - UsageRecordEntity Extensions
extension UsageRecordEntity {
    func toUsageRecord() -> (dateKey: String, amount: Int) {
        return (
            dateKey: self.dateKey ?? "",
            amount: Int(self.amount)
        )
    }
}

// MARK: - NoteEntity Extensions
extension NoteEntity {
    func toNote() -> Note {
        return Note(
            id: self.id ?? UUID(),
            title: self.title ?? "",
            content: self.content ?? "",
            tags: (self.tags as? [String]) ?? [],
            createdAt: self.createdAt ?? Date(),
            updatedAt: self.updatedAt ?? Date()
        )
    }
}

// MARK: - DifficultyLogEntity Extensions
extension DifficultyLogEntity {
    func toDifficultyLog() -> DifficultyLog {
        return DifficultyLog(
            id: UUID(), // Generate new ID since it's not stored
            difficulty: Int(self.difficulty),
            context: self.context ?? "",
            timestamp: self.timestamp ?? Date()
        )
    }
}

// MARK: - Future Data Models
struct Note {
    let id: UUID
    let title: String
    let content: String
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
}

struct DifficultyLog {
    let id: UUID
    let difficulty: Int // 1-10 scale
    let context: String
    let timestamp: Date
}

struct MoodLog {
    let id: UUID
    let mood: Int // 1-10 scale
    let timestamp: Date
}
