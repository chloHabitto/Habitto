# Schema Change Guidelines

## Overview

This document provides step-by-step guidelines for making safe schema changes to Habitto's SwiftData models. Follow these guidelines to ensure user data safety during app updates.

## 📋 Current Schema Baseline: Version 1.0.0

### Models in V1 (13 total)

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
11. `StorageHeader` - Schema version tracking
12. `MigrationRecord` - Migration history
13. `MigrationState` - Migration status

**Reference:** See `Core/Data/SwiftData/Migrations/HabittoSchemaV1.swift` for complete documentation.

## 🎯 Rules for Safe Schema Changes

### ✅ Safe Changes (Lightweight Migration)

These changes are **automatically handled** by SwiftData:

1. **Adding new optional properties**
   - Example: Adding `var newField: String?` to `HabitData`
   - ✅ Safe - SwiftData handles automatically
   - ✅ No migration code needed

2. **Adding new models**
   - Example: Adding `NewModel.self` to schema
   - ✅ Safe - SwiftData handles automatically
   - ✅ No migration code needed

3. **Changing property from required to optional**
   - Example: `var field: String` → `var field: String?`
   - ✅ Safe - SwiftData handles automatically
   - ⚠️ Requires new schema version

### ⚠️ Dangerous Changes (Custom Migration Required)

These changes **require custom migration code**:

1. **Removing properties**
   - ❌ Dangerous - Data loss risk
   - ✅ Requires custom migration to preserve data

2. **Changing property types**
   - ❌ Dangerous - Data loss risk
   - ✅ Requires custom migration to transform data

3. **Renaming properties**
   - ❌ Dangerous - Data loss risk
   - ✅ Requires custom migration to copy data

4. **Removing models**
   - ❌ Dangerous - Data loss risk
   - ✅ Requires custom migration to delete/archive data

5. **Changing property from optional to required**
   - ❌ Dangerous - Validation failures
   - ✅ Requires custom migration to set default values

## 📝 Step-by-Step: Adding a New Optional Field

### Example: Adding `reminderTime: Date?` to `HabitData`

**Step 1: Update the Model**
```swift
// In Core/Data/SwiftData/HabitDataModel.swift
@Model
final class HabitData {
  // ... existing properties ...
  var reminderTime: Date?  // ✅ NEW: Optional field
}
```

**Step 2: Create New Schema Version**
```swift
// Create Core/Data/SwiftData/Migrations/HabittoSchemaV2.swift
enum HabittoSchemaV2: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(2, 0, 0)
  }
  
  static var models: [any PersistentModel.Type] {
    HabittoSchemaV1.models  // Same models, but HabitData now has reminderTime
  }
}
```

**Step 3: Add Migration Stage**
```swift
// In Core/Data/SwiftData/Migrations/HabittoMigrationPlan.swift
static var schemas: [any VersionedSchema.Type] {
  [
    HabittoSchemaV1.self,
    HabittoSchemaV2.self  // ✅ ADD: New schema version
  ]
}

static var stages: [MigrationStage] {
  [
    .lightweight(fromVersion: HabittoSchemaV1.self, toVersion: HabittoSchemaV2.self)  // ✅ ADD: Lightweight migration
  ]
}
```

**Step 4: Update SwiftDataContainer**
```swift
// In Core/Data/SwiftData/SwiftDataContainer.swift
// No changes needed! Migration plan automatically handles it
```

**Step 5: Test**
- ✅ Test on fresh install (should work)
- ✅ Test on existing database (migration should run automatically)
- ✅ Verify data is preserved
- ✅ Verify new field works correctly

## 📝 Step-by-Step: Adding a New Model

### Example: Adding `UserPreferences` model

**Step 1: Create the Model**
```swift
// Create Core/Models/UserPreferences.swift
@Model
final class UserPreferences {
  @Attribute(.unique) var id: UUID
  var userId: String
  var theme: String
  var notificationsEnabled: Bool
  // ... other properties
}
```

**Step 2: Create New Schema Version**
```swift
// Create Core/Data/SwiftData/Migrations/HabittoSchemaV2.swift
enum HabittoSchemaV2: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(2, 0, 0)
  }
  
  static var models: [any PersistentModel.Type] {
    HabittoSchemaV1.models + [
      UserPreferences.self  // ✅ ADD: New model
    ]
  }
}
```

**Step 3: Add Migration Stage**
```swift
// In HabittoMigrationPlan.swift
static var schemas: [any VersionedSchema.Type] {
  [HabittoSchemaV1.self, HabittoSchemaV2.self]
}

static var stages: [MigrationStage] {
  [
    .lightweight(fromVersion: HabittoSchemaV1.self, toVersion: HabittoSchemaV2.self)
  ]
}
```

**Step 4: Test**
- ✅ Test on fresh install
- ✅ Test on existing database
- ✅ Verify new model can be created
- ✅ Verify existing data unaffected

## 📝 Step-by-Step: Removing a Deprecated Model

