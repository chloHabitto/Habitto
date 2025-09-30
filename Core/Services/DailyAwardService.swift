import Foundation
import SwiftData
import Combine

/// Service for managing daily awards and streak/XP calculations
@MainActor
public class DailyAwardService: ObservableObject {
    private let modelContext: ModelContext
    private let eventBus: EventBus
    
    public init(modelContext: ModelContext, eventBus: EventBus = EventBus.shared) {
        self.modelContext = modelContext
        self.eventBus = eventBus
    }
    
    /// Called when a habit is completed
    /// Returns true if a daily award was granted
    public func onHabitCompleted(date: Date, userId: String) async -> Bool {
        let dateKey = DateKey.key(for: date)
        
        // Check if all habits are completed for this date
        guard await areAllHabitsCompleted(dateKey: dateKey, userId: userId) else {
            return false
        }
        
        // Check if award already exists (idempotency)
        guard DailyAward.validateUniqueConstraint(userId: userId, dateKey: dateKey, in: modelContext) else {
            return false
        }
        
        // Grant daily award
        let xpGranted = await calculateDailyXP()
        let award = DailyAward(userId: userId, dateKey: dateKey, xpGranted: xpGranted)
        
        modelContext.insert(award)
        
        do {
            try modelContext.save()
            
            // Update streak
            await updateStreak(userId: userId, dateKey: dateKey)
            
            // Emit event
            eventBus.publish(.dailyAwardGranted(dateKey: dateKey))
            
            return true
        } catch {
            print("Failed to save daily award: \(error)")
            return false
        }
    }
    
    /// Called when a habit is uncompleted
    public func onHabitUncompleted(date: Date, userId: String) async {
        let dateKey = DateKey.key(for: date)
        
        // Check if award exists for this date
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let existingAwards = (try? modelContext.fetch(request)) ?? []
        
        guard let award = existingAwards.first else {
            return // No award to revoke
        }
        
        // Revoke award
        modelContext.delete(award)
        
        do {
            try modelContext.save()
            
            // Revert streak
            await revertStreak(userId: userId, dateKey: dateKey)
            
            // Emit event
            eventBus.publish(.dailyAwardRevoked(dateKey: dateKey))
        } catch {
            print("Failed to revoke daily award: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func areAllHabitsCompleted(dateKey: String, userId: String) async -> Bool {
        // Get all habits for the user
        let predicate = #Predicate<HabitData> { habit in
            habit.userId == userId
        }
        
        let request = FetchDescriptor<HabitData>(predicate: predicate)
        let habits = (try? modelContext.fetch(request)) ?? []
        
        // Check if all habits are completed for the given date
        return habits.allSatisfy { habit in
            // Convert HabitData to Habit and check completion
            let habitStruct = Habit(
                id: habit.id,
                name: habit.name,
                emoji: habit.emoji,
                color: habit.color,
                schedule: habit.schedule,
                difficulty: habit.difficulty,
                originalOrder: habit.originalOrder,
                completionHistory: habit.completionHistory,
                difficultyHistory: habit.difficultyHistory,
                usageHistory: habit.usageHistory,
                userId: habit.userId,
                createdAt: habit.createdAt,
                updatedAt: habit.updatedAt
            )
            return habitStruct.isCompleted(for: DateKey.startOfDay(for: dateKey))
        }
    }
    
    private func calculateDailyXP() async -> Int {
        // Calculate XP based on completed habits
        // For now, returning a fixed value
        return 100
    }
    
    private func updateStreak(userId: String, dateKey: String) async {
        // Update user streak based on consecutive daily awards
        // Implementation would depend on your user model
    }
    
    private func revertStreak(userId: String, dateKey: String) async {
        // Revert user streak when award is revoked
        // Implementation would depend on your user model
    }
}
