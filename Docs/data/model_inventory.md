# Persisted Model Inventory - Ground Truth

## SwiftData Models (@Model)

### 1. HabitData
**File**: `Core/Data/SwiftData/HabitDataModel.swift:7`
```swift
@Model
final class HabitData {
    @Attribute(.unique) var id: UUID
    var userId: String // User ID for data isolation
    var name: String
    var habitDescription: String
    var icon: String
    var colorData: Data // Store Color as Data for SwiftData
    var habitType: String // Store enum as String
    var schedule: String
    var goal: String
    var reminder: String
    var startDate: Date
    var endDate: Date?
    // MARK: - Denormalized Fields (Computed from completionHistory)
    var isCompleted: Bool // ⚠️ DENORMALIZED - use isCompleted(for:) for truth
    var streak: Int // ⚠️ DENORMALIZED - use calculateTrueStreak() for truth
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var completionHistory: [CompletionRecord]
    @Relationship(deleteRule: .cascade) var difficultyHistory: [DifficultyRecord]
    @Relationship(deleteRule: .cascade) var usageHistory: [UsageRecord]
    @Relationship(deleteRule: .cascade) var notes: [HabitNote]
}
```

**User Scoping**: ✅ `userId: String` present and indexed
**Issues**: ⚠️ Denormalized fields `isCompleted` and `streak` can become inconsistent

### 2. SimpleHabitData
**File**: `Core/Data/SwiftData/SimpleHabitData.swift:24`
```swift
@Model
final class SimpleHabitData {
    @Attribute(.unique) var id: UUID
    var name: String
    var habitDescription: String
    var icon: String
    var colorString: String // Store color as string
    var habitType: String // Store enum as String
    var schedule: String
    var goal: String
    var reminder: String
    var startDate: Date
    var endDate: Date?
    var isCompleted: Bool
    var streak: Int
    var createdAt: Date
    var updatedAt: Date
    
    // Store completion history as JSON string for simplicity
    var completionHistoryJSON: String
    var difficultyHistoryJSON: String
    var usageHistoryJSON: String
}
```

**User Scoping**: ❌ **MISSING** - No `userId` field
**Issues**: ⚠️ Denormalized fields, no relationships, stores data as JSON strings

### 3. DailyAward
**File**: `Core/Models/DailyAward.swift:5`
```swift
@Model
public class DailyAward {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var dateKey: String
    public var xpGranted: Int
    public var createdAt: Date
}
```

**User Scoping**: ✅ `userId: String` present
**Issues**: ❌ **MISSING** relationship to HabitData - cannot track which habits contributed

### 4. CompletionRecord
**File**: `Core/Data/SwiftData/HabitDataModel.swift:219`
```swift
@Model
final class CompletionRecord {
    var date: Date
    var isCompleted: Bool
    var createdAt: Date
}
```

**User Scoping**: ❌ **MISSING** - No `userId` field
**Issues**: No relationship back to HabitData defined

### 5. DifficultyRecord
**File**: `Core/Data/SwiftData/HabitDataModel.swift:233`
```swift
@Model
final class DifficultyRecord {
    var date: Date
    var difficulty: Int
    var createdAt: Date
}
```

**User Scoping**: ❌ **MISSING** - No `userId` field
**Issues**: No relationship back to HabitData defined

### 6. UsageRecord
**File**: `Core/Data/SwiftData/HabitDataModel.swift:247`
```swift
@Model
final class UsageRecord {
    var key: String
    var value: Int
    var createdAt: Date
}
```

**User Scoping**: ❌ **MISSING** - No `userId` field
**Issues**: No relationship back to HabitData defined

### 7. HabitNote
**File**: `Core/Data/SwiftData/HabitDataModel.swift:261`
```swift
@Model
final class HabitNote {
    var content: String
    var createdAt: Date
    var updatedAt: Date
}
```

**User Scoping**: ❌ **MISSING** - No `userId` field
**Issues**: No relationship back to HabitData defined

### 8. StorageHeader
**File**: `Core/Data/SwiftData/HabitDataModel.swift:275`
```swift
@Model
final class StorageHeader {
    var schemaVersion: Int
    var lastMigration: Date
    var createdAt: Date
}
```

**User Scoping**: ❌ **MISSING** - No `userId` field
**Issues**: Schema versioning not user-scoped

### 9. MigrationRecord
**File**: `Core/Data/SwiftData/HabitDataModel.swift:289`
```swift
@Model
final class MigrationRecord {
    var fromVersion: Int
    var toVersion: Int
    var executedAt: Date
    var success: Bool
    var errorMessage: String?
}
```

