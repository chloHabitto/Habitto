# Persisted Models Inventory

This document provides a comprehensive inventory of all persisted models in the Habitto codebase, with exact file locations, signatures, and attributes.

## SwiftData Models

### 1. HabitData
**File:** `Core/Data/SwiftData/HabitDataModel.swift:7-28`
**Model:** Main habit entity with normalized relationships

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
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var completionHistory: [CompletionRecord]
    @Relationship(deleteRule: .cascade) var difficultyHistory: [DifficultyRecord]
    @Relationship(deleteRule: .cascade) var usageHistory: [UsageRecord]
    @Relationship(deleteRule: .cascade) var notes: [HabitNote]
}
```

**Properties:**
- `id: UUID` - Primary key, unique
- `userId: String` - User isolation key
- `name: String` - Habit name
- `habitDescription: String` - Habit description
- `icon: String` - System icon name
- `colorData: Data` - Serialized Color object
- `habitType: String` - Enum stored as string
- `schedule: String` - Schedule definition
- `goal: String` - Habit goal
- `reminder: String` - Reminder text
- `startDate: Date` - Habit start date
- `endDate: Date?` - Optional end date
- `createdAt: Date` - Creation timestamp
- `updatedAt: Date` - Last update timestamp

**Relationships:**
- `completionHistory: [CompletionRecord]` - 1:N, cascade delete
- `difficultyHistory: [DifficultyRecord]` - 1:N, cascade delete
- `usageHistory: [UsageRecord]` - 1:N, cascade delete
- `notes: [HabitNote]` - 1:N, cascade delete

### 2. CompletionRecord
**File:** `Core/Data/SwiftData/HabitDataModel.swift:195-231`
**Model:** Daily completion tracking with composite unique constraint

```swift
@Model
final class CompletionRecord {
    var userId: String
    var habitId: UUID
    var date: Date
    var dateKey: String  // For date-based queries (indexing not supported in current SwiftData)
    var isCompleted: Bool
    var createdAt: Date
    
    // Composite unique constraint to prevent duplicate completions
    @Attribute(.unique) var userIdHabitIdDateKey: String
}
```

**Properties:**
- `userId: String` - User isolation key
- `habitId: UUID` - Reference to habit
- `date: Date` - Completion date
- `dateKey: String` - ISO8601 date string for indexing
- `isCompleted: Bool` - Completion status
- `createdAt: Date` - Creation timestamp
- `userIdHabitIdDateKey: String` - Composite unique key

**Indexes/Constraints:**
- `@Attribute(.unique)` on `userIdHabitIdDateKey` - Prevents duplicate completions

### 3. DifficultyRecord
**File:** `Core/Data/SwiftData/HabitDataModel.swift:234-259`
**Model:** Daily difficulty tracking (legacy compatibility)

```swift
@Model
final class DifficultyRecord {
    // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
    // @Attribute(.indexed) // Not supported in current SwiftData version var habitId: UUID
    var date: Date
    var difficulty: Int
    var createdAt: Date
}
```

**Properties:**
- `date: Date` - Difficulty assessment date
- `difficulty: Int` - Difficulty level (1-10)
- `createdAt: Date` - Creation timestamp

**Note:** UserId and habitId properties are commented out due to SwiftData limitations

### 4. UsageRecord
**File:** `Core/Data/SwiftData/HabitDataModel.swift:262-287`
**Model:** Usage tracking for habit breaking (legacy compatibility)

```swift
@Model
final class UsageRecord {
    // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
    // @Attribute(.indexed) // Not supported in current SwiftData version var habitId: UUID
    var key: String
    var value: Int
    var createdAt: Date
}
```

**Properties:**
- `key: String` - Usage metric key
- `value: Int` - Usage value
- `createdAt: Date` - Creation timestamp

### 5. HabitNote
**File:** `Core/Data/SwiftData/HabitDataModel.swift:290-315`
**Model:** Notes associated with habits

```swift
@Model
final class HabitNote {
    // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
    // @Attribute(.indexed) // Not supported in current SwiftData version var habitId: UUID
    var content: String
    var createdAt: Date
    var updatedAt: Date
}
```

**Properties:**
- `content: String` - Note content
- `createdAt: Date` - Creation timestamp
- `updatedAt: Date` - Last update timestamp

### 6. StorageHeader
**File:** `Core/Data/SwiftData/HabitDataModel.swift:318-340`
**Model:** Schema versioning and migration tracking

```swift
@Model
final class StorageHeader {
    // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
    var schemaVersion: Int
    var lastMigration: Date
    var createdAt: Date
}
```

**Properties:**
- `schemaVersion: Int` - Current schema version
- `lastMigration: Date` - Last migration timestamp
- `createdAt: Date` - Creation timestamp

### 7. MigrationRecord
**File:** `Core/Data/SwiftData/HabitDataModel.swift:343-372`
**Model:** Migration execution log

```swift
@Model
final class MigrationRecord {
    // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
    var fromVersion: Int
    var toVersion: Int
    var executedAt: Date
    var success: Bool
    var errorMessage: String?
}
```

**Properties:**
- `fromVersion: Int` - Source version
- `toVersion: Int` - Target version
- `executedAt: Date` - Execution timestamp
- `success: Bool` - Migration success status
- `errorMessage: String?` - Error message if failed

### 8. DailyAward
**File:** `Core/Models/DailyAward.swift:5-30`
**Model:** Daily XP awards with composite unique constraint

```swift
@Model
public final class DailyAward: @unchecked Sendable {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var dateKey: String
    public var xpGranted: Int
    public var allHabitsCompleted: Bool
    public var createdAt: Date
    
