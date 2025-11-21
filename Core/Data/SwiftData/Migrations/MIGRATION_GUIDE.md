# SwiftData Migration Guide

## Overview

This document explains the SwiftData migration system implemented for Habitto. The migration infrastructure ensures user data safety through future schema changes.

## Architecture

### Two-Tier Migration System

Habitto uses **two separate but complementary migration systems**:

1. **SwiftData Schema Migrations** (NEW)
   - Handles database structure changes (adding/removing models, changing properties)
   - Uses `SchemaMigrationPlan` and `VersionedSchema`
   - Managed by SwiftData framework automatically
   - **File:** `HabittoMigrationPlan.swift`, `HabittoSchemaV1.swift`

2. **App-Level Data Migrations** (EXISTING)
   - Handles data format changes, business logic migrations
   - Uses `StorageHeader`, `MigrationRecord`, `MigrationState`
   - Managed manually by app code
   - **Files:** Various migration services

**Why Both?**
- SwiftData migrations handle **schema structure** (database tables, columns)
- App-level migrations handle **data transformation** (converting old data formats to new ones)
- They work together but serve different purposes

## Current State: Version 1.0.0

### Schema V1 Models (13 total)

**Primary Models:**
1. `HabitData` - Main habit entity
2. `CompletionRecord` - Daily completion tracking
3. `DailyAward` - Daily XP awards
4. `UserProgressData` - User XP and leveling
5. `AchievementData` - Unlocked achievements
6. `ProgressEvent` - Event-sourced progress changes
7. `GlobalStreakModel` - Global streak tracking

**Supporting Models:**
8. `DifficultyRecord` - Daily difficulty ratings
9. `UsageRecord` - Usage history
10. `HabitNote` - Notes attached to habits

**App-Level Migration Tracking:**
11. `StorageHeader` - Tracks app-level schema version
12. `MigrationRecord` - Logs app-level migrations
13. `MigrationState` - Tracks per-user migration status

**Note:** `SimpleHabitData` is **NOT** in V1 schema (deprecated, not in active use)

## StorageHeader/MigrationRecord System

### Current Status: KEPT

**Decision:** Keep both systems running in parallel.

**Reasoning:**
- `StorageHeader`/`MigrationRecord` track **app-level data migrations** (e.g., converting UserDefaults data to SwiftData)
- SwiftData migrations track **database schema changes** (e.g., adding a new field)
- They serve different purposes and complement each other

**Example:**
- **SwiftData Migration:** Adding a new optional field to `HabitData` → handled by SwiftData automatically
- **App-Level Migration:** Converting legacy JSON data to SwiftData models → handled by `MigrationService`

### Future Strategy

1. **Keep StorageHeader** for app-level version tracking
2. **Use SwiftData migrations** for schema structure changes
3. **Document** which system handles which type of change

## Migration Types

### Lightweight Migrations (Automatic)

SwiftData can automatically handle:
- Adding new optional properties
- Adding new models
- Removing models (with custom migration)
- Changing property types (with custom migration)

**Example:**
```swift
// Adding a new optional field
enum HabittoSchemaV2: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(2, 0, 0)
  }
  
  static var models: [any PersistentModel.Type] {
    HabittoSchemaV1.models  // Same models, but HabitData now has new optional field
  }
}

// In HabittoMigrationPlan:
static var stages: [MigrationStage] {
  [
    .lightweight(fromVersion: HabittoSchemaV1.self, toVersion: HabittoSchemaV2.self)
  ]
}
```

### Custom Migrations (Manual)

Required for:
- Renaming properties
- Changing property types
- Removing properties
- Data transformation
- Removing deprecated models

**Example:**
```swift
static var stages: [MigrationStage] {
  [
    .custom(
      fromVersion: HabittoSchemaV1.self,
      toVersion: HabittoSchemaV2.self,
      willMigrate: { context in
        // Custom migration logic
        let descriptor = FetchDescriptor<HabitData>()
        let habits = try context.fetch(descriptor)
        
        for habit in habits {
          // Transform data
          habit.newField = transformOldField(habit.oldField)
        }
        
        try context.save()
      }
    )
  ]
}
```

## Removing SimpleHabitData

### Strategy

