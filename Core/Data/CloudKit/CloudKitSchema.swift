import Foundation
import CloudKit

// MARK: - CloudKit Schema Definition
/// Defines the CloudKit schema for Habitto app
struct CloudKitSchema {
    
    // MARK: - Record Types
    enum RecordType: String, CaseIterable {
        case habit = "Habit"
        case reminder = "Reminder"
        case analytics = "Analytics"
        case userSettings = "UserSettings"
        case syncMetadata = "SyncMetadata"
    }
    
    // MARK: - Habit Record Schema
    struct HabitRecord {
        static let recordType = "Habit"
        
        // Required fields
        static let id = "id" // String (UUID)
        static let name = "name" // String
        static let description = "description" // String
        static let icon = "icon" // String
        static let colorHex = "colorHex" // String
        static let habitType = "habitType" // String
        static let schedule = "schedule" // String
        static let goal = "goal" // String
        static let reminder = "reminder" // String
        static let startDate = "startDate" // Date
        static let isCompleted = "isCompleted" // Bool
        static let streak = "streak" // Int
        static let createdAt = "createdAt" // Date
        static let lastModified = "lastModified" // Date
        static let isDeleted = "isDeleted" // Bool
        
        // Optional fields
        static let endDate = "endDate" // Date (optional)
        static let baseline = "baseline" // Int
        static let target = "target" // Int
        
        // JSON string fields (for complex data)
        static let completionHistory = "completionHistory" // String (JSON)
        static let difficultyHistory = "difficultyHistory" // String (JSON)
        static let actualUsage = "actualUsage" // String (JSON)
        
        // Indexed fields for queries
        static let indexedFields: [String] = [
            "habitType",
            "createdAt",
            "lastModified",
            "isDeleted"
        ]
    }
    
    // MARK: - Reminder Record Schema
    struct ReminderRecord {
        static let recordType = "Reminder"
        
        // Required fields
        static let id = "id" // String (UUID)
        static let habitId = "habitId" // String (UUID reference)
        static let title = "title" // String
        static let time = "time" // Date
        static let isEnabled = "isEnabled" // Bool
        static let lastModified = "lastModified" // Date
        static let isDeleted = "isDeleted" // Bool
        
        // JSON string fields
        static let repeatDays = "repeatDays" // String (JSON array)
        
        // Indexed fields for queries
        static let indexedFields: [String] = [
            "habitId",
            "isEnabled",
            "lastModified",
            "isDeleted"
        ]
    }
    
    // MARK: - Analytics Record Schema
    struct AnalyticsRecord {
        static let recordType = "Analytics"
        
        // Required fields
        static let id = "id" // String (UUID)
        static let userId = "userId" // String
        static let eventType = "eventType" // String
        static let timestamp = "timestamp" // Date
        static let lastModified = "lastModified" // Date
        static let isDeleted = "isDeleted" // Bool
        
        // Optional fields
        static let sessionId = "sessionId" // String (optional)
        
        // JSON string fields
        static let eventData = "eventData" // String (JSON)
        
        // Indexed fields for queries
        static let indexedFields: [String] = [
            "userId",
            "eventType",
            "timestamp",
            "lastModified",
            "isDeleted"
        ]
    }
    
    // MARK: - User Settings Record Schema
    struct UserSettingsRecord {
        static let recordType = "UserSettings"
        
        // Required fields
        static let id = "id" // String (UUID)
        static let userId = "userId" // String
        static let lastModified = "lastModified" // Date
        static let isDeleted = "isDeleted" // Bool
        
        // JSON string fields
        static let settings = "settings" // String (JSON)
        static let preferences = "preferences" // String (JSON)
        
        // Indexed fields for queries
        static let indexedFields: [String] = [
            "userId",
            "lastModified",
            "isDeleted"
        ]
    }
    
    // MARK: - Sync Metadata Record Schema
    struct SyncMetadataRecord {
        static let recordType = "SyncMetadata"
        
        // Required fields
        static let id = "id" // String (UUID)
        static let userId = "userId" // String
        static let recordTypeField = "recordType" // String
        static let recordId = "recordId" // String
        static let lastSyncDate = "lastSyncDate" // Date
        static let syncStatus = "syncStatus" // String
        static let lastModified = "lastModified" // Date
        static let isDeleted = "isDeleted" // Bool
        
        // Optional fields
        static let conflictResolution = "conflictResolution" // String
        static let version = "version" // Int
        
