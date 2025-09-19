import Foundation
import SwiftData
import OSLog

// MARK: - SwiftData Storage Implementation
@MainActor
final class SwiftDataStorage: HabitStorageProtocol {
    typealias DataType = Habit
    
    private let container = SwiftDataContainer.shared
    private let logger = Logger(subsystem: "com.habitto.app", category: "SwiftDataStorage")
    
    // MARK: - Generic Data Storage Methods
    
    func save<T: Codable>(_ data: T, forKey key: String, immediate: Bool = false) async throws {
        // For generic data, we'll store as JSON in a separate table
        // This is a fallback for non-habit data
        logger.warning("Generic save called for key: \(key) - consider using specific methods")
        
        let jsonData = try JSONEncoder().encode(data)
        // Store in UserDefaults as fallback for now
        UserDefaults.standard.set(jsonData, forKey: key)
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T? {
        // For generic data, load from UserDefaults fallback
        logger.warning("Generic load called for key: \(key) - consider using specific methods")
        
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        
        return try JSONDecoder().decode(type, from: data)
    }
    
    func delete(forKey key: String) async throws {
        logger.warning("Generic delete called for key: \(key) - consider using specific methods")
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    func exists(forKey key: String) async throws -> Bool {
        return UserDefaults.standard.object(forKey: key) != nil
    }
    
    func keys(withPrefix prefix: String) async throws -> [String] {
        // This is not applicable for SwiftData as we use relationships
        return []
    }
    
    // MARK: - Habit-Specific Storage Methods
    
    func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
        logger.info("Saving \(habits.count) habits to SwiftData")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Get existing habits
            let existingHabits = try await loadHabits()
            let existingHabitIds = Set(existingHabits.map { $0.id })
            
            for habit in habits {
                if let existingHabitData = try await loadHabitData(by: habit.id) {
                    // Update existing habit
                    existingHabitData.updateFromHabit(habit)
                    await updateHabitHistory(existingHabitData, from: habit)
                } else {
                    // Create new habit
                    let habitData = HabitData(
                        id: habit.id,
                        name: habit.name,
                        habitDescription: habit.description,
                        icon: habit.icon,
                        color: habit.color,
                        habitType: habit.habitType,
                        schedule: habit.schedule,
                        goal: habit.goal,
                        reminder: habit.reminder,
                        startDate: habit.startDate,
                        endDate: habit.endDate,
                        isCompleted: habit.isCompleted,
                        streak: habit.streak
                    )
                    
                    container.modelContext.insert(habitData)
                    await updateHabitHistory(habitData, from: habit)
                }
            }
            
            // Remove habits that are no longer in the list
            let currentHabitIds = Set(habits.map { $0.id })
            let habitsToRemove = existingHabitIds.subtracting(currentHabitIds)
            
            for habitId in habitsToRemove {
                if let habitData = try await loadHabitData(by: habitId) {
                    container.modelContext.delete(habitData)
                }
            }
            
            try container.modelContext.save()
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Successfully saved \(habits.count) habits in \(String(format: "%.3f", timeElapsed))s")
            
        } catch {
            logger.error("Failed to save habits: \(error.localizedDescription)")
            throw DataError.storage(StorageError(type: .unknown, message: "Failed to save habits: \(error.localizedDescription)", underlyingError: error))
        }
    }
    