`SimpleHabitData` is deprecated but **not currently in the active schema**. When we're ready to remove it completely:

1. **Create V2 Schema** without `SimpleHabitData`
2. **Add Custom Migration** to delete any remaining `SimpleHabitData` records
3. **Update Migration Plan** with the migration stage

**Example Implementation:**

```swift
// HabittoSchemaV2.swift
enum HabittoSchemaV2: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(2, 0, 0)
  }
  
  static var models: [any PersistentModel.Type] {
    // Explicitly exclude SimpleHabitData
    HabittoSchemaV1.models.filter { $0 != SimpleHabitData.self }
  }
}

// HabittoMigrationPlan.swift
static var stages: [MigrationStage] {
  [
    .custom(
      fromVersion: HabittoSchemaV1.self,
      toVersion: HabittoSchemaV2.self,
      willMigrate: { context in
        // Delete all SimpleHabitData records
        let descriptor = FetchDescriptor<SimpleHabitData>()
        let legacyHabits = try context.fetch(descriptor)
        
        logger.info("🗑️ Removing \(legacyHabits.count) SimpleHabitData records")
        
        for legacyHabit in legacyHabits {
          context.delete(legacyHabit)
        }
        
        try context.save()
        logger.info("✅ SimpleHabitData cleanup complete")
      }
    )
  ]
}
```

## Migration Testing

### Test File: `Tests/Migration/SchemaMigrationTests.swift`

**Coverage:**
- ✅ Schema version verification
- ✅ Migration plan configuration
- ✅ Container initialization
- ✅ Model fetching (all 13 models)
- ✅ Model creation and persistence

**Run Tests:**
```bash
# Run all migration tests
xcodebuild test -scheme Habitto -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:HabittoTests/SchemaMigrationTests
```

## Best Practices

### When to Create a New Schema Version

Create a new version when:
- ✅ Adding/removing models
- ✅ Adding/removing properties
- ✅ Changing property types
- ✅ Renaming properties
- ✅ Changing relationships

**Do NOT** create a new version for:
- ❌ Bug fixes (unless they require schema changes)
- ❌ Performance improvements
- ❌ Code refactoring

### Migration Checklist

Before deploying a schema change:

1. ✅ Create new schema version file (`HabittoSchemaV2.swift`)
2. ✅ Add migration stage to `HabittoMigrationPlan`
3. ✅ Test migration on development database
4. ✅ Test fresh install (no migration needed)
5. ✅ Test upgrade path (migration needed)
6. ✅ Update documentation
7. ✅ Test rollback strategy (if applicable)

### Version Numbering

- **Major:** Breaking changes (removing models, incompatible changes)
- **Minor:** Additive changes (new models, new optional fields)
- **Patch:** Bug fixes (rarely used for schema)

**Example:**
- `1.0.0` → `2.0.0`: Removing `SimpleHabitData` (breaking)
- `1.0.0` → `1.1.0`: Adding new `UserPreferences` model (additive)
- `1.0.0` → `1.0.1`: Fixing migration bug (patch)

## Troubleshooting

### Migration Fails

1. **Check logs** for specific error
2. **Verify migration plan** includes correct stages
3. **Test on fresh database** (should work)
4. **Test on existing database** (may need custom migration)

### Data Loss Concerns

1. **Always backup** before migration
2. **Test migration** on development database first
3. **Use custom migrations** for data transformation
4. **Keep fallback** to UserDefaults if migration fails

### Performance Issues

1. **Lightweight migrations** are fast (automatic)
2. **Custom migrations** may be slow (depends on data volume)
3. **Consider batching** large data transformations
4. **Show progress** to user for long migrations

## Future Considerations

### Planned Migrations

- **V2:** Remove `SimpleHabitData` (when ready)
- **V3:** Add typed `Schedule` enum (if needed)
- **V4:** Add user preferences model (if needed)

### Migration Strategy for Each

Document each planned migration in this guide before implementation.

## References

- [SwiftData Migration Documentation](https://developer.apple.com/documentation/swiftdata/migrating-your-data-model-to-a-new-schema)
- [SchemaMigrationPlan API](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)
- [VersionedSchema API](https://developer.apple.com/documentation/swiftdata/versionedschema)