        // Indexed fields for queries
        static let indexedFields: [String] = [
            "userId",
            "recordType",
            "recordId",
            "lastSyncDate",
            "syncStatus",
            "isDeleted"
        ]
    }
}

// MARK: - CloudKit Schema Validation
extension CloudKitSchema {
    
    /// Validates a CloudKit record against the schema
    static func validateRecord(_ record: CKRecord) -> CloudKitValidationResult {
        guard let recordType = RecordType(rawValue: record.recordType) else {
            return .invalid("Unknown record type: \(record.recordType)")
        }
        
        switch recordType {
        case .habit:
            return validateHabitRecord(record)
        case .reminder:
            return validateReminderRecord(record)
        case .analytics:
            return validateAnalyticsRecord(record)
        case .userSettings:
            return validateUserSettingsRecord(record)
        case .syncMetadata:
            return validateSyncMetadataRecord(record)
        }
    }
    
    private static func validateHabitRecord(_ record: CKRecord) -> CloudKitValidationResult {
        let requiredFields = [
            HabitRecord.id,
            HabitRecord.name,
            HabitRecord.description,
            HabitRecord.icon,
            HabitRecord.colorHex,
            HabitRecord.habitType,
            HabitRecord.schedule,
            HabitRecord.goal,
            HabitRecord.reminder,
            HabitRecord.startDate,
            HabitRecord.isCompleted,
            HabitRecord.streak,
            HabitRecord.createdAt,
            HabitRecord.lastModified,
            HabitRecord.isDeleted
        ]
        
        for field in requiredFields {
            if record[field] == nil {
                return .invalid("Missing required field: \(field)")
            }
        }
        
        // Validate data types
        if let habitType = record[HabitRecord.habitType] as? String,
           !["Habit Building", "Habit Breaking"].contains(habitType) {
            return .invalid("Invalid habit type: \(habitType)")
        }
        
        if let streak = record[HabitRecord.streak] as? Int, streak < 0 {
            return .invalid("Invalid streak value: \(streak)")
        }
        
        return .valid
    }
    
    private static func validateReminderRecord(_ record: CKRecord) -> CloudKitValidationResult {
        let requiredFields = [
            ReminderRecord.id,
            ReminderRecord.habitId,
            ReminderRecord.title,
            ReminderRecord.time,
            ReminderRecord.isEnabled,
            ReminderRecord.lastModified,
            ReminderRecord.isDeleted
        ]
        
        for field in requiredFields {
            if record[field] == nil {
                return .invalid("Missing required field: \(field)")
            }
        }
        
        return .valid
    }
    
    private static func validateAnalyticsRecord(_ record: CKRecord) -> CloudKitValidationResult {
        let requiredFields = [
            AnalyticsRecord.id,
            AnalyticsRecord.userId,
            AnalyticsRecord.eventType,
            AnalyticsRecord.timestamp,
            AnalyticsRecord.lastModified,
            AnalyticsRecord.isDeleted
        ]
        
        for field in requiredFields {
            if record[field] == nil {
                return .invalid("Missing required field: \(field)")
            }
        }
        
        return .valid
    }
    
    private static func validateUserSettingsRecord(_ record: CKRecord) -> CloudKitValidationResult {
        let requiredFields = [
            UserSettingsRecord.id,
            UserSettingsRecord.userId,
            UserSettingsRecord.lastModified,
            UserSettingsRecord.isDeleted
        ]
        
        for field in requiredFields {
            if record[field] == nil {
                return .invalid("Missing required field: \(field)")
            }
        }
        
        return .valid
    }
    
    private static func validateSyncMetadataRecord(_ record: CKRecord) -> CloudKitValidationResult {
        let requiredFields = [
            SyncMetadataRecord.id,
            SyncMetadataRecord.userId,
            SyncMetadataRecord.recordType,
            SyncMetadataRecord.recordId,
            SyncMetadataRecord.lastSyncDate,
            SyncMetadataRecord.syncStatus,
            SyncMetadataRecord.lastModified,
            SyncMetadataRecord.isDeleted
        ]
        
        for field in requiredFields {
            if record[field] == nil {
                return .invalid("Missing required field: \(field)")
            }
        }
        
        return .valid
    }
}


// MARK: - CloudKit Schema Documentation
extension CloudKitSchema {
    
