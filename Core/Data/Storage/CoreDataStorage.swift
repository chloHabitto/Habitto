import Foundation
import CoreData
import SwiftUI

// MARK: - Core Data Storage Implementation
/// Core Data implementation of the habit storage protocol
@MainActor
class CoreDataStorage: HabitStorageProtocol {
    typealias DataType = Habit
    
    private let coreDataManager: CoreDataManager
    private let context: NSManagedObjectContext
    private let backgroundQueue = BackgroundQueueManager.shared
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        self.context = coreDataManager.context
    }
    
    // MARK: - Generic Data Storage Methods
    
    func save<T: Codable>(_ data: T, forKey key: String, immediate: Bool = false) async throws {
        // For Core Data, we don't use keys in the same way
        // This method is mainly for protocol compliance
        throw DataStorageError.operationNotSupported("Generic save not supported in Core Data storage")
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T? {
        // For Core Data, we don't use keys in the same way
        // This method is mainly for protocol compliance
        throw DataStorageError.operationNotSupported("Generic load not supported in Core Data storage")
    }
    
    func delete(forKey key: String) async throws {
        // For Core Data, we don't use keys in the same way
        // This method is mainly for protocol compliance
        throw DataStorageError.operationNotSupported("Generic delete not supported in Core Data storage")
    }
    
    func exists(forKey key: String) async throws -> Bool {
        // For Core Data, we don't use keys in the same way
        // This method is mainly for protocol compliance
        throw DataStorageError.operationNotSupported("Generic exists not supported in Core Data storage")
    }
    
    func keys(withPrefix prefix: String) async throws -> [String] {
        // For Core Data, we don't use keys in the same way
        // This method is mainly for protocol compliance
        throw DataStorageError.operationNotSupported("Generic keys not supported in Core Data storage")
    }
    
    // MARK: - Habit-Specific Storage Methods
    
    func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
        try await backgroundQueue.executeSerial {
            try self.context.performAndWait { [weak self] in
                guard let self = self else {
                    throw DataStorageError.contextUnavailable
                }
                
                // Clear existing habits
                let fetchRequest: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
                let existingHabits = try self.context.fetch(fetchRequest)
                for habit in existingHabits {
                    self.context.delete(habit)
                }
                
                // Create new habit entities
                for habit in habits {
                    let entity = HabitEntity(context: self.context)
                    self.updateEntity(entity, with: habit)
                }
                
                // Save context
                try self.context.save()
            }
        }
    }
    
    func loadHabits() async throws -> [Habit] {
        try await backgroundQueue.execute {
            try self.context.performAndWait { [weak self] in
                guard let self = self else {
                    throw DataStorageError.contextUnavailable
                }
                
                let fetchRequest: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
                let entities = try self.context.fetch(fetchRequest)
                return entities.compactMap { self.habit(from: $0) }
            }
        }
    }
    
    func saveHabit(_ habit: Habit, immediate: Bool = false) async throws {
        try await backgroundQueue.executeSerial {
            try self.context.performAndWait { [weak self] in
                guard let self = self else {
                    throw DataStorageError.contextUnavailable
                }
                
                // Find existing entity or create new one
                let fetchRequest: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", habit.id as CVarArg)
                let entities = try self.context.fetch(fetchRequest)
                
                let entity = entities.first ?? HabitEntity(context: self.context)
                self.updateEntity(entity, with: habit)
                
                try self.context.save()
            }
        }
    }
    
    func loadHabit(id: UUID) async throws -> Habit? {
        try await backgroundQueue.execute {
            try self.context.performAndWait { [weak self] in
                guard let self = self else {
                    throw DataStorageError.contextUnavailable
                }
                
                let fetchRequest: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                let entities = try self.context.fetch(fetchRequest)
                
                if let entity = entities.first {
                    return self.habit(from: entity)
                } else {
                    return nil
                }
            }
        }
    }
    
    func deleteHabit(id: UUID) async throws {
        try await backgroundQueue.executeSerial {
            try self.context.performAndWait { [weak self] in
                guard let self = self else {
                    throw DataStorageError.contextUnavailable
                }
                
                let fetchRequest: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                let entities = try self.context.fetch(fetchRequest)
                
                for entity in entities {
                    self.context.delete(entity)
                }
                
                try self.context.save()
            }
        }
    }
    
    func clearAllHabits() async throws {
        try await backgroundQueue.executeSerial {
            try self.context.performAndWait { [weak self] in
                guard let self = self else {
                    throw DataStorageError.contextUnavailable
                }
                
                let fetchRequest: NSFetchRequest<HabitEntity> = HabitEntity.fetchRequest()
                let entities = try self.context.fetch(fetchRequest)
                
                for entity in entities {
                    self.context.delete(entity)
                }
                
                try self.context.save()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateEntity(_ entity: HabitEntity, with habit: Habit) {
        entity.id = habit.id
        entity.name = habit.name
        entity.habitDescription = habit.description
        entity.icon = habit.icon
        entity.colorHex = habit.color.description
        entity.habitType = habit.habitType.rawValue
        entity.schedule = habit.schedule
        entity.goal = habit.goal
        entity.reminder = habit.reminder
        entity.startDate = habit.startDate
        entity.endDate = habit.endDate
        entity.isCompleted = habit.isCompleted
        entity.streak = Int32(habit.streak)
        entity.createdAt = habit.createdAt
        entity.baseline = Double(habit.baseline)
        entity.target = Double(habit.target)
        
        // Convert completion history
        if (try? JSONEncoder().encode(habit.completionHistory)) != nil {
            entity.completionHistory = NSSet(array: []) // TODO: Implement proper completion history storage
        }
        
        // Convert difficulty history
        if (try? JSONEncoder().encode(habit.difficultyHistory)) != nil {
            entity.difficultyLogs = NSSet(array: []) // TODO: Implement proper difficulty history storage
        }
        
        // Convert actual usage
        if (try? JSONEncoder().encode(habit.actualUsage)) != nil {
            entity.usageRecords = NSSet(array: []) // TODO: Implement proper usage records storage
        }
        
        // Convert reminders
        if (try? JSONEncoder().encode(habit.reminders)) != nil {
            entity.reminders = NSSet(array: []) // TODO: Implement proper reminders storage
        }
    }
    
    private func habit(from entity: HabitEntity) -> Habit? {
        guard let id = entity.id,
              let name = entity.name,
              let description = entity.habitDescription,
              let icon = entity.icon,
              let habitTypeString = entity.habitType,
              let habitType = HabitType(rawValue: habitTypeString),
              let schedule = entity.schedule,
              let goal = entity.goal,
              let reminder = entity.reminder,
              let startDate = entity.startDate,
              let createdAt = entity.createdAt else {
            return nil
        }
        
        // Convert color from hex string
        let color = Color.blue // TODO: Implement proper color conversion from hex
        
        return Habit(
            id: id,
            name: name,
            description: description,
            icon: icon,
            color: color,
            habitType: habitType,
            schedule: schedule,
            goal: goal,
            reminder: reminder,
            startDate: startDate,
            endDate: entity.endDate,
            isCompleted: entity.isCompleted,
            streak: Int(entity.streak),
            createdAt: createdAt,
            reminders: [], // TODO: Convert from entity.reminders
            baseline: Int(entity.baseline),
            target: Int(entity.target),
            completionHistory: [:], // TODO: Convert from entity.completionHistory
            difficultyHistory: [:], // TODO: Convert from entity.difficultyHistory
            actualUsage: [:] // TODO: Convert from entity.usageRecords
        )
    }
}

// MARK: - Data Storage Errors
enum DataStorageError: Error, LocalizedError {
    case contextUnavailable
    case operationNotSupported(String)
    case encodingFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .contextUnavailable:
            return "Core Data context is not available"
        case .operationNotSupported(let message):
            return "Operation not supported: \(message)"
        case .encodingFailed:
            return "Failed to encode data"
        case .decodingFailed:
            return "Failed to decode data"
        }
    }
}