    func loadHabits() async throws -> [Habit] {
        logger.info("Loading habits from SwiftData")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let descriptor = FetchDescriptor<HabitData>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            
            let habitDataArray = try container.modelContext.fetch(descriptor)
            let habits = await MainActor.run {
                habitDataArray.map { $0.toHabit() }
            }
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Successfully loaded \(habits.count) habits in \(String(format: "%.3f", timeElapsed))s")
            
            return habits
            
        } catch {
            logger.error("Failed to load habits: \(error.localizedDescription)")
            throw DataError.storage(StorageError(type: .unknown, message: "Failed to load habits: \(error.localizedDescription)", underlyingError: error))
        }
    }
    
    func saveHabit(_ habit: Habit, immediate: Bool = false) async throws {
        logger.info("Saving single habit: \(habit.name)")
        
        do {
            if let existingHabitData = try await loadHabitData(by: habit.id) {
                // Update existing habit
                existingHabitData.updateFromHabit(habit)
                await updateHabitHistory(existingHabitData, from: habit)
            } else {
                // Create new habit
                let habitData = HabitData(
                    id: habit.id,
                    name: habit.name,
                    habitDescription: habit.description,
                    icon: habit.icon,
                    color: habit.color,
                    habitType: habit.habitType,
                    schedule: habit.schedule,
                    goal: habit.goal,
                    reminder: habit.reminder,
                    startDate: habit.startDate,
                    endDate: habit.endDate,
                    isCompleted: habit.isCompleted,
                    streak: habit.streak
                )
                
                container.modelContext.insert(habitData)
                await updateHabitHistory(habitData, from: habit)
            }
            
            try container.modelContext.save()
            logger.info("Successfully saved habit: \(habit.name)")
            
        } catch {
            logger.error("Failed to save habit: \(error.localizedDescription)")
            throw DataError.storage(StorageError(type: .unknown, message: "Failed to save habit: \(error.localizedDescription)", underlyingError: error))
        }
    }
    
    func loadHabit(id: UUID) async throws -> Habit? {
        logger.info("Loading habit with ID: \(id)")
        
        do {
            guard let habitData = try await loadHabitData(by: id) else {
                logger.info("Habit not found with ID: \(id)")
                return nil
            }
            
            let habit = await MainActor.run {
                habitData.toHabit()
            }
            logger.info("Successfully loaded habit: \(habit.name)")
            return habit
            
        } catch {
            logger.error("Failed to load habit: \(error.localizedDescription)")
            throw DataError.storage(StorageError(type: .unknown, message: "Failed to load habit: \(error.localizedDescription)", underlyingError: error))
        }
    }
    
    func deleteHabit(id: UUID) async throws {
        logger.info("Deleting habit with ID: \(id)")
        
        do {
            guard let habitData = try await loadHabitData(by: id) else {
                logger.warning("Habit not found for deletion: \(id)")
                return
            }
            
            container.modelContext.delete(habitData)
            try container.modelContext.save()
            
            logger.info("Successfully deleted habit with ID: \(id)")
            
        } catch {
            logger.error("Failed to delete habit: \(error.localizedDescription)")
            throw DataError.storage(StorageError(type: .unknown, message: "Failed to delete habit: \(error.localizedDescription)", underlyingError: error))
        }
    }
    
    func clearAllHabits() async throws {
        logger.info("Clearing all habits from SwiftData")
        
        do {
            let descriptor = FetchDescriptor<HabitData>()
            let habitDataArray = try container.modelContext.fetch(descriptor)
            
            for habitData in habitDataArray {
                container.modelContext.delete(habitData)
            }
            
            try container.modelContext.save()
            logger.info("Successfully cleared all habits")
            
        } catch {
            logger.error("Failed to clear all habits: \(error.localizedDescription)")
            throw DataError.storage(StorageError(type: .unknown, message: "Failed to clear all habits: \(error.localizedDescription)", underlyingError: error))
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func loadHabitData(by id: UUID) async throws -> HabitData? {
        let descriptor = FetchDescriptor<HabitData>(
            predicate: #Predicate { $0.id == id }
        )
        
        let results = try container.modelContext.fetch(descriptor)
        return results.first
    }
    
    private func updateHabitHistory(_ habitData: HabitData, from habit: Habit) async {
        // Update completion history
        await updateCompletionHistory(habitData, from: habit)
        
        // Update difficulty history
        await updateDifficultyHistory(habitData, from: habit)
        
        // Update usage history
        await updateUsageHistory(habitData, from: habit)
    }
    
    private func updateCompletionHistory(_ habitData: HabitData, from habit: Habit) async {
        // Clear existing completion history
        habitData.completionHistory.removeAll()
        
        // Add new completion records (convert from String keys to Date)
        for (dateString, isCompletedInt) in habit.completionHistory {
            if let date = ISO8601DateHelper.shared.date(from: dateString) {
                let isCompleted = isCompletedInt == 1
                let record = CompletionRecord(date: date, isCompleted: isCompleted)
                habitData.completionHistory.append(record)
            }
        }
    }
    
    private func updateDifficultyHistory(_ habitData: HabitData, from habit: Habit) async {
        // Clear existing difficulty history
        habitData.difficultyHistory.removeAll()
        
        // Add new difficulty records (convert from String keys to Date)
        for (dateString, difficulty) in habit.difficultyHistory {
            if let date = ISO8601DateHelper.shared.date(from: dateString) {
                let record = DifficultyRecord(date: date, difficulty: difficulty)
                habitData.difficultyHistory.append(record)
            }
        }
    }
    
    private func updateUsageHistory(_ habitData: HabitData, from habit: Habit) async {
        // Clear existing usage history
        habitData.usageHistory.removeAll()
        
        // Add new usage records
        for (key, value) in habit.actualUsage {
            let record = UsageRecord(key: key, value: value)
            habitData.usageHistory.append(record)
        }
    }
}