    /// Generates documentation for the CloudKit schema
    static func generateSchemaDocumentation() -> String {
        var documentation = """
        # Habitto CloudKit Schema Documentation
        
        This document describes the CloudKit schema used by the Habitto app for data synchronization.
        
        ## Record Types
        
        """
        
        for recordType in RecordType.allCases {
            documentation += "\n### \(recordType.rawValue)\n\n"
            
            switch recordType {
            case .habit:
                documentation += generateHabitDocumentation()
            case .reminder:
                documentation += generateReminderDocumentation()
            case .analytics:
                documentation += generateAnalyticsDocumentation()
            case .userSettings:
                documentation += generateUserSettingsDocumentation()
            case .syncMetadata:
                documentation += generateSyncMetadataDocumentation()
            }
        }
        
        documentation += """
        
        ## Indexing Strategy
        
        All record types include indexed fields for efficient querying:
        - `lastModified`: For sync operations
        - `isDeleted`: For soft delete filtering
        - Type-specific fields: For common query patterns
        
        ## Data Types
        
        - **String**: Text data, UUIDs, JSON-encoded complex data
        - **Date**: Timestamps and date values
        - **Bool**: Boolean flags
        - **Int**: Numeric values
        - **JSON String**: Complex data structures encoded as JSON strings
        
        ## Sync Strategy
        
        - All records include `lastModified` and `isDeleted` fields
        - Soft deletes are used to maintain data integrity
        - Conflict resolution is based on `lastModified` timestamps
        - Batch operations are used for efficiency
        
        """
        
        return documentation
    }
    
    private static func generateHabitDocumentation() -> String {
        return """
        **Purpose**: Stores habit data for synchronization across devices.
        
        **Key Fields**:
        - `id`: Unique identifier (UUID string)
        - `name`: Habit name
        - `description`: Habit description
        - `icon`: System icon name
        - `colorHex`: Color as hex string
        - `habitType`: "Habit Building" or "Habit Breaking"
        - `schedule`: Schedule string
        - `goal`: Goal description
        - `completionHistory`: JSON string of date -> progress mapping
        - `difficultyHistory`: JSON string of date -> difficulty mapping
        - `actualUsage`: JSON string of date -> usage mapping
        
        **Indexed Fields**: `habitType`, `createdAt`, `lastModified`, `isDeleted`
        
        """
    }
    
    private static func generateReminderDocumentation() -> String {
        return """
        **Purpose**: Stores reminder data linked to habits.
        
        **Key Fields**:
        - `id`: Unique identifier (UUID string)
        - `habitId`: Reference to parent habit
        - `title`: Reminder title
        - `time`: Reminder time
        - `isEnabled`: Whether reminder is active
        - `repeatDays`: JSON array of repeat days (1-7)
        
        **Indexed Fields**: `habitId`, `isEnabled`, `lastModified`, `isDeleted`
        
        """
    }
    
    private static func generateAnalyticsDocumentation() -> String {
        return """
        **Purpose**: Stores analytics data for user behavior tracking.
        
        **Key Fields**:
        - `id`: Unique identifier (UUID string)
        - `userId`: User identifier
        - `eventType`: Type of analytics event
        - `timestamp`: When event occurred
        - `eventData`: JSON string of event metadata
        - `sessionId`: Optional session identifier
        
        **Indexed Fields**: `userId`, `eventType`, `timestamp`, `lastModified`, `isDeleted`
        
        """
    }
    
    private static func generateUserSettingsDocumentation() -> String {
        return """
        **Purpose**: Stores user preferences and settings.
        
        **Key Fields**:
        - `id`: Unique identifier (UUID string)
        - `userId`: User identifier
        - `settings`: JSON string of app settings
        - `preferences`: JSON string of user preferences
        
        **Indexed Fields**: `userId`, `lastModified`, `isDeleted`
        
        """
    }
    
    private static func generateSyncMetadataDocumentation() -> String {
        return """
        **Purpose**: Tracks synchronization metadata for conflict resolution.
        
        **Key Fields**:
        - `id`: Unique identifier (UUID string)
        - `userId`: User identifier
        - `recordType`: Type of record being tracked
        - `recordId`: ID of the tracked record
        - `lastSyncDate`: When record was last synced
        - `syncStatus`: Current sync status
        - `conflictResolution`: How conflicts should be resolved
        - `version`: Record version for conflict detection
        
        **Indexed Fields**: `userId`, `recordType`, `recordId`, `lastSyncDate`, `syncStatus`, `isDeleted`
        
        """
    }
}
