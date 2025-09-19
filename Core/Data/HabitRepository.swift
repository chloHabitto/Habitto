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
//
// This repository acts as a @MainActor facade for UI compatibility.
// All actual data operations are handled by the HabitStore actor.
//
// Data Storage:
// - Habit definitions → SwiftData (primary) → UserDefaults (fallback)
// - Completion records → SwiftData (primary) → UserDefaults (fallback)
// - User preferences → UserDefaults
// - Streak calculations → Computed from local data
//
// Authentication:
// - User login → AuthenticationManager (Firebase Auth)
// - User tokens → Keychain (via KeychainManager)
// - User profile → Firebase Auth
//
@MainActor
class HabitRepository: ObservableObject {
    static let shared = HabitRepository()
    
    @Published var habits: [Habit] = []
    
    // Use the new HabitStore actor for all data operations
    private let habitStore = HabitStore.shared
    
    // Defer CloudKit initialization to avoid crashes
    private lazy var cloudKitManager = CloudKitManager.shared
    private lazy var cloudKitIntegration = CloudKitIntegrationService.shared
    
    private init() {
        // Initialize basic functionality first
        print("✅ HabitRepository: Initializing...")
        
        // Load habits using the new actor
        print("✅ HabitRepository: Using HabitStore actor for data operations...")
        Task {
            await loadHabits(force: true)
        }
        
        // Defer CloudKit initialization to avoid crashes
        Task { @MainActor in
            await self.initializeCloudKitSafely()
        }
        
        print("✅ HabitRepository: Initialization completed")
    }
    
    // MARK: - Safe CloudKit Initialization
    private func initializeCloudKitSafely() async {
        // Initialize CloudKit integration safely
        await cloudKitIntegration.initialize()
        print("✅ HabitRepository: CloudKit integration initialized safely")
        
        // Initialize CloudKit sync safely
        if cloudKitManager.isCloudKitAvailable() {
            cloudKitManager.initializeCloudKitSync()
        } else {
            print("ℹ️ HabitRepository: CloudKit not available, skipping sync initialization")
        }
        
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
        
        // Force reload habits from storage
        Task {
            await loadHabits(force: true)
            print("✅ HabitRepository: Habits reloaded after app became active")
        }
    }
    