### Example: Removing `SimpleHabitData` (when ready)

**Step 1: Create New Schema Version**
```swift
// Create Core/Data/SwiftData/Migrations/HabittoSchemaV2.swift
enum HabittoSchemaV2: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(2, 0, 0)
  }
  
  static var models: [any PersistentModel.Type] {
    // Remove SimpleHabitData
    HabittoSchemaV1.models.filter { $0 != SimpleHabitData.self }
  }
}
```

**Step 2: Add Custom Migration**
```swift
// In HabittoMigrationPlan.swift
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

**Step 3: Test Thoroughly**
- ✅ Test on fresh install (should work)
- ✅ Test on database with SimpleHabitData records (should delete them)
- ✅ Verify no data loss for active models
- ✅ Verify app works correctly after migration

## 🧪 Testing Checklist

Before releasing a schema change:

### Pre-Release Testing

- [ ] **Fresh Install Test**
  - Install app on clean device/simulator
  - Verify new schema works
  - Verify all models can be created

- [ ] **Migration Test**
  - Install app with existing V1 data
  - Update to new version
  - Verify migration runs automatically
  - Verify all data is preserved
  - Verify new features work

- [ ] **Data Integrity Test**
  - Verify all relationships intact
  - Verify no orphaned records
  - Verify unique constraints work
  - Verify cascade deletes work

- [ ] **Performance Test**
  - Verify migration completes quickly (< 5 seconds)
  - Verify app launches normally after migration
  - Verify queries work correctly

- [ ] **Rollback Test** (if possible)
  - Test what happens if migration fails
  - Verify fallback mechanisms work
  - Verify data is not corrupted

### Post-Release Monitoring

- [ ] Monitor crash reports for migration-related issues
- [ ] Monitor analytics for migration success rates
- [ ] Check logs for migration errors
- [ ] Verify user reports (if any)

## 🚨 When to Create a New Schema Version

### Create V2 When:

- ✅ Adding new optional properties
- ✅ Adding new models
- ✅ Removing models (with migration)
- ✅ Changing property types (with migration)
- ✅ Renaming properties (with migration)
- ✅ Changing relationships

### Don't Create V2 When:

- ❌ Bug fixes (unless schema change required)
- ❌ Performance improvements
- ❌ Code refactoring
- ❌ UI changes
- ❌ Business logic changes (unless schema change required)

## 📊 Version Numbering

### Semantic Versioning

- **Major (X.0.0):** Breaking changes, removing models, incompatible changes
- **Minor (0.X.0):** Additive changes, new models, new optional fields
- **Patch (0.0.X):** Bug fixes (rarely used for schema)

### Examples

- `1.0.0` → `2.0.0`: Removing `SimpleHabitData` (breaking)
- `1.0.0` → `1.1.0`: Adding `UserPreferences` model (additive)
- `1.0.0` → `1.0.1`: Fixing migration bug (patch)

## 🔍 Debugging Migrations

### Enable Migration Logging

Migration logs are automatically enabled. Check:
- Xcode Console for migration messages
- Device logs for production issues

### Common Issues

**Issue: Migration doesn't run**
- Check migration plan includes both schemas
- Check migration stage is correct
- Verify ModelContainer uses migration plan

**Issue: Data loss after migration**
- Check custom migration logic
- Verify data transformation is correct
- Test on development database first

**Issue: Migration takes too long**
- Check for large datasets
- Optimize custom migration code
- Consider batching operations

## 📚 Reference

- **Current Schema:** `Core/Data/SwiftData/Migrations/HabittoSchemaV1.swift`
- **Migration Plan:** `Core/Data/SwiftData/Migrations/HabittoMigrationPlan.swift`
- **Migration Guide:** `Core/Data/SwiftData/Migrations/MIGRATION_GUIDE.md`
- **API Documentation:** `Core/Data/SwiftData/Migrations/API_FINDINGS_AND_RECOMMENDATIONS.md`

## ✅ Quick Reference

### Adding Optional Field
1. Add property to model
2. Create V2 schema (include all V1 models)
3. Add lightweight migration stage
4. Test

### Adding New Model
1. Create model class
2. Create V2 schema (include V1 models + new model)
3. Add lightweight migration stage
4. Test

### Removing Model
1. Create V2 schema (exclude removed model)
2. Add custom migration to delete/archive data
3. Test thoroughly
4. Monitor after release

### Changing Property Type
1. Add new property with new type
2. Create V2 schema
3. Add custom migration to copy/transform data
4. Remove old property in V3 (if needed)
5. Test thoroughly

## 🎯 Best Practices

1. **Always test migrations** on development database first
2. **Document all changes** in schema version file
3. **Keep migration code simple** - complex logic is error-prone
4. **Test on real devices** - simulators may behave differently
5. **Monitor after release** - watch for migration issues
6. **Have rollback plan** - know how to revert if needed
7. **Backup before migration** - automatic backups help
8. **Incremental changes** - small changes are safer than large ones

