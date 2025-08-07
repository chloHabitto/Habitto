import CoreData
import SwiftUI

// MARK: - Core Data Adapter
class CoreDataAdapter: ObservableObject {
    static let shared = CoreDataAdapter()
    private let coreDataManager = CoreDataManager.shared
    private let cloudKitManager = CloudKitManager.shared
    
    @Published var habits: [Habit] = []
    @Published var syncStatus: String = "Initializing..."
    
    private init() {
        initializeSync()
        loadHabits()
    }
    
    // MARK: - Initialize Sync
    private func initializeSync() {
        // Initialize CloudKit sync
        cloudKitManager.initializeCloudKitSync()
        
        // Update sync status
        syncStatus = cloudKitManager.getSyncStatus()
        
        // Monitor sync status changes
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.syncStatus = self.cloudKitManager.getSyncStatus()
            }
        }
    }
    
    // MARK: - Load Habits
    func loadHabits() {
        let habitEntities = coreDataManager.fetchHabits()
        habits = habitEntities.map { $0.toHabit() }
    }
    
    // MARK: - Save Habits
    func saveHabits(_ habits: [Habit]) {
        // Clear existing habits
        let existingEntities = coreDataManager.fetchHabits()
        for entity in existingEntities {
            coreDataManager.deleteHabit(entity)
        }
        
        // Create new habits
        for habit in habits {
            _ = coreDataManager.createHabit(from: habit)
        }
        
        loadHabits()
    }
    
    // MARK: - Create Habit
    func createHabit(_ habit: Habit) {
        _ = coreDataManager.createHabit(from: habit)
        loadHabits()
    }
    
    // MARK: - Update Habit
    func updateHabit(_ habit: Habit) {
        let habitEntities = coreDataManager.fetchHabits()
        if let entity = habitEntities.first(where: { $0.id == habit.id }) {
            coreDataManager.updateHabit(entity, with: habit)
            loadHabits()
        }
    }
    
    // MARK: - Delete Habit
    func deleteHabit(_ habit: Habit) {
        let habitEntities = coreDataManager.fetchHabits()
        if let entity = habitEntities.first(where: { $0.id == habit.id }) {
            coreDataManager.deleteHabit(entity)
            loadHabits()
        }
    }
    
    // MARK: - Toggle Habit Completion
    func toggleHabitCompletion(_ habit: Habit, for date: Date) {
        let habitEntities = coreDataManager.fetchHabits()
        if let entity = habitEntities.first(where: { $0.id == habit.id }) {
            let currentProgress = coreDataManager.getProgress(for: entity, date: date)
            let newProgress = currentProgress > 0 ? 0 : 1
            coreDataManager.markCompletion(for: entity, date: date, progress: newProgress)
            loadHabits()
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
    
    // MARK: - Migration
    func migrateFromUserDefaults() {
        coreDataManager.migrateFromUserDefaults()
        loadHabits()
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
            for record in completionRecords {
                if let dateKey = record.dateKey {
                    completionHistory[dateKey] = Int(record.progress)
                }
            }
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
            reminders: reminders,
            baseline: Int(self.baseline),
            target: Int(self.target)
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