**User Scoping**: ❌ **MISSING** - No `userId` field
**Issues**: Migration tracking not user-scoped

## Core Data Models (NSManagedObject) - TEMPORARY STUBS

### 1. HabitEntity
**File**: `Core/Data/HabitRepository.swift:13`
```swift
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
}
```

**User Scoping**: ❌ **MISSING** - No `userId` field
**Issues**: Temporary stub, not actively used

### 2. ReminderItemEntity
**File**: `Core/Data/HabitRepository.swift:57`
```swift
class ReminderItemEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var time: Date?
    @NSManaged var isActive: Bool
    @NSManaged var message: String?
    @NSManaged var habit: HabitEntity?
}
```

**User Scoping**: ❌ **MISSING** - No `userId` field
**Issues**: Temporary stub, not actively used

### 3. CompletionRecordEntity
**File**: `Core/Data/HabitRepository.swift:65`
```swift
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
```

**User Scoping**: ❌ **MISSING** - No `userId` field
**Issues**: Temporary stub, not actively used

### 4. DifficultyLogEntity
**File**: `Core/Data/HabitRepository.swift:77`
```swift
class DifficultyLogEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var timestamp: Date?
    @NSManaged var difficultyLevel: Int16
    @NSManaged var difficulty: Int16  // Legacy property
    @NSManaged var context: String?
    @NSManaged var habit: HabitEntity?
    @NSManaged var notes: String?
}
```

**User Scoping**: ❌ **MISSING** - No `userId` field
**Issues**: Temporary stub, not actively used

### 5. UsageRecordEntity
**File**: `Core/Data/HabitRepository.swift:91`
```swift
class UsageRecordEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var timestamp: Date?
    @NSManaged var action: String?
    @NSManaged var habit: HabitEntity?
    @NSManaged var dateKey: String?
    @NSManaged var amount: Double
}
```

**User Scoping**: ❌ **MISSING** - No `userId` field
**Issues**: Temporary stub, not actively used

### 6. NoteEntity
**File**: `Core/Data/HabitRepository.swift:100`
```swift
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
```

**User Scoping**: ❌ **MISSING** - No `userId` field
**Issues**: Temporary stub, not actively used

## Model Inventory Summary

| Model | Type | User Scoping | Relationships | Issues |
|-------|------|--------------|---------------|---------|
| HabitData | SwiftData | ✅ | ✅ | ⚠️ Denormalized fields |
| SimpleHabitData | SwiftData | ❌ | ❌ | Multiple issues |
| DailyAward | SwiftData | ✅ | ❌ | Missing relationship to habits |
| CompletionRecord | SwiftData | ❌ | ❌ | Missing user scoping |
| DifficultyRecord | SwiftData | ❌ | ❌ | Missing user scoping |
| UsageRecord | SwiftData | ❌ | ❌ | Missing user scoping |
| HabitNote | SwiftData | ❌ | ❌ | Missing user scoping |
| StorageHeader | SwiftData | ❌ | ❌ | Missing user scoping |
| MigrationRecord | SwiftData | ❌ | ❌ | Missing user scoping |
| HabitEntity | CoreData | ❌ | ✅ | Temporary stub |
| ReminderItemEntity | CoreData | ❌ | ✅ | Temporary stub |
| CompletionRecordEntity | CoreData | ❌ | ✅ | Temporary stub |
| DifficultyLogEntity | CoreData | ❌ | ✅ | Temporary stub |
| UsageRecordEntity | CoreData | ❌ | ✅ | Temporary stub |
| NoteEntity | CoreData | ❌ | ✅ | Temporary stub |

## Critical Issues Found

1. **Missing User Scoping**: 8 out of 9 SwiftData models lack `userId` field
2. **Denormalized Fields**: `isCompleted` and `streak` in HabitData can become inconsistent
3. **Missing Relationships**: DailyAward has no relationship to HabitData
4. **Dual Storage**: Both SwiftData and CoreData models exist (CoreData are temporary stubs)
5. **Incomplete Relationships**: CompletionRecord, DifficultyRecord, UsageRecord, HabitNote lack back-references to HabitData

## Recommendations

1. **Add userId to all models** for proper user isolation
2. **Remove denormalized fields** or implement automatic sync
3. **Add relationships** between DailyAward and HabitData
4. **Complete migration** from CoreData stubs to SwiftData only
5. **Fix relationship definitions** with proper inverse relationships
