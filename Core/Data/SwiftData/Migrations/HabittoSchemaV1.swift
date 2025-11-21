import Foundation
import SwiftData

// MARK: - HabittoSchemaV1

/// Schema Version 1 - Baseline schema representing the current state of all SwiftData models
///
/// **Created:** 2024 (Current baseline)
/// **Purpose:** Establish versioned schema baseline for future migrations
///
/// **Models Included (13 total):**
/// 1. HabitData - Main habit entity
/// 2. CompletionRecord - Daily completion tracking
/// 3. DailyAward - Daily XP awards
/// 4. UserProgressData - User XP and leveling
/// 5. AchievementData - Unlocked achievements
/// 6. ProgressEvent - Event-sourced progress changes
/// 7. GlobalStreakModel - Global streak tracking
/// 8. DifficultyRecord - Daily difficulty ratings
/// 9. UsageRecord - Usage history
/// 10. HabitNote - Notes attached to habits
/// 11. StorageHeader - Schema version tracking (app-level)
/// 12. MigrationRecord - Migration history (app-level)
/// 13. MigrationState - Migration status tracking (app-level)
///
/// **Note:** SimpleHabitData is NOT included in V1 as it's deprecated and not in active schema
///
/// **Migration Strategy:**
/// - This is the baseline schema (no migrations from previous version)
/// - Future schema changes will create V2, V3, etc. with migration stages
/// - StorageHeader/MigrationRecord remain for app-level migration tracking
///   (separate from SwiftData schema versioning)
enum HabittoSchemaV1: VersionedSchema {
  // MARK: - VersionedSchema Conformance
  
  static var versionIdentifier: Schema.Version {
    Schema.Version(1, 0, 0)
  }
  
  static var models: [any PersistentModel.Type] {
    [
      // Primary Models
      HabitData.self,
      CompletionRecord.self,
      DailyAward.self,
      UserProgressData.self,
      AchievementData.self,
      ProgressEvent.self,
      GlobalStreakModel.self,
      
      // Supporting Models
      DifficultyRecord.self,
      UsageRecord.self,
      HabitNote.self,
      
      // App-Level Migration Tracking (kept separate from SwiftData versioning)
      StorageHeader.self,
      MigrationRecord.self,
      MigrationState.self
    ]
  }
  
  // MARK: - Schema Definition
  
  static var schema: Schema {
    Schema(versionedSchema: HabittoSchemaV1.self)
  }
}

// MARK: - Schema Documentation

extension HabittoSchemaV1 {
  /// Get detailed information about this schema version
  static var documentation: String {
    """
    # Habitto Schema Version 1
    
    **Version:** 1.0.0
    **Created:** 2024
    **Status:** Baseline (Current Production)
    
    ## Models (13 total)
    
    ### Primary Models
    1. **HabitData** - Main habit entity with relationships
       - Properties: id, userId, name, description, icon, colorData, habitType, schedule, goal, reminder, startDate, endDate, baseline, target, goalHistoryJSON, createdAt, updatedAt
       - Relationships: completionHistory, difficultyHistory, usageHistory, notes (all cascade delete)
    
    2. **CompletionRecord** - Daily completion tracking
       - Properties: userId, habitId, date, dateKey, isCompleted, progress, createdAt, updatedAt
       - Unique constraint: userIdHabitIdDateKey (composite)
    
    3. **DailyAward** - Daily XP awards
       - Properties: id, userId, dateKey, xpGranted, allHabitsCompleted, createdAt
       - Unique constraint: userIdDateKey
    
    4. **UserProgressData** - User XP and leveling
       - Properties: id, userId (unique), xpTotal, level, xpForCurrentLevel, xpForNextLevel, dailyXP, lastCompletedDate, streakDays, createdAt, updatedAt
       - Relationships: achievements (cascade delete)
    
    5. **AchievementData** - Unlocked achievements
       - Properties: id, userId, title, description, xpReward, isUnlocked, unlockedDate, iconName, category, requirementType, requirementTarget, progress, createdAt, updatedAt
    
    6. **ProgressEvent** - Event-sourced progress changes
       - Properties: id (deterministic string), habitId, dateKey, eventType, progressDelta, createdAt, occurredAt, utcDayStart, utcDayEnd, deviceId, userId, timezoneIdentifier, operationId (unique), synced, lastSyncedAt, syncVersion, isRemote, deletedAt, note, metadata
    
    7. **GlobalStreakModel** - Global streak tracking
       - Properties: id, userId, currentStreak, longestStreak, totalCompleteDays, streakHistory, lastCompleteDate, lastUpdated
    
    ### Supporting Models
    8. **DifficultyRecord** - Daily difficulty ratings
    9. **UsageRecord** - Usage history
    10. **HabitNote** - Notes attached to habits
    
    ### App-Level Migration Tracking
    11. **StorageHeader** - Tracks app-level schema version (separate from SwiftData versioning)
    12. **MigrationRecord** - Logs app-level migrations
    13. **MigrationState** - Tracks per-user migration status
    
    ## Notes
    
    - SimpleHabitData is NOT included (deprecated, not in active schema)
    - StorageHeader/MigrationRecord serve app-level migration tracking (different from SwiftData schema versioning)
    - All relationships use cascade delete for data integrity
    - User isolation via userId field on all models
    """
  }
}

