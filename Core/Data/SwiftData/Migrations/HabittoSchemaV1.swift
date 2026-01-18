import Foundation
import SwiftData

// MARK: - HabittoSchemaV1

/// Schema Version 1 - Baseline schema representing the current state of all SwiftData models
///
/// **Created:** 2024 (Current baseline)
/// **Purpose:** Establish versioned schema baseline for future migrations
///
/// **Models Included (14 total):**
/// 1. HabitData - Main habit entity
/// 2. CompletionRecord - Daily completion tracking
/// 3. HabitDeletionLog - Audit log for habit deletions
/// 4. DailyAward - Daily XP awards
/// 5. UserProgressData - User XP and leveling
/// 6. AchievementData - Unlocked achievements
/// 7. ProgressEvent - Event-sourced progress changes
/// 8. GlobalStreakModel - Global streak tracking
/// 9. DifficultyRecord - Daily difficulty ratings
/// 10. UsageRecord - Usage history
/// 11. HabitNote - Notes attached to habits
/// 12. StorageHeader - Schema version tracking (app-level)
/// 13. MigrationRecord - Migration history (app-level)
/// 14. MigrationState - Migration status tracking (app-level)
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
      HabitDeletionLog.self,
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
    
    ## Models (14 total)
    
    ### Primary Models
    1. **HabitData** - Main habit entity with relationships
       - Properties: id, userId, name, description, icon, colorData, habitType, schedule, goal, reminder, startDate, endDate, baseline, target, goalHistoryJSON, createdAt, updatedAt, deletedAt, deletionSource
       - Relationships: completionHistory, difficultyHistory, usageHistory, notes (all cascade delete)
       - Soft Delete: deletedAt and deletionSource fields for audit trail
    
    2. **CompletionRecord** - Daily completion tracking
       - Properties: userId, habitId, date, dateKey, isCompleted, progress, createdAt, updatedAt
       - Unique constraint: userIdHabitIdDateKey (composite)
    
    3. **HabitDeletionLog** - Audit log for habit deletions
       - Properties: id, habitId, habitName, userId, deletedAt, source, metadata
       - Purpose: Complete audit trail for investigating data loss
    
    4. **DailyAward** - Daily XP awards
       - Properties: id, userId, dateKey, xpGranted, allHabitsCompleted, createdAt
       - Unique constraint: userIdDateKey
    
    5. **UserProgressData** - User XP and leveling
       - Properties: id, userId (unique), xpTotal, level, xpForCurrentLevel, xpForNextLevel, dailyXP, lastCompletedDate, streakDays, createdAt, updatedAt
       - Relationships: achievements (cascade delete)
    
    6. **AchievementData** - Unlocked achievements
       - Properties: id, userId, title, description, xpReward, isUnlocked, unlockedDate, iconName, category, requirementType, requirementTarget, progress, createdAt, updatedAt
    
    7. **ProgressEvent** - Event-sourced progress changes
       - Properties: id (deterministic string), habitId, dateKey, eventType, progressDelta, createdAt, occurredAt, utcDayStart, utcDayEnd, deviceId, userId, timezoneIdentifier, operationId (unique), synced, lastSyncedAt, syncVersion, isRemote, deletedAt, note, metadata
    
    8. **GlobalStreakModel** - Global streak tracking
       - Properties: id, userId, currentStreak, longestStreak, totalCompleteDays, streakHistory, lastCompleteDate, lastUpdated
    
    ### Supporting Models
    9. **DifficultyRecord** - Daily difficulty ratings
    10. **UsageRecord** - Usage history
    11. **HabitNote** - Notes attached to habits
    
    ### App-Level Migration Tracking
    12. **StorageHeader** - Tracks app-level schema version (separate from SwiftData versioning)
    13. **MigrationRecord** - Logs app-level migrations
    14. **MigrationState** - Tracks per-user migration status
    
    ## Notes
    
    - SimpleHabitData is NOT included (deprecated, not in active schema)
    - StorageHeader/MigrationRecord serve app-level migration tracking (different from SwiftData schema versioning)
    - All relationships use cascade delete for data integrity
    - User isolation via userId field on all models
    """
  }
}

