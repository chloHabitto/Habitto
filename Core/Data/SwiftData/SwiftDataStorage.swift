import Foundation
import SwiftData
import OSLog

// MARK: - SwiftData Storage Implementation
@MainActor
final class SwiftDataStorage: HabitStorageProtocol {
    typealias DataType = Habit
    
    private lazy var container = SwiftDataContainer.shared
    private let logger = Logger(subsystem: "com.habitto.app", category: "SwiftDataStorage")
    
    nonisolated init() {}
    
    // Helper method to get current user ID for data isolation
    private func getCurrentUserId() async -> String? {
        return await MainActor.run {
            return AuthenticationManager.shared.currentUser?.uid
        }
    }
    
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
                } else {
                    // Create new habit with user ID
                    let habitData = HabitData(
                        id: habit.id,
                        userId: await getCurrentUserId() ?? "", // Use current user ID or empty string for guest
                        name: habit.name,
                        habitDescription: habit.description,
                        icon: habit.icon,
                        color: habit.color,
                        habitType: habit.habitType,
                        schedule: habit.schedule,
                        goal: habit.goal,
                        reminder: habit.reminder,
                        startDate: habit.startDate,
                        endDate: habit.endDate
                    )
                    
                    // Add completion history
                    for (dateString, isCompleted) in habit.completionHistory {
                        if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
                            let completionRecord = CompletionRecord(
                                userId: "legacy",
                                habitId: habitData.id,
                                date: date,
                                dateKey: Habit.dateKey(for: date),
                                isCompleted: isCompleted == 1
                            )
                            habitData.completionHistory.append(completionRecord)
                        }
                    }
                    
                    // Add difficulty history
                    for (dateString, difficulty) in habit.difficultyHistory {
                        if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
                            let difficultyRecord = DifficultyRecord(
                                userId: await getCurrentUserId() ?? "",
                                habitId: habitData.id,
                                date: date,
                                difficulty: difficulty
                            )
                            habitData.difficultyHistory.append(difficultyRecord)
                        }
                    }
                    
                    // Add usage history
                    for (key, value) in habit.actualUsage {
                        let usageRecord = UsageRecord(
                            userId: await getCurrentUserId() ?? "",
                            habitId: habitData.id,
                            key: key,
                            value: value
                        )
                        habitData.usageHistory.append(usageRecord)
                    }
                    
                    container.modelContext.insert(habitData)
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
        let currentUserId = await getCurrentUserId()
        logger.info("Loading habits from SwiftData for user: \(currentUserId ?? "guest")")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Create user-specific fetch descriptor
            var descriptor = FetchDescriptor<HabitData>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            
            // Filter by current user ID if authenticated, otherwise show guest data
            if let userId = currentUserId {
                descriptor.predicate = #Predicate<HabitData> { habitData in
                    habitData.userId == userId
                }
            } else {
                // For guest users, show data with empty userId
                descriptor.predicate = #Predicate<HabitData> { habitData in
                    habitData.userId == ""
                }
            }
            
            let habitDataArray = try container.modelContext.fetch(descriptor)
            let habits = habitDataArray.map { $0.toHabit() }
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Successfully loaded \(habits.count) habits for user: \(currentUserId ?? "guest") in \(String(format: "%.3f", timeElapsed))s")
            
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
                
                // Update completion history
                existingHabitData.completionHistory.removeAll()
                for (dateString, isCompleted) in habit.completionHistory {
                    if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
                        let completionRecord = CompletionRecord(
                            userId: "legacy",
                            habitId: existingHabitData.id,
                            date: date,
                            dateKey: Habit.dateKey(for: date),
                            isCompleted: isCompleted == 1
                        )
                        existingHabitData.completionHistory.append(completionRecord)
                    }
                }
                
                // Update difficulty history
                existingHabitData.difficultyHistory.removeAll()
                for (dateString, difficulty) in habit.difficultyHistory {
                    if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
                        let difficultyRecord = DifficultyRecord(
                            userId: await getCurrentUserId() ?? "",
                            habitId: existingHabitData.id,
                            date: date,
                            difficulty: difficulty
                        )
                        existingHabitData.difficultyHistory.append(difficultyRecord)
                    }
                }
                
                // Update usage history
                existingHabitData.usageHistory.removeAll()
                for (key, value) in habit.actualUsage {
                    let usageRecord = UsageRecord(
                        userId: await getCurrentUserId() ?? "",
                        habitId: existingHabitData.id,
                        key: key,
                        value: value
                    )
                    existingHabitData.usageHistory.append(usageRecord)
                }
            } else {
                // Create new habit
                let habitData = HabitData(
                    id: habit.id,
                    userId: await getCurrentUserId() ?? "", // Use current user ID or empty string for guest
                    name: habit.name,
                    habitDescription: habit.description,
                    icon: habit.icon,
                    color: habit.color,
                    habitType: habit.habitType,
                    schedule: habit.schedule,
                    goal: habit.goal,
                    reminder: habit.reminder,
                    startDate: habit.startDate,
                    endDate: habit.endDate
                )
                
                // Add completion history
                for (dateString, isCompleted) in habit.completionHistory {
                    if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
                        let completionRecord = CompletionRecord(
                            userId: "legacy",
                            habitId: habitData.id,
                            date: date,
                            dateKey: Habit.dateKey(for: date),
                            isCompleted: isCompleted == 1
                        )
                        habitData.completionHistory.append(completionRecord)
                    }
                }
                
                // Add difficulty history
                for (dateString, difficulty) in habit.difficultyHistory {
                    if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
                        let difficultyRecord = DifficultyRecord(
                            userId: await getCurrentUserId() ?? "",
                            habitId: habitData.id,
                            date: date,
                            difficulty: difficulty
                        )
                        habitData.difficultyHistory.append(difficultyRecord)
                    }
                }
                
                // Add usage history
                for (key, value) in habit.actualUsage {
                    let usageRecord = UsageRecord(
                        userId: await getCurrentUserId() ?? "",
                        habitId: habitData.id,
                        key: key,
                        value: value
                    )
                    habitData.usageHistory.append(usageRecord)
                }
                
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
            guard let habitData = try await loadHabitData(by: id) else {
                logger.info("Habit not found with ID: \(id)")
                return nil
            }
            
            let habit = habitData.toHabit()
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
    
    /// Clear all habits for the current user
    func clearAllHabits() async throws {
        let currentUserId = await getCurrentUserId()
        logger.info("Clearing all habits from SwiftData for user: \(currentUserId ?? "guest")")
        
        do {
            // Create user-specific fetch descriptor
            var descriptor = FetchDescriptor<HabitData>()
            
            // Filter by current user ID if authenticated, otherwise clear guest data
            if let userId = currentUserId {
                descriptor.predicate = #Predicate<HabitData> { habitData in
                    habitData.userId == userId
                }
            } else {
                // For guest users, clear data with empty userId
                descriptor.predicate = #Predicate<HabitData> { habitData in
                    habitData.userId == ""
                }
            }
            
            let habitDataArray = try container.modelContext.fetch(descriptor)
            
            for habitData in habitDataArray {
                container.modelContext.delete(habitData)
            }
            
            try container.modelContext.save()
            logger.info("Successfully cleared \(habitDataArray.count) habits for user: \(currentUserId ?? "guest")")
            
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
    
}
