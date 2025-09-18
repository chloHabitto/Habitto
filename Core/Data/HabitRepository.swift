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

// MARK: - Habit Repository
class HabitRepository: ObservableObject {
    static let shared = HabitRepository()
    
    @Published var habits: [Habit] = []
    
    private let coreDataManager = CoreDataManager.shared
    private let cloudKitManager = CloudKitManager.shared
    
    private init() {
        initializeSync()
        
        // Always use UserDefaults for data persistence (simpler and more reliable)
        print("✅ HabitRepository: Using UserDefaults for data persistence...")
        loadHabits(force: true)
        
        // Clean up any existing duplicate habits
        cleanupDuplicateHabits()
        
        print("✅ HabitRepository: Loaded \(habits.count) habits from UserDefaults")
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
        print("🔄 HabitRepository: App became active, reloading habits...")
        
        // Force reload habits from Core Data
        loadHabits(force: true)
        
        // Also check for any pending changes
        // Note: CoreDataManager doesn't have saveIfNeeded method
        
        print("✅ HabitRepository: Habits reloaded after app became active")
    }
    
    // MARK: - Debug Methods
    func debugHabitsState() {
        print("🔍 HabitRepository: Debug - Current habits state:")
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
            print("⚠️ HabitRepository: Found \(invalidHabits.count) habits with default UUIDs")
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
            print("⚠️ HabitRepository: Found \(duplicates.count) duplicate habits:")
            for duplicate in duplicates {
                print("    - \(duplicate.name) (ID: \(duplicate.id))")
            }
        }
        
