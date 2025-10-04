# Entity Relationship Diagram

This document provides a Mermaid ER diagram showing the relationships between all persisted models in the Habitto codebase.

## ER Diagram

```mermaid
erDiagram
    HabitData {
        UUID id PK
        string userId
        string name
        string habitDescription
        string icon
        Data colorData
        string habitType
        string schedule
        string goal
        string reminder
        Date startDate
        Date endDate
        Date createdAt
        Date updatedAt
    }
    
    CompletionRecord {
        string userId
        UUID habitId
        Date date
        string dateKey
        bool isCompleted
        Date createdAt
        string userIdHabitIdDateKey UK
    }
    
    DailyAward {
        UUID id PK
        string userId
        string dateKey
        int xpGranted
        bool allHabitsCompleted
        Date createdAt
        string userIdDateKey UK
    }
    
    UserProgressData {
        UUID id PK
        string userId UK
        int xpTotal
        int level
        int xpForCurrentLevel
        int xpForNextLevel
        int dailyXP
        Date lastCompletedDate
        int streakDays
        Date createdAt
        Date updatedAt
    }
    
    AchievementData {
        UUID id PK
        string userId
        string title
        string achievementDescription
        int xpReward
        bool isUnlocked
        Date unlockedDate
        string iconName
        string category
        string requirementType
        int requirementTarget
        int progress
        Date createdAt
        Date updatedAt
    }
    
    DifficultyRecord {
        Date date
        int difficulty
        Date createdAt
    }
    
    UsageRecord {
        string key
        int value
        Date createdAt
    }
    
    HabitNote {
        string content
        Date createdAt
        Date updatedAt
    }
    
    StorageHeader {
        int schemaVersion
        Date lastMigration
        Date createdAt
    }
    
    MigrationRecord {
        int fromVersion
        int toVersion
        Date executedAt
        bool success
        string errorMessage
        Date createdAt
        Date updatedAt
    }
    
    MigrationState {
        UUID id PK
        string userId
        int migrationVersion
        string status
        Date startedAt
        Date completedAt
        string errorMessage
        int migratedRecordsCount
        Date createdAt
        Date updatedAt
    }
    
    SimpleHabitData {
        UUID id PK
        string name
        string habitDescription
        string icon
        string colorString
        string habitType
        string schedule
        string goal
        string reminder
        Date startDate
        Date endDate
        bool isCompleted
        int streak
        Date createdAt
        Date updatedAt
        string completionHistoryJSON
        string difficultyHistoryJSON
        string usageHistoryJSON
    }

    %% Primary Relationships
    HabitData ||--o{ CompletionRecord : "has completion history"
    HabitData ||--o{ DifficultyRecord : "has difficulty records"
    HabitData ||--o{ UsageRecord : "has usage records"
    HabitData ||--o{ HabitNote : "has notes"
    
    UserProgressData ||--o{ AchievementData : "has achievements"
    
    %% User Isolation Relationships
    HabitData }o--|| UserProgressData : "user isolation"
    CompletionRecord }o--|| UserProgressData : "user isolation"
    DailyAward }o--|| UserProgressData : "user isolation"
    AchievementData }o--|| UserProgressData : "user isolation"
    MigrationState }o--|| UserProgressData : "user isolation"
    
    %% Business Logic Relationships
    DailyAward }o--|| HabitData : "awards based on completion"
    CompletionRecord }o--|| DailyAward : "triggers daily awards"
```

## Relationship Details

### Primary Relationships (1:N)

1. **HabitData → CompletionRecord** (1:N)
   - **Type:** One-to-Many
   - **Delete Rule:** Cascade
   - **Purpose:** Track daily completion status for each habit
   - **Key:** `HabitData.id` → `CompletionRecord.habitId`

2. **HabitData → DifficultyRecord** (1:N)
   - **Type:** One-to-Many
   - **Delete Rule:** Cascade
   - **Purpose:** Track daily difficulty ratings
   - **Key:** `HabitData.id` → `DifficultyRecord.habitId` (implied)

3. **HabitData → UsageRecord** (1:N)
   - **Type:** One-to-Many
   - **Delete Rule:** Cascade
   - **Purpose:** Track usage metrics for habit breaking
   - **Key:** `HabitData.id` → `UsageRecord.habitId` (implied)

4. **HabitData → HabitNote** (1:N)
   - **Type:** One-to-Many
   - **Delete Rule:** Cascade
   - **Purpose:** Associate notes with habits
   - **Key:** `HabitData.id` → `HabitNote.habitId` (implied)

5. **UserProgressData → AchievementData** (1:N)
   - **Type:** One-to-Many
   - **Delete Rule:** Cascade
   - **Purpose:** Track user achievements and progress
   - **Key:** `UserProgressData.userId` → `AchievementData.userId`

### User Isolation Relationships (1:1)

All models are scoped by `userId` for user data isolation:

6. **UserProgressData** (1:1 per user)
   - **Constraint:** `@Attribute(.unique) var userId: String`
   - **Purpose:** Single progress record per user

### Business Logic Relationships (Implicit)

7. **DailyAward ↔ CompletionRecord** (Implicit)
   - **Purpose:** Daily awards are granted when all habits are completed
   - **Logic:** Service-level relationship, not direct foreign key

8. **DailyAward ↔ UserProgressData** (Implicit)
   - **Purpose:** Daily awards contribute to user XP and level progression
   - **Logic:** Service-level relationship, not direct foreign key

## Key Constraints and Indexes

### Primary Keys
- All models have `id: UUID` with `@Attribute(.unique)`

### Unique Constraints
1. **CompletionRecord.userIdHabitIdDateKey**
   - **Purpose:** Prevent duplicate completions per habit per day
   - **Format:** `"userId#habitId#dateKey"`

2. **DailyAward.userIdDateKey**
   - **Purpose:** Prevent duplicate daily awards per user per day
   - **Format:** `"userId#dateKey"`

3. **UserProgressData.userId**
   - **Purpose:** Ensure one progress record per user
   - **Type:** Single field unique constraint

### Indexing Notes
- SwiftData limitations prevent explicit indexing on `userId` fields
- Composite unique constraints provide implicit indexing
- Date-based queries use `dateKey` strings for performance

## Data Flow Summary

```
User → UserProgressData (1:1)
  ↓
User → HabitData[] (1:N)
  ↓
HabitData → CompletionRecord[] (1:N)
  ↓
CompletionRecord[] → DailyAward (business logic)
  ↓
DailyAward → UserProgressData.xpTotal (service update)
```

## Migration and Legacy Models

- **MigrationState:** Tracks migration status per user
- **MigrationRecord:** Logs migration execution history
- **StorageHeader:** Schema versioning
- **SimpleHabitData:** Legacy storage (deprecated)
- **DifficultyRecord, UsageRecord, HabitNote:** Legacy models with limited functionality