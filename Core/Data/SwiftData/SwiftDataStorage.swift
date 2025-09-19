import Foundation
import SwiftData
import OSLog

// MARK: - SwiftData Storage Implementation
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
                if let existingSimpleHabitData = try await loadSimpleHabitData(by: habit.id) {
                    // Update existing habit
                    existingSimpleHabitData.updateFromHabit(habit)
                } else {
                    // Create new habit
                    let habitData = SimpleHabitData(
                        id: habit.id,
                        name: habit.name,
                        habitDescription: habit.description,
                        icon: habit.icon,
                        colorString: habit.color.toHexString(),
                        habitType: habit.habitType.rawValue,
                        schedule: habit.schedule,
                        goal: habit.goal,
                        reminder: habit.reminder,
                        startDate: habit.startDate,
                        endDate: habit.endDate,
                        isCompleted: habit.isCompleted,
                        streak: habit.streak,
                        completionHistoryJSON: encodeCompletionHistory(habit.completionHistory),
                        difficultyHistoryJSON: encodeDifficultyHistory(habit.difficultyHistory),
                        usageHistoryJSON: encodeUsageHistory(habit.actualUsage)
                    )
                    
                    container.modelContext.insert(habitData)
                }
            }
            
            // Remove habits that are no longer in the list
            let currentHabitIds = Set(habits.map { $0.id })
            let habitsToRemove = existingHabitIds.subtracting(currentHabitIds)
            
            for habitId in habitsToRemove {
                if let habitData = try await loadSimpleHabitData(by: habitId) {
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
            let descriptor = FetchDescriptor<SimpleHabitData>(
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
            if let existingSimpleHabitData = try await loadSimpleHabitData(by: habit.id) {
                // Update existing habit
                existingSimpleHabitData.updateFromHabit(habit)
            } else {
                // Create new habit
                let habitData = SimpleHabitData(
                    id: habit.id,
                    name: habit.name,
                    habitDescription: habit.description,
                    icon: habit.icon,
                    colorString: habit.color.toHexString(),
                    habitType: habit.habitType.rawValue,
                    schedule: habit.schedule,
                    goal: habit.goal,
                    reminder: habit.reminder,
                    startDate: habit.startDate,
                    endDate: habit.endDate,
                    isCompleted: habit.isCompleted,
                    streak: habit.streak,
                    completionHistoryJSON: encodeCompletionHistory(habit.completionHistory),
                    difficultyHistoryJSON: encodeDifficultyHistory(habit.difficultyHistory),
                    usageHistoryJSON: encodeUsageHistory(habit.actualUsage)
                )
                
                container.modelContext.insert(habitData)
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
            guard let habitData = try await loadSimpleHabitData(by: id) else {
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
            guard let habitData = try await loadSimpleHabitData(by: id) else {
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
            let descriptor = FetchDescriptor<SimpleHabitData>()
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
    
    private func loadSimpleHabitData(by id: UUID) async throws -> SimpleHabitData? {
        let descriptor = FetchDescriptor<SimpleHabitData>(
            predicate: #Predicate { $0.id == id }
        )
        
        let results = try await container.modelContext.fetch(descriptor)
        return results.first
    }
    
    
    // MARK: - Helper Methods for SimpleSimpleHabitData
    
    private func encodeCompletionHistory(_ history: [String: Int]) -> String {
        do {
            let data = try JSONEncoder().encode(history)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            logger.error("Failed to encode completion history: \(error)")
            return "{}"
        }
    }
    
    private func encodeDifficultyHistory(_ history: [String: Int]) -> String {
        do {
            let data = try JSONEncoder().encode(history)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            logger.error("Failed to encode difficulty history: \(error)")
            return "{}"
        }
    }
    
    private func encodeUsageHistory(_ history: [String: Int]) -> String {
        do {
            let data = try JSONEncoder().encode(history)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            logger.error("Failed to encode usage history: \(error)")
            return "{}"
        }
    }
    
    private func decodeCompletionHistory(_ jsonString: String) -> [String: Int] {
        guard let data = jsonString.data(using: .utf8) else { return [:] }
        do {
            return try JSONDecoder().decode([String: Int].self, from: data)
        } catch {
            logger.error("Failed to decode completion history: \(error)")
            return [:]
        }
    }
    
    private func decodeDifficultyHistory(_ jsonString: String) -> [String: Int] {
        guard let data = jsonString.data(using: .utf8) else { return [:] }
        do {
            return try JSONDecoder().decode([String: Int].self, from: data)
        } catch {
            logger.error("Failed to decode difficulty history: \(error)")
            return [:]
        }
    }
    
    private func decodeUsageHistory(_ jsonString: String) -> [String: Int] {
        guard let data = jsonString.data(using: .utf8) else { return [:] }
        do {
            return try JSONDecoder().decode([String: Int].self, from: data)
        } catch {
            logger.error("Failed to decode usage history: \(error)")
            return [:]
        }
    }
}