    // MARK: - Debug Methods
    func debugHabitsState() {
        print("🔍 HabitRepository: Debug - Current habits state:")
        print("  - Published habits count: \(habits.count)")
        
        // List all published habits
        print("📋 Published habits:")
        for (index, habit) in habits.enumerated() {
            print("  \(index): \(habit.name) (ID: \(habit.id), reminders: \(habit.reminders.count))")
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
        
        // Force reload habits from storage
        Task {
            await loadHabits(force: true)
            print("🚨 Recovery complete: \(habits.count) habits recovered")
        }
    }
    
    // MARK: - Load Habits
    func loadHabits(force: Bool = false) async {
        print("🔄 HabitRepository: loadHabits called (force: \(force))")
        
        // Always load if force is true, or if habits is empty
        if !force && !habits.isEmpty {
            print("ℹ️ HabitRepository: Skipping load - habits not empty and not forced")
            return
        }
        
        do {
            // Use the HabitStore actor for data operations
            let loadedHabits = try await habitStore.loadHabits()
            print("🔍 HabitRepository: Loaded \(loadedHabits.count) habits from HabitStore")
            
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
            
            // Update on main thread and notify observers
            self.habits = uniqueHabits
            print("✅ HabitRepository: Updated habits array with \(uniqueHabits.count) unique habits")
            
            // Debug final habits array
            for (index, habit) in uniqueHabits.enumerated() {
                print("🔍 Final Habit \(index): name=\(habit.name), id=\(habit.id)")
            }
            
            // Notify observers that habits have changed
            self.objectWillChange.send()
            
        } catch {
            print("❌ HabitRepository: Failed to load habits: \(error.localizedDescription)")
            // Keep existing habits if loading fails
        }
    }
    
    // MARK: - Save Difficulty Rating
    func saveDifficultyRating(habitId: UUID, date: Date, difficulty: Int32) {
        Task {
            do {
                // Use the HabitStore actor for data operations
                try await habitStore.saveDifficultyRating(habitId: habitId, date: date, difficulty: difficulty)
                
                // Update the local habits array immediately for UI responsiveness
                if let habitIndex = habits.firstIndex(where: { $0.id == habitId }) {
                    habits[habitIndex].recordDifficulty(Int(difficulty), for: date)
                    objectWillChange.send()
                }
                
                print("✅ HabitRepository: Saved difficulty \(difficulty) for habit \(habitId) on \(date)")
                
            } catch {
                print("❌ HabitRepository: Failed to save difficulty: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Fetch Difficulty Data
    func fetchDifficultiesForHabit(_ habitId: UUID, month: Int, year: Int) async -> [Double] {
        do {
            // Use the HabitStore actor for data operations
            return try await habitStore.fetchDifficultiesForHabit(habitId, month: month, year: year)
        } catch {
            print("❌ HabitRepository: Failed to fetch difficulties: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchAllDifficulties(month: Int, year: Int) async -> [Double] {
        do {
            // Use the HabitStore actor for data operations
            return try await habitStore.fetchAllDifficulties(month: month, year: year)
        } catch {
            print("❌ HabitRepository: Failed to fetch all difficulties: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Save Habits
    func saveHabits(_ habits: [Habit]) {
        print("🔄 HabitRepository: saveHabits called with \(habits.count) habits")
        
        Task {
            do {
                // Use the HabitStore actor for data operations
                try await habitStore.saveHabits(habits)
                
                // Update the local habits array on main thread
                await MainActor.run {
                    self.habits = habits
                    self.objectWillChange.send()
                }
                
                // Trigger CloudKit sync if enabled
                if cloudKitIntegration.isEnabled {
                    await cloudKitIntegration.startSync()
                }
                
                print("✅ HabitRepository: Successfully saved \(habits.count) habits")
                
            } catch {
                print("❌ HabitRepository: Failed to save habits: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Create Habit
    func createHabit(_ habit: Habit) {
        print("🔄 HabitRepository: Creating habit: \(habit.name)")
        print("🔄 HabitRepository: Current habits count before creation: \(habits.count)")
        
        Task {
            do {
                // Use the HabitStore actor for data operations
                try await habitStore.createHabit(habit)
                
                // Reload habits to get the updated list
                await loadHabits(force: true)
                
                print("✅ HabitRepository: Successfully created habit: \(habit.name)")
                
            } catch {
                print("❌ HabitRepository: Failed to create habit: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Update Habit
    func updateHabit(_ habit: Habit) {
        print("🔄 HabitRepository: updateHabit called for: \(habit.name) (ID: \(habit.id))")
        print("🔄 HabitRepository: Habit has \(habit.reminders.count) reminders")
        
        Task {
            do {
                // Use the HabitStore actor for data operations
                try await habitStore.updateHabit(habit)
                
                // Reload habits to get the updated list
                await loadHabits(force: true)
                
                print("✅ HabitRepository: Successfully updated habit: \(habit.name)")
                
            } catch {
                print("❌ HabitRepository: Failed to update habit: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Delete Habit
    func deleteHabit(_ habit: Habit) {
        print("🗑️ HabitRepository: Starting delete for habit: \(habit.name)")
        
        // Remove all notifications for this habit first
        NotificationManager.shared.removeAllNotifications(for: habit)
        print("🗑️ HabitRepository: Removed all notifications for habit: \(habit.name)")
        
        Task {
            do {
                // Use the HabitStore actor for data operations
                try await habitStore.deleteHabit(habit)
                
                // Reload habits to get the updated list
                await loadHabits(force: true)
                
                print("✅ HabitRepository: Successfully deleted habit: \(habit.name)")
                
            } catch {
                print("❌ HabitRepository: Failed to delete habit: \(error.localizedDescription)")
            }
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
        
        // Save current habits
        saveHabits(habits)
        
        print("✅ HabitRepository: All changes saved")
    }
    
    // MARK: - Set Progress
    func setProgress(for habit: Habit, date: Date, progress: Int) {
        let dateKey = CoreDataManager.dateKey(for: date)
        print("🔄 HabitRepository: Setting progress to \(progress) for habit '\(habit.name)' on \(dateKey)")
        
        Task {
            do {
                // Use the HabitStore actor for data operations
                try await habitStore.setProgress(for: habit, date: date, progress: progress)
                
                // Update the local habits array immediately for UI responsiveness
                if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                    habits[index].completionHistory[dateKey] = progress
                    objectWillChange.send()
                }
                
                print("✅ HabitRepository: Successfully updated progress for habit '\(habit.name)' on \(dateKey)")
                
            } catch {
                print("❌ HabitRepository: Failed to update progress: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Get Progress
    func getProgress(for habit: Habit, date: Date) -> Int {
        // Use the Habit model's getProgress method directly since we're not using Core Data
        return habit.getProgress(for: date)
    }
    
    // MARK: - Fetch Difficulty Logs for Habit
    func fetchDifficultyLogs(for habit: Habit) -> [DifficultyLogEntity] {
        // This function is deprecated - use habit.difficultyHistory directly instead
        // Return empty array to prevent crashes
        print("⚠️ HabitRepository: fetchDifficultyLogs is deprecated - use habit.difficultyHistory directly")
        return []
    }
    
    // MARK: - Clean Up Duplicates
    func cleanupDuplicateHabits() {
        print("🔄 HabitRepository: Starting duplicate cleanup...")
        
        // Check for duplicate IDs in current habits
        var seenIds: Set<UUID> = []
        var duplicatesToRemove: [Habit] = []
        
        for habit in habits {
            if seenIds.contains(habit.id) {
                duplicatesToRemove.append(habit)
                print("⚠️ HabitRepository: Found duplicate habit with ID: \(habit.id), name: \(habit.name) - will be removed")
            } else {
                seenIds.insert(habit.id)
            }
        }
        
        if !duplicatesToRemove.isEmpty {
            print("🔄 HabitRepository: Removing \(duplicatesToRemove.count) duplicate habits...")
            
            // Remove duplicates from habits array
            habits.removeAll { habit in
                duplicatesToRemove.contains { $0.id == habit.id }
            }
            
            // Save updated habits
            saveHabits(habits)
            print("✅ HabitRepository: Duplicate cleanup completed, total habits: \(habits.count)")
        } else {
            print("✅ HabitRepository: No duplicate habits found")
        }
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
