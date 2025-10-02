# Entity Relationship Diagram - From Actual Code

## Mermaid ER Diagram

```mermaid
erDiagram
    HabitData {
        UUID id PK "unique"
        String userId "indexed"
        String name
        String habitDescription
        String icon
        Data colorData
        String habitType
        String schedule
        String goal
        String reminder
        Date startDate
        Date endDate
        Bool isCompleted "DENORMALIZED"
        Int streak "DENORMALIZED"
        Date createdAt
        Date updatedAt
    }
    
    SimpleHabitData {
        UUID id PK "unique"
        String name "NO userId"
        String habitDescription
        String icon
        String colorString
        String habitType
        String schedule
        String goal
        String reminder
        Date startDate
        Date endDate
        Bool isCompleted
        Int streak
        Date createdAt
        Date updatedAt
        String completionHistoryJSON
        String difficultyHistoryJSON
        String usageHistoryJSON
    }
    
    DailyAward {
        UUID id PK "unique"
        String userId "indexed"
        String dateKey "indexed"
        Int xpGranted
        Date createdAt
    }
    
    CompletionRecord {
        Date date
        Bool isCompleted
        Date createdAt "NO userId, NO habitId"
    }
    
    DifficultyRecord {
        Date date
        Int difficulty
        Date createdAt "NO userId, NO habitId"
    }
    
    UsageRecord {
        String key
        Int value
        Date createdAt "NO userId, NO habitId"
    }
    
    HabitNote {
        String content
        Date createdAt
        Date updatedAt "NO userId, NO habitId"
    }
    
    StorageHeader {
        Int schemaVersion
        Date lastMigration
        Date createdAt "NO userId"
    }
    
    MigrationRecord {
        Int fromVersion
        Int toVersion
        Date executedAt
        Bool success
        String errorMessage "NO userId"
    }
    
    HabitEntity {
        UUID id "temporary stub"
        String name
        NSSet reminders
        NSSet completionHistory
        Date createdAt
        Date updatedAt
        Date lastCompleted
        Bool isArchived
        String color
        String emoji
        Int32 streak
        String frequency
        Double targetAmount
        String unit
        Int16 difficultyLevel
        String notes
        Bool isActive
        Bool reminderEnabled
        String weekdays
        String scheduleDays
        Date scheduleTime
        String habitType
        String timeOfDay
        String category
        NSSet difficultyLogs
        String colorHex
        String habitDescription
        String icon
        String schedule
        String goal
        String reminder
        Date startDate
        Date endDate
        Bool isCompleted
        Double baseline
        Double target
        NSSet usageRecords "NO userId"
    }
    
    ReminderItemEntity {
        UUID id "temporary stub"
        Date time
        Bool isActive
        String message "NO userId"
    }
    
    CompletionRecordEntity {
        UUID id "temporary stub"
        Date timestamp
        Double progress
        Date date
        String notes
        Bool isCompleted
        String dateKey
        String timeBlock "NO userId"
    }
    
    DifficultyLogEntity {
        UUID id "temporary stub"
        Date timestamp
        Int16 difficultyLevel
        Int16 difficulty
        String context
        String notes "NO userId"
    }
    
    UsageRecordEntity {
        UUID id "temporary stub"
        Date timestamp
        String action
        String dateKey
        Double amount "NO userId"
    }
    
    NoteEntity {
        UUID id "temporary stub"
        String content
        Date timestamp
        String title
        String tags
        Date createdAt
        Date updatedAt "NO userId"
    }
    
    %% Relationships (from code)
    HabitData ||--o{ CompletionRecord : "completionHistory (cascade)"
    HabitData ||--o{ DifficultyRecord : "difficultyHistory (cascade)"
    HabitData ||--o{ UsageRecord : "usageHistory (cascade)"
    HabitData ||--o{ HabitNote : "notes (cascade)"
    
    %% Missing relationships (issues)
    %% DailyAward should relate to HabitData but doesn't
    %% CompletionRecord should have back-reference to HabitData but doesn't
    %% DifficultyRecord should have back-reference to HabitData but doesn't
    %% UsageRecord should have back-reference to HabitData but doesn't
    %% HabitNote should have back-reference to HabitData but doesn't
    
    %% Core Data relationships (temporary stubs)
    HabitEntity ||--o{ ReminderItemEntity : "reminders"
    HabitEntity ||--o{ CompletionRecordEntity : "completionHistory"
    HabitEntity ||--o{ DifficultyLogEntity : "difficultyLogs"
    HabitEntity ||--o{ UsageRecordEntity : "usageRecords"
    HabitEntity ||--o{ NoteEntity : "notes"
```

## Relationship Analysis

### Defined Relationships (Working)
1. **HabitData → CompletionRecord** (1:many, cascade delete)
2. **HabitData → DifficultyRecord** (1:many, cascade delete)  
3. **HabitData → UsageRecord** (1:many, cascade delete)
4. **HabitData → HabitNote** (1:many, cascade delete)

### Missing Relationships (Issues)
1. **DailyAward → HabitData** - No relationship defined
2. **CompletionRecord → HabitData** - No inverse relationship
3. **DifficultyRecord → HabitData** - No inverse relationship
4. **UsageRecord → HabitData** - No inverse relationship
5. **HabitNote → HabitData** - No inverse relationship

### User Scoping Issues
- **DailyAward**: ✅ Has `userId`
- **HabitData**: ✅ Has `userId`
- **All other SwiftData models**: ❌ Missing `userId`
- **All Core Data models**: ❌ Missing `userId`

### Denormalized Fields
- **HabitData.isCompleted**: ⚠️ DENORMALIZED - should be computed from CompletionRecord
- **HabitData.streak**: ⚠️ DENORMALIZED - should be computed from CompletionRecord

### Indexing Issues
- **userId** should be indexed on all models for efficient user-scoped queries
- **dateKey** should be indexed on DailyAward for efficient date-based queries
- **habitId** should be added to CompletionRecord, DifficultyRecord, UsageRecord, HabitNote for efficient habit-based queries

## Critical Problems

1. **No User Isolation**: Most models lack `userId`, allowing data leakage between users
2. **Broken Relationships**: Related models have no back-references, making queries inefficient
3. **Denormalized Data**: `isCompleted` and `streak` can become inconsistent
4. **Missing Foreign Keys**: DailyAward cannot track which habits contributed to XP
5. **Dual Storage**: Both SwiftData and CoreData models exist, creating confusion
