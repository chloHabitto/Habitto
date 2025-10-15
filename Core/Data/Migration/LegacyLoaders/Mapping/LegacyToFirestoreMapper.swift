import Foundation
import FirebaseFirestore
import OSLog

// MARK: - Legacy To Firestore Mapper

/// Maps legacy data items to Firestore document structures and write operations
final class LegacyToFirestoreMapper: LegacyToFirestoreMapperProtocol {
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "LegacyToFirestoreMapper")
    
    // MARK: - LegacyToFirestoreMapper Implementation
    
    func mapItems(_ items: [LegacyDataItem], for userId: String) async throws -> [FirestoreWriteOperation] {
        logger.debug("🔄 LegacyToFirestoreMapper: Mapping \(items.count) items for user \(userId)")
        
        var operations: [FirestoreWriteOperation] = []
        
        for item in items {
            let mappedOperations = try await mapItem(item, for: userId)
            operations.append(contentsOf: mappedOperations)
        }
        
        logger.debug("🔄 LegacyToFirestoreMapper: Generated \(operations.count) write operations")
        return operations
    }
    
    // MARK: - Private Mapping Methods
    
    private func mapItem(_ item: LegacyDataItem, for userId: String) async throws -> [FirestoreWriteOperation] {
        switch item.type {
        case .habit:
            return try await mapHabitItem(item, for: userId)
        case .completion:
            return try await mapCompletionItem(item, for: userId)
        case .xpState:
            return try await mapXPStateItem(item, for: userId)
        case .xpLedger:
            return try await mapXPLedgerItem(item, for: userId)
        case .streak:
            return try await mapStreakItem(item, for: userId)
        case .goalVersion:
            return try await mapGoalVersionItem(item, for: userId)
        case .userSettings:
            return try await mapUserSettingsItem(item, for: userId)
        }
    }
    
    // MARK: - Specific Item Mappers
    
    private func mapHabitItem(_ item: LegacyDataItem, for userId: String) async throws -> [FirestoreWriteOperation] {
        guard let habitId = item.data["id"] as? String else {
            throw MappingError.missingRequiredField("id")
        }
        
        let firestoreData = mapHabitDataToFirestore(item.data)
        let path = "users/\(userId)/habits/\(habitId)"
        
        return [
            FirestoreWriteOperation(
                type: .set,
                path: path,
                data: firestoreData,
                merge: false
            )
        ]
    }
    
    private func mapCompletionItem(_ item: LegacyDataItem, for userId: String) async throws -> [FirestoreWriteOperation] {
        guard let habitId = item.data["habitId"] as? String else {
            throw MappingError.missingRequiredField("habitId")
        }
        
        // Extract date from stable key (format: habitId_YYYY-MM-DD)
        let dateKey = String(item.stableKey.dropFirst(habitId.count + 1))
        
        let firestoreData = mapCompletionDataToFirestore(item.data)
        let path = "users/\(userId)/completions/\(dateKey)/\(habitId)"
        
        return [
            FirestoreWriteOperation(
                type: .set,
                path: path,
                data: firestoreData,
                merge: true
            )
        ]
    }
    
    private func mapXPStateItem(_ item: LegacyDataItem, for userId: String) async throws -> [FirestoreWriteOperation] {
        let firestoreData = mapXPStateDataToFirestore(item.data)
        let path = "users/\(userId)/xp/state"
        
        return [
            FirestoreWriteOperation(
                type: .set,
                path: path,
                data: firestoreData,
                merge: true
            )
        ]
    }
    
    private func mapXPLedgerItem(_ item: LegacyDataItem, for userId: String) async throws -> [FirestoreWriteOperation] {
        // Generate a unique event ID from the stable key
        let eventId = generateEventId(from: item.stableKey)
        
        let firestoreData = mapXPLedgerDataToFirestore(item.data)
        let path = "users/\(userId)/xp/ledger/\(eventId)"
        
        return [
            FirestoreWriteOperation(
                type: .set,
                path: path,
                data: firestoreData,
                merge: false
            )
        ]
    }
    
    private func mapStreakItem(_ item: LegacyDataItem, for userId: String) async throws -> [FirestoreWriteOperation] {
        guard let habitId = item.data["habitId"] as? String else {
            throw MappingError.missingRequiredField("habitId")
        }
        
        let firestoreData = mapStreakDataToFirestore(item.data)
        let path = "users/\(userId)/streaks/\(habitId)"
        
        return [
            FirestoreWriteOperation(
                type: .set,
                path: path,
                data: firestoreData,
                merge: true
            )
        ]
    }
    
    private func mapGoalVersionItem(_ item: LegacyDataItem, for userId: String) async throws -> [FirestoreWriteOperation] {
        guard let habitId = item.data["habitId"] as? String,
              let effectiveDate = item.data["effectiveDate"] as? Date else {
            throw MappingError.missingRequiredField("habitId or effectiveDate")
        }
        
        // Generate version ID from effective date
        let versionId = generateVersionId(for: habitId, effectiveDate: effectiveDate)
        
        let firestoreData = mapGoalVersionDataToFirestore(item.data)
        let path = "users/\(userId)/goalVersions/\(versionId)"
        
        return [
            FirestoreWriteOperation(
                type: .set,
                path: path,
                data: firestoreData,
                merge: false
            )
        ]
    }
    
    private func mapUserSettingsItem(_ item: LegacyDataItem, for userId: String) async throws -> [FirestoreWriteOperation] {
        let firestoreData = mapUserSettingsDataToFirestore(item.data)
        let path = "users/\(userId)/settings"
        
        return [
            FirestoreWriteOperation(
                type: .set,
                path: path,
                data: firestoreData,
                merge: true
            )
        ]
    }
    
    // MARK: - Data Transformation Methods
    
    private func mapHabitDataToFirestore(_ data: [String: Any]) -> [String: Any] {
        var firestoreData: [String: Any] = [:]
        
        // Map core fields
        if let id = data["id"] as? String { firestoreData["id"] = id }
        if let userId = data["userId"] as? String { firestoreData["userId"] = userId }
        if let name = data["name"] as? String { firestoreData["name"] = name }
        if let description = data["habitDescription"] as? String { firestoreData["description"] = description }
        if let icon = data["icon"] as? String { firestoreData["icon"] = icon }
        if let colorData = data["colorData"] as? Data { firestoreData["colorData"] = colorData }
        if let habitType = data["habitType"] as? String { firestoreData["habitType"] = habitType }
        if let schedule = data["schedule"] as? String { firestoreData["schedule"] = schedule }
        if let goal = data["goal"] as? String { firestoreData["goal"] = goal }
        if let reminder = data["reminder"] as? String { firestoreData["reminder"] = reminder }
        if let startDate = data["startDate"] as? Date { firestoreData["startDate"] = startDate }
        if let endDate = data["endDate"] as? Date { firestoreData["endDate"] = endDate }
        if let createdAt = data["createdAt"] as? Date { firestoreData["createdAt"] = createdAt }
        if let updatedAt = data["updatedAt"] as? Date { firestoreData["updatedAt"] = updatedAt }
        
        // Add Firestore-specific fields
        firestoreData["_migrated"] = true
        firestoreData["_migrationVersion"] = "1.0.0"
        firestoreData["_migrationTimestamp"] = FieldValue.serverTimestamp()
        
        return firestoreData
    }
    
    private func mapCompletionDataToFirestore(_ data: [String: Any]) -> [String: Any] {
        var firestoreData: [String: Any] = [:]
        
        if let id = data["id"] as? String { firestoreData["id"] = id }
        if let habitId = data["habitId"] as? String { firestoreData["habitId"] = habitId }
        if let timestamp = data["timestamp"] as? Date { firestoreData["timestamp"] = timestamp }
        if let progress = data["progress"] as? Double { firestoreData["progress"] = progress }
        if let date = data["date"] as? Date { firestoreData["date"] = date }
        if let notes = data["notes"] as? String { firestoreData["notes"] = notes }
        if let isCompleted = data["isCompleted"] as? Bool { firestoreData["isCompleted"] = isCompleted }
        if let dateKey = data["dateKey"] as? String { firestoreData["dateKey"] = dateKey }
        if let timeBlock = data["timeBlock"] as? String { firestoreData["timeBlock"] = timeBlock }
        
        // Add Firestore-specific fields
        firestoreData["_migrated"] = true
        firestoreData["_migrationVersion"] = "1.0.0"
        firestoreData["_migrationTimestamp"] = FieldValue.serverTimestamp()
        
        return firestoreData
    }
    
    private func mapXPStateDataToFirestore(_ data: [String: Any]) -> [String: Any] {
        var firestoreData: [String: Any] = [:]
        
        if let userId = data["userId"] as? String { firestoreData["userId"] = userId }
        if let totalXP = data["totalXP"] as? Int { firestoreData["totalXP"] = totalXP }
        if let currentLevel = data["currentLevel"] as? Int { firestoreData["currentLevel"] = currentLevel }
        if let xpToNextLevel = data["xpToNextLevel"] as? Int { firestoreData["xpToNextLevel"] = xpToNextLevel }
        if let createdAt = data["createdAt"] as? Date { firestoreData["createdAt"] = createdAt }
        if let updatedAt = data["updatedAt"] as? Date { firestoreData["updatedAt"] = updatedAt }
        
        // Add Firestore-specific fields
        firestoreData["_migrated"] = true
        firestoreData["_migrationVersion"] = "1.0.0"
        firestoreData["_migrationTimestamp"] = FieldValue.serverTimestamp()
        
        return firestoreData
    }
    
    private func mapXPLedgerDataToFirestore(_ data: [String: Any]) -> [String: Any] {
        var firestoreData: [String: Any] = [:]
        
        if let id = data["id"] as? String { firestoreData["id"] = id }
        if let timestamp = data["timestamp"] as? Date { firestoreData["timestamp"] = timestamp }
        if let action = data["action"] as? String { firestoreData["action"] = action }
        if let habitId = data["habitId"] as? String { firestoreData["habitId"] = habitId }
        if let dateKey = data["dateKey"] as? String { firestoreData["dateKey"] = dateKey }
        if let amount = data["amount"] as? Double { firestoreData["amount"] = amount }
        
        // Add Firestore-specific fields
        firestoreData["_migrated"] = true
        firestoreData["_migrationVersion"] = "1.0.0"
        firestoreData["_migrationTimestamp"] = FieldValue.serverTimestamp()
        
        return firestoreData
    }
    
    private func mapStreakDataToFirestore(_ data: [String: Any]) -> [String: Any] {
        var firestoreData: [String: Any] = [:]
        
        if let habitId = data["habitId"] as? String { firestoreData["habitId"] = habitId }
        if let currentStreak = data["currentStreak"] as? Int { firestoreData["currentStreak"] = currentStreak }
        if let longestStreak = data["longestStreak"] as? Int { firestoreData["longestStreak"] = longestStreak }
        if let lastCompletedDate = data["lastCompletedDate"] as? Date { firestoreData["lastCompletedDate"] = lastCompletedDate }
        if let updatedAt = data["updatedAt"] as? Date { firestoreData["updatedAt"] = updatedAt }
        
        // Add Firestore-specific fields
        firestoreData["_migrated"] = true
        firestoreData["_migrationVersion"] = "1.0.0"
        firestoreData["_migrationTimestamp"] = FieldValue.serverTimestamp()
        
        return firestoreData
    }
    
    private func mapGoalVersionDataToFirestore(_ data: [String: Any]) -> [String: Any] {
        var firestoreData: [String: Any] = [:]
        
        if let habitId = data["habitId"] as? String { firestoreData["habitId"] = habitId }
        if let goal = data["goal"] as? String { firestoreData["goal"] = goal }
        if let effectiveDate = data["effectiveDate"] as? Date { firestoreData["effectiveDate"] = effectiveDate }
        if let createdAt = data["createdAt"] as? Date { firestoreData["createdAt"] = createdAt }
        
        // Add Firestore-specific fields
        firestoreData["_migrated"] = true
        firestoreData["_migrationVersion"] = "1.0.0"
        firestoreData["_migrationTimestamp"] = FieldValue.serverTimestamp()
        
        return firestoreData
    }
    
    private func mapUserSettingsDataToFirestore(_ data: [String: Any]) -> [String: Any] {
        var firestoreData: [String: Any] = [:]
        
        // Map all settings fields
        for (key, value) in data {
            firestoreData[key] = value
        }
        
        // Add Firestore-specific fields
        firestoreData["_migrated"] = true
        firestoreData["_migrationVersion"] = "1.0.0"
        firestoreData["_migrationTimestamp"] = FieldValue.serverTimestamp()
        
        return firestoreData
    }
    
    // MARK: - Helper Methods
    
    private func generateEventId(from stableKey: String) -> String {
        // Create a deterministic event ID from the stable key
        let hash = stableKey.hashValue
        return "event_\(abs(hash))"
    }
    
    private func generateVersionId(for habitId: String, effectiveDate: Date) -> String {
        let dateKey = DateFormatter.dateKeyFormatter.string(from: effectiveDate)
        return "\(habitId)_\(dateKey)"
    }
}

// MARK: - Mapping Errors

enum MappingError: LocalizedError {
    case missingRequiredField(String)
    case invalidDataFormat(String)
    case unsupportedDataType(String)
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidDataFormat(let message):
            return "Invalid data format: \(message)"
        case .unsupportedDataType(let type):
            return "Unsupported data type: \(type)"
        }
    }
}