        print("✅ HabitRepository: Debug completed")
    }
    
    // Emergency recovery method
    func recoverMissingHabits() {
        print("🚨 HabitRepository: Starting emergency habit recovery...")
        
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
        print("🔄 HabitRepository: loadHabits called (force: \(force))")
        
        // Always load if force is true, or if habits is empty
        if !force && !habits.isEmpty {
            print("ℹ️ HabitRepository: Skipping load - habits not empty and not forced")
            return
        }
        
        // Always load from UserDefaults (simpler and more reliable)
        let loadedHabits = HabitStorageManager.shared.loadHabits()
        print("🔍 HabitRepository: Loaded \(loadedHabits.count) habits from UserDefaults")
        
        // Debug each loaded habit
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
                print("⚠️ HabitRepository: Found duplicate habit with ID: \(habit.id), name: \(habit.name) - skipping")
            }
        }
        
        // Always update on main thread and notify observers
        DispatchQueue.main.async {
            self.habits = uniqueHabits
            print("✅ HabitRepository: Updated habits array with \(uniqueHabits.count) unique habits")
            
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
        // Find the habit and update its difficulty history
        if let habitIndex = habits.firstIndex(where: { $0.id == habitId }) {
            var updatedHabit = habits[habitIndex]
            updatedHabit.recordDifficulty(Int(difficulty), for: date)
            habits[habitIndex] = updatedHabit
            
            // Save the updated habits array
            Habit.saveHabits(habits, immediate: true)
            
            print("✅ HabitRepository: Saved difficulty \(difficulty) for habit \(habitId) on \(date)")
        } else {
            print("❌ HabitRepository: Habit not found for ID: \(habitId)")
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
            print("❌ HabitRepository: Failed to fetch difficulties: \(error)")
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
            print("❌ HabitRepository: Failed to fetch all difficulties: \(error)")
            return []
        }
    }
    
    // MARK: - Save Habits
    func saveHabits(_ habits: [Habit]) {
        print("🔄 HabitRepository: saveHabits called with \(habits.count) habits")
        print("⚠️ HabitRepository: Skipping Core Data sync - using UserDefaults only")
        
        // Save directly to UserDefaults instead of Core Data
        HabitStorageManager.shared.saveHabits(habits, immediate: true)
        
        // Update the local habits array
        DispatchQueue.main.async {
            self.habits = habits
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Create Habit
    func createHabit(_ habit: Habit) {
        print("🔄 HabitRepository: Creating habit: \(habit.name)")
        print("🔄 HabitRepository: Current habits count before creation: \(habits.count)")
        
        // Use UserDefaults directly for reliable persistence
        var currentHabits = HabitStorageManager.shared.loadHabits()
        currentHabits.append(habit)
        HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
        
        // Update the published habits on main thread
        DispatchQueue.main.async {
            self.habits = currentHabits
            print("✅ HabitRepository: Habit saved to UserDefaults, total: \(self.habits.count)")
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Update Habit
    func updateHabit(_ habit: Habit) {
        print("🔄 HabitRepository: updateHabit called for: \(habit.name) (ID: \(habit.id))")
        print("🔄 HabitRepository: Habit has \(habit.reminders.count) reminders")
        
        // Use UserDefaults directly for reliable persistence
        var currentHabits = HabitStorageManager.shared.loadHabits()
        if let index = currentHabits.firstIndex(where: { $0.id == habit.id }) {
            currentHabits[index] = habit
            HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
            
            // Update the published habits on main thread
            DispatchQueue.main.async {
                self.habits = currentHabits
                print("✅ HabitRepository: Habit updated in UserDefaults")
                self.objectWillChange.send()
            }
        } else {
            print("❌ HabitRepository: No matching habit found for ID: \(habit.id)")
            print("🔄 HabitRepository: Creating new habit in UserDefaults...")
            
            // Create new habit in UserDefaults
            currentHabits.append(habit)
            HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
            
            // Update the published habits on main thread
            DispatchQueue.main.async {
                self.habits = currentHabits
                print("✅ HabitRepository: New habit created in UserDefaults")
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Delete Habit
    func deleteHabit(_ habit: Habit) {
        print("🗑️ HabitRepository: Starting delete for habit: \(habit.name)")
        
        // Remove all notifications for this habit first
        NotificationManager.shared.removeAllNotifications(for: habit)
        print("🗑️ HabitRepository: Removed all notifications for habit: \(habit.name)")
        
        // Use UserDefaults directly for reliable persistence
        var currentHabits = HabitStorageManager.shared.loadHabits()
        currentHabits.removeAll { $0.id == habit.id }
        HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
        
        // Update the published habits on main thread
        DispatchQueue.main.async {
            self.habits = currentHabits
            print("✅ HabitRepository: Habit deleted from UserDefaults, new count: \(self.habits.count)")
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Toggle Habit Completion
    func toggleHabitCompletion(_ habit: Habit, for date: Date) {
        // Skip Core Data and handle completion directly in UserDefaults
        print("⚠️ HabitRepository: Bypassing Core Data for toggleHabitCompletion")
        
        let dateKey = CoreDataManager.dateKey(for: date)
        let currentProgress = habit.completionHistory[dateKey] ?? 0
        let newProgress = currentProgress > 0 ? 0 : 1
        
        setProgress(for: habit, date: date, progress: newProgress)
    }
    
    // MARK: - Force Save All Changes
    func forceSaveAllChanges() {
        print("🔄 HabitRepository: Force saving all changes...")
        
        // Force save Core Data
        do {
            try coreDataManager.save()
            print("✅ HabitRepository: Core Data changes saved")
        } catch {
            print("❌ HabitRepository: Failed to save Core Data: \(error)")
        }
        
        // Also backup to UserDefaults as a safety measure
        backupToUserDefaults()
        
        print("✅ HabitRepository: All changes saved")
    }
    
    // MARK: - Set Progress
    func setProgress(for habit: Habit, date: Date, progress: Int) {
        let dateKey = CoreDataManager.dateKey(for: date)
        print("🔄 HabitRepository: Setting progress to \(progress) for habit '\(habit.name)' on \(dateKey)")
        
        // Skip Core Data and update UserDefaults directly
        print("⚠️ HabitRepository: Bypassing Core Data, updating UserDefaults directly...")
        
        // Update the local habits array immediately
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            var updatedHabits = habits
            updatedHabits[index].completionHistory[dateKey] = progress
            
            DispatchQueue.main.async {
                self.habits = updatedHabits
                print("✅ HabitRepository: Progress updated in memory for habit '\(habit.name)' on \(dateKey)")
                self.objectWillChange.send()
                
                // Save to UserDefaults
                HabitStorageManager.shared.saveHabits(updatedHabits, immediate: true)
                print("✅ HabitRepository: Progress saved to UserDefaults")
            }
        } else {
            print("❌ HabitRepository: Habit not found in local array: \(habit.name)")
        }
    }
    
    // MARK: - Get Progress
    func getProgress(for habit: Habit, date: Date) -> Int {
        // Use the Habit model's getProgress method directly since we're not using Core Data
        return habit.getProgress(for: date)
    }
    
    // MARK: - Fetch Completion Records with Timestamps
    func fetchCompletionRecordsWithTimestamps(for habit: Habit) -> [CompletionRecordEntity] {
        let habitEntities = coreDataManager.fetchHabits()
        guard let entity = habitEntities.first(where: { $0.id == habit.id }) else {
            print("❌ HabitRepository: No matching entity found for habit: \(habit.name)")
            return []
        }
        
        if let completionRecords = entity.completionHistory as? Set<CompletionRecordEntity> {
            let sortedRecords = completionRecords.sorted { record1, record2 in
                guard let timestamp1 = record1.timestamp, let timestamp2 = record2.timestamp else {
                    return false
                }
                return timestamp1 > timestamp2
            }
            print("✅ HabitRepository: Fetched \(sortedRecords.count) completion records with timestamps for habit '\(habit.name)'")
            return sortedRecords
        }
        
        print("⚠️ HabitRepository: No completion records found for habit: \(habit.name)")
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
        
        print("✅ HabitRepository: Fetched \(sortedRecords.count) total completion records with timestamps")
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
        
        print("✅ HabitRepository: Fetched \(sortedRecords.count) completion records with timestamps for habit type: \(habitType)")
        return sortedRecords
    }
    
    // MARK: - Fetch Difficulty Logs for Habit
    func fetchDifficultyLogs(for habit: Habit) -> [DifficultyLogEntity] {
        // This function is deprecated - use habit.difficultyHistory directly instead
        // Return empty array to prevent crashes
        print("⚠️ HabitRepository: fetchDifficultyLogs is deprecated - use habit.difficultyHistory directly")
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
        
        print("✅ HabitRepository: Fetched \(sortedLogs.count) total difficulty logs")
        return sortedLogs
    }
    
    // MARK: - Clean Up Duplicates
    func cleanupDuplicateHabits() {
        print("🔄 HabitRepository: Starting duplicate cleanup...")
        
        let entities = coreDataManager.fetchHabits()
        var seenIds: Set<UUID> = []
        var duplicatesToRemove: [HabitEntity] = []
        
        for entity in entities {
            if let id = entity.id {
                if seenIds.contains(id) {
                    duplicatesToRemove.append(entity)
                    print("⚠️ HabitRepository: Found duplicate habit entity with ID: \(id), name: \(entity.name ?? "Unknown") - will be removed")
                } else {
                    seenIds.insert(id)
                }
            }
        }
        
        if !duplicatesToRemove.isEmpty {
            print("🔄 HabitRepository: Removing \(duplicatesToRemove.count) duplicate habits...")
            
            for duplicate in duplicatesToRemove {
                do {
                    try coreDataManager.deleteHabit(duplicate)
                    print("✅ HabitRepository: Removed duplicate habit: \(duplicate.name ?? "Unknown")")
                } catch {
                    print("❌ HabitRepository: Failed to remove duplicate habit: \(error)")
                }
            }
            
            // Reload habits after cleanup
            loadHabits(force: true)
            print("✅ HabitRepository: Duplicate cleanup completed, total habits: \(habits.count)")
        } else {
            print("✅ HabitRepository: No duplicate habits found")
        }
    }
    
    // MARK: - Migrate from UserDefaults
    func migrateFromUserDefaults() {
        print("🔄 HabitRepository: Starting migration from UserDefaults...")
        
        let userDefaultsHabits = HabitStorageManager.shared.loadHabits()
        print("🔄 HabitRepository: Found \(userDefaultsHabits.count) habits in UserDefaults")
        
        // Check for existing habits in Core Data to avoid duplicates
        let existingEntities = coreDataManager.fetchHabits()
        let existingIds = Set(existingEntities.compactMap { $0.id })
        
        var migratedCount = 0
        var skippedCount = 0
        
        for habit in userDefaultsHabits {
            // Skip if habit already exists in Core Data
            if existingIds.contains(habit.id) {
                print("⚠️ HabitRepository: Habit '\(habit.name)' already exists in Core Data, skipping migration")
                skippedCount += 1
                continue
            }
            
            do {
                _ = try coreDataManager.createHabit(from: habit)
                print("✅ HabitRepository: Migrated habit: \(habit.name)")
                migratedCount += 1
            } catch {
                print("❌ HabitRepository: Failed to migrate habit '\(habit.name)': \(error)")
            }
        }
        
        // Reload habits after migration
        loadHabits(force: true)
        print("✅ HabitRepository: Migration completed - \(migratedCount) habits migrated, \(skippedCount) skipped, total habits: \(habits.count)")
    }
    
    // MARK: - Backup to UserDefaults
    func backupToUserDefaults() {
        HabitStorageManager.shared.saveHabits(habits, immediate: true)
        print("✅ HabitRepository: Habits backed up to UserDefaults")
    }
}

// MARK: - HabitEntity Extensions
extension HabitEntity {
    func toHabit() -> Habit {
        let habitType = HabitType(rawValue: self.habitType ?? "formation") ?? .formation
        let color = Color.fromHex(self.colorHex ?? "#1C274C")
        
        // Convert completion history
        var completionHistory: [String: Int] = [:]
        print("🔍 HabitRepository: Raw completionHistory property: \(String(describing: self.completionHistory))")
        
        if let completionRecords = self.completionHistory as? Set<CompletionRecordEntity> {
            print("🔍 HabitRepository: Converting \(completionRecords.count) completion records for habit '\(self.name ?? "Unknown")'")
            for record in completionRecords {
                if let dateKey = record.dateKey {
                    let progress = Int(record.progress)
                    completionHistory[dateKey] = progress
                    print("  📅 Converting: \(dateKey) -> \(progress)")
                }
            }
        } else {
            print("🔍 HabitRepository: No completion records found for habit '\(self.name ?? "Unknown")'")
            print("🔍 HabitRepository: completionHistory type: \(type(of: self.completionHistory))")
            print("🔍 HabitRepository: completionHistory is NSSet: \(self.completionHistory != nil)")
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
            tags: (self.tags?.components(separatedBy: ",").compactMap { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }) ?? [],
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
