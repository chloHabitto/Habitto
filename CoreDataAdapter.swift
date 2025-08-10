import CoreData
import SwiftUI

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
        
        // Reload habits from Core Data
        loadHabits(force: true)
        
        print("✅ CoreDataAdapter: Habits reloaded after app became active")
    }
    
    // MARK: - Load Habits
    func loadHabits(force: Bool = false) {
        if !force && !habits.isEmpty {
            return
        }
        
        let entities = coreDataManager.fetchHabits()
        habits = entities.map { $0.toHabit() }
        print("✅ CoreDataAdapter: Loaded \(habits.count) habits from Core Data")
    }
    
    // MARK: - Save Habits
    func saveHabits(_ habits: [Habit]) {
        do {
            // Clear existing habits
            let existingEntities = coreDataManager.fetchHabits()
            for entity in existingEntities {
                try coreDataManager.deleteHabit(entity)
            }
            
            // Create new habits
            for habit in habits {
                _ = try coreDataManager.createHabit(from: habit)
            }
            
            loadHabits(force: true)
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
        
        // Try to create in Core Data first
        do {
            let createdEntity = try coreDataManager.createHabit(from: habit)
            print("🔄 CoreDataAdapter: Habit created in Core Data with ID: \(createdEntity.id?.uuidString ?? "nil")")
            loadHabits(force: true)
            print("🔄 CoreDataAdapter: Habits loaded, total: \(habits.count)")
        } catch {
            print("❌ CoreDataAdapter: Failed to create habit in Core Data: \(error)")
            print("🔄 CoreDataAdapter: Falling back to UserDefaults...")
            
            // Fallback to UserDefaults
            var currentHabits = HabitStorageManager.shared.loadHabits()
            currentHabits.append(habit)
            HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
            
            // Update the published habits
            habits = currentHabits
            print("✅ CoreDataAdapter: Habit saved to UserDefaults, total: \(habits.count)")
        }
    }
    
    // MARK: - Update Habit
    func updateHabit(_ habit: Habit) {
        let habitEntities = coreDataManager.fetchHabits()
        if let entity = habitEntities.first(where: { $0.id == habit.id }) {
            do {
                try coreDataManager.updateHabit(entity, with: habit)
                print("✅ CoreDataAdapter: Habit updated in Core Data")
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
            print("🔄 CoreDataAdapter: Trying to find by name instead...")
            
            // Try to find by name as a fallback
            if let entity = habitEntities.first(where: { $0.name == habit.name }) {
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
        
        let habitEntities = coreDataManager.fetchHabits()
        
        if let entity = habitEntities.first(where: { $0.id == habit.id }) {
            print("🗑️ CoreDataAdapter: Found matching entity, deleting...")
            do {
                try coreDataManager.deleteHabit(entity)
                print("🗑️ CoreDataAdapter: Entity deleted, reloading habits...")
                loadHabits(force: true)
                print("🗑️ CoreDataAdapter: Habits reloaded, total: \(habits.count)")
                
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
                habits = currentHabits
                print("✅ CoreDataAdapter: Habit deleted from UserDefaults, total: \(habits.count)")
            }
        } else {
            print("❌ CoreDataAdapter: No matching entity found for habit: \(habit.name)")
            print("❌ CoreDataAdapter: Trying to find by name instead...")
            
            // Try to find by name as a fallback
            if let entity = habitEntities.first(where: { $0.name == habit.name }) {
                print("🗑️ CoreDataAdapter: Found entity by name, deleting...")
                do {
                    try coreDataManager.deleteHabit(entity)
                    print("🗑️ CoreDataAdapter: Entity deleted by name, reloading habits...")
                    loadHabits(force: true)
                    print("🗑️ CoreDataAdapter: Habits reloaded, total: \(habits.count)")
                    
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
        print("🔄 CoreDataAdapter: Setting progress to \(progress) for habit '\(habit.name)' on \(DateUtils.dateKey(for: date))")
        
        let habitEntities = coreDataManager.fetchHabits()
        if let entity = habitEntities.first(where: { $0.id == habit.id }) {
            do {
                // First, update the completion record
                try coreDataManager.markCompletion(for: entity, date: date, progress: progress)
                print("✅ CoreDataAdapter: Progress set to \(progress) for habit '\(habit.name)' on \(DateUtils.dateKey(for: date))")
                
                // Save the context
                try coreDataManager.save()
                print("✅ CoreDataAdapter: Context saved after marking completion")
                
                // Update the local habits array to reflect the change immediately
                if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                    habits[index].completionHistory[DateUtils.dateKey(for: date)] = progress
                    print("✅ CoreDataAdapter: Local habits array updated")
                }
                
                // Also backup to UserDefaults as a safety measure
                var currentHabits = HabitStorageManager.shared.loadHabits()
                if let index = currentHabits.firstIndex(where: { $0.id == habit.id }) {
                    let dateKey = DateUtils.dateKey(for: date)
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
                    let dateKey = DateUtils.dateKey(for: date)
                    currentHabits[index].completionHistory[dateKey] = progress
                    HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
                    habits = currentHabits
                    print("✅ CoreDataAdapter: Progress saved to UserDefaults")
                }
            }
        } else {
            print("❌ CoreDataAdapter: No matching entity found for habit: \(habit.name)")
            print("🔄 CoreDataAdapter: Falling back to UserDefaults...")
            
            // Fallback to UserDefaults
            var currentHabits = HabitStorageManager.shared.loadHabits()
            if let index = currentHabits.firstIndex(where: { $0.id == habit.id }) {
                let dateKey = DateUtils.dateKey(for: date)
                currentHabits[index].completionHistory[dateKey] = progress
                HabitStorageManager.shared.saveHabits(currentHabits, immediate: true)
                habits = currentHabits
                print("✅ CoreDataAdapter: Progress saved to UserDefaults")
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
    
    // MARK: - Migrate from UserDefaults
    func migrateFromUserDefaults() {
        print("🔄 CoreDataAdapter: Starting migration from UserDefaults...")
        
        let userDefaultsHabits = HabitStorageManager.shared.loadHabits()
        print("🔄 CoreDataAdapter: Found \(userDefaultsHabits.count) habits in UserDefaults")
        
        for habit in userDefaultsHabits {
            do {
                _ = try coreDataManager.createHabit(from: habit)
                print("✅ CoreDataAdapter: Migrated habit: \(habit.name)")
            } catch {
                print("❌ CoreDataAdapter: Failed to migrate habit '\(habit.name)': \(error)")
            }
        }
        
        // Reload habits after migration
        loadHabits(force: true)
        print("✅ CoreDataAdapter: Migration completed, total habits: \(habits.count)")
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
            schedule: self.schedule ?? "everyday",
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