    // Unique constraint on (userId, dateKey)
    @Attribute(.unique) public var userIdDateKey: String
}
```

**Properties:**
- `id: UUID` - Primary key, unique
- `userId: String` - User isolation key
- `dateKey: String` - ISO8601 date string
- `xpGranted: Int` - XP amount awarded
- `allHabitsCompleted: Bool` - Whether all habits were completed
- `createdAt: Date` - Creation timestamp
- `userIdDateKey: String` - Composite unique key

**Indexes/Constraints:**
- `@Attribute(.unique)` on `id`
- `@Attribute(.unique)` on `userIdDateKey` - Prevents duplicate daily awards

### 9. UserProgressData
**File:** `Core/Models/UserProgressData.swift:7-45`
**Model:** User XP and level progression with achievements

```swift
@Model
final class UserProgressData {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var userId: String  // One UserProgress per user
    var xpTotal: Int
    var level: Int
    var xpForCurrentLevel: Int
    var xpForNextLevel: Int
    var dailyXP: Int
    var lastCompletedDate: Date?
    var streakDays: Int
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var achievements: [AchievementData]
}
```

**Properties:**
- `id: UUID` - Primary key, unique
- `userId: String` - User isolation key, unique (one progress per user)
- `xpTotal: Int` - Total XP earned
- `level: Int` - Current level
- `xpForCurrentLevel: Int` - XP progress in current level
- `xpForNextLevel: Int` - XP needed for next level
- `dailyXP: Int` - Daily XP earned
- `lastCompletedDate: Date?` - Last completion date
- `streakDays: Int` - Current streak
- `createdAt: Date` - Creation timestamp
- `updatedAt: Date` - Last update timestamp

**Relationships:**
- `achievements: [AchievementData]` - 1:N, cascade delete

**Indexes/Constraints:**
- `@Attribute(.unique)` on `id`
- `@Attribute(.unique)` on `userId` - One progress record per user

### 10. AchievementData
**File:** `Core/Models/UserProgressData.swift:100-165`
**Model:** User achievements with progress tracking

```swift
@Model
final class AchievementData {
    @Attribute(.unique) var id: UUID
    var userId: String  // Reference to user (not indexed, use relationship)
    var title: String
    var achievementDescription: String
    var xpReward: Int
    var isUnlocked: Bool
    var unlockedDate: Date?
    var iconName: String
    var category: String  // Store enum as string
    var requirementType: String  // Store enum as string
    var requirementTarget: Int
    var progress: Int
    var createdAt: Date
    var updatedAt: Date
}
```

**Properties:**
- `id: UUID` - Primary key, unique
- `userId: String` - User reference
- `title: String` - Achievement title
- `achievementDescription: String` - Achievement description
- `xpReward: Int` - XP reward amount
- `isUnlocked: Bool` - Unlock status
- `unlockedDate: Date?` - Unlock timestamp
- `iconName: String` - Icon identifier
- `category: String` - Achievement category
- `requirementType: String` - Requirement type enum as string
- `requirementTarget: Int` - Target value
- `progress: Int` - Current progress
- `createdAt: Date` - Creation timestamp
- `updatedAt: Date` - Last update timestamp

**Indexes/Constraints:**
- `@Attribute(.unique)` on `id`

### 11. MigrationState
**File:** `Core/Models/MigrationState.swift:8-35`
**Model:** Migration state tracking per user

```swift
@Model
final class MigrationState {
    @Attribute(.unique) var id: UUID
    var userId: String
    var migrationVersion: Int
    var status: MigrationStatus
    var startedAt: Date
    var completedAt: Date?
    var errorMessage: String?
    var migratedRecordsCount: Int
    var createdAt: Date
    var updatedAt: Date
}
```

**Properties:**
- `id: UUID` - Primary key, unique
- `userId: String` - User isolation key
- `migrationVersion: Int` - Migration version
- `status: MigrationStatus` - Current status enum
- `startedAt: Date` - Start timestamp
- `completedAt: Date?` - Completion timestamp
- `errorMessage: String?` - Error message if failed
- `migratedRecordsCount: Int` - Number of records migrated
- `createdAt: Date` - Creation timestamp
- `updatedAt: Date` - Last update timestamp

**Indexes/Constraints:**
- `@Attribute(.unique)` on `id`

### 12. SimpleHabitData
**File:** `Core/Data/SwiftData/SimpleHabitData.swift:24-44`
**Model:** Legacy simplified habit storage (deprecated)

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

**Properties:**
- `id: UUID` - Primary key, unique
- `name: String` - Habit name
- `habitDescription: String` - Habit description
- `icon: String` - System icon name
- `colorString: String` - Color as hex string
- `habitType: String` - Enum as string
- `schedule: String` - Schedule definition
- `goal: String` - Habit goal
- `reminder: String` - Reminder text
- `startDate: Date` - Start date
- `endDate: Date?` - Optional end date
- `isCompleted: Bool` - Current completion status (denormalized)
- `streak: Int` - Current streak (denormalized)
- `createdAt: Date` - Creation timestamp
- `updatedAt: Date` - Last update timestamp
- `completionHistoryJSON: String` - JSON-encoded completion history
- `difficultyHistoryJSON: String` - JSON-encoded difficulty history
- `usageHistoryJSON: String` - JSON-encoded usage history

**Indexes/Constraints:**
- `@Attribute(.unique)` on `id`

## Schema Registration

**File:** `Core/Data/SwiftData/SwiftDataContainer.swift:18-30`

```swift
let schema = Schema([
    HabitData.self,
    CompletionRecord.self,
    DailyAward.self,          // ✅ PHASE 5: Added DailyAward model
    UserProgressData.self,    // ✅ PHASE 5: Added UserProgressData model
    AchievementData.self,     // ✅ PHASE 5: Added AchievementData model
    DifficultyRecord.self,
    UsageRecord.self,
    HabitNote.self,
    StorageHeader.self,
    MigrationRecord.self,
    MigrationState.self       // ✅ PHASE 5: Added MigrationState model
])
```

## Summary

**Total SwiftData Models:** 12
- **Primary Models:** HabitData, CompletionRecord, DailyAward, UserProgressData, AchievementData
- **Legacy Models:** SimpleHabitData, DifficultyRecord, UsageRecord, HabitNote
- **System Models:** StorageHeader, MigrationRecord, MigrationState

**Key Design Patterns:**
- User isolation via `userId` field on all models
- Composite unique constraints for business logic (e.g., one award per user per day)
- Cascade delete relationships for data integrity
- Computed properties for denormalized fields (streak, isCompleted)
- SwiftData limitations noted for indexing constraints