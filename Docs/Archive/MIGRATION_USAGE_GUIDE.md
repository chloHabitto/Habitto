# Migration Usage Guide

Complete guide for using the new data migration system.

---

## 📋 Overview

The migration system safely converts old data (UserDefaults-based `Habit` structs) to the new SwiftData models (`HabitModel`, `DailyProgressModel`, `GlobalStreakModel`, `UserProgressModel`).

**Key Features:**
- ✅ **Safe**: Never modifies old data (read-only)
- ✅ **Reversible**: Full rollback capability
- ✅ **Testable**: Dry-run mode for validation
- ✅ **Idempotent**: Can safely run multiple times
- ✅ **Progress Reporting**: Real-time status updates

---

## 🚀 Quick Start

### 1. Test Migration (Dry Run)

```swift
import SwiftData

// Create ModelContext
let container = try ModelContainer(for: HabitModel.self, DailyProgressModel.self, ...)
let context = ModelContext(container)

// Get current user
let userId = AuthenticationManager.shared.currentUser?.id ?? ""

// Create migration manager
let manager = MigrationManager(modelContext: context, userId: userId)

// Test migration (doesn't save data)
let summary = try await manager.migrate(dryRun: true)

print(summary)
```

**Expected Output:**
```
═══════════════════════════════════════════════════════════
📊 MIGRATION SUMMARY
═══════════════════════════════════════════════════════════

Status: ✅ SUCCESS
Mode: 🧪 DRY RUN
Duration: 0.45s

───────────────────────────────────────────────────────────
📦 DATA MIGRATED
───────────────────────────────────────────────────────────

Habits: 10
Progress Records: 150
XP Transactions: 45

───────────────────────────────────────────────────────────
✓ VALIDATION
───────────────────────────────────────────────────────────

Status: ✅ PASSED
Data Counts: ✅ All matched
Streak: ✅ Valid
Checks: ✅ All passed
```

### 2. Actual Migration

```swift
// Once dry run succeeds, run actual migration
let summary = try await manager.migrate(dryRun: false)

if summary.success {
    print("✅ Migration complete!")
} else {
    print("❌ Migration failed: \(summary.error?.localizedDescription ?? "Unknown")")
}
```

### 3. Rollback (If Needed)

```swift
// If something goes wrong, rollback to old data
try await manager.rollback()
print("🔄 Rolled back to old data")
```

---

## 🧪 Testing with Sample Data

### Generate Test Data

```swift
// Generate realistic test data
SampleDataGenerator.generateTestData(userId: "test_user")

// Test migration
let manager = MigrationManager(modelContext: context, userId: "test_user")
let summary = try await manager.migrate(dryRun: true)

// Clean up
SampleDataGenerator.clearTestData(userId: "test_user")
```

### Sample Data Includes:

1. **Simple formation habit** (daily)
2. **Breaking habit** (daily)
3. **Frequency-based schedule** (3 days a week)
4. **Specific weekdays** (Monday, Wednesday, Friday)
5. **Every N days** (every 3 days)
6. **Frequency monthly** (5 days a month)
7. **No completions** (edge case)
8. **Very old data** (1 year ago)
9. **Different units** (minutes, steps)

---

## 📊 Progress Reporting

### Implement Progress Delegate

```swift
class MigrationViewController: UIViewController, MigrationProgressDelegate {
    
    func migrationProgress(step: String, current: Int, total: Int) {
        // Update progress bar
        progressBar.progress = Float(current) / Float(total)
        statusLabel.text = step
    }
    
    func migrationError(error: Error) {
        // Show error alert
        showAlert(title: "Migration Failed", message: error.localizedDescription)
    }
    
    func migrationComplete(summary: MigrationSummary) {
        // Show success message
        showAlert(title: "Success!", message: "Migration completed successfully")
    }
}

// Use delegate
let manager = MigrationManager(modelContext: context, userId: userId)
manager.progressDelegate = self
try await manager.migrate(dryRun: false)
```

---

## 🔍 Validation

The validator checks:

### Data Counts
- ✅ Habit count matches (old vs new)
- ✅ Progress record count matches
- ✅ XP totals match

### Data Integrity
- ✅ No orphaned progress records
- ✅ No invalid dates
- ✅ All relationships properly set
- ✅ All schedules parseable

### Streak Logic
- ✅ Current streak ≤ Longest streak
- ✅ Longest streak ≤ Total complete days
- ✅ Dates are reasonable

### Example Validation Output

```swift
let validator = MigrationValidator(modelContext: context, userId: userId)
let result = try await validator.validate()

if result.isValid {
    print("✅ Validation passed")
} else {
    print("❌ Validation failed:")
    for error in result.errors {
        print("  - \(error)")
    }
}
```

---

## 🎯 Production Migration Flow

### Phase 1: TestFlight (Beta Users)

```swift
// In app startup
if FeatureFlags.shared.useNewDataModel && !isMigrationComplete() {
    showMigrationUI()
    
    let manager = MigrationManager(modelContext: context, userId: userId)
    manager.progressDelegate = self
    
    do {
        let summary = try await manager.migrate(dryRun: false)
        
        if summary.success {
            showSuccessMessage()
        } else {
            showErrorAndRollback()
        }
    } catch {
        print("Migration failed: \(error)")
        try await manager.rollback()
    }
}

func isMigrationComplete() -> Bool {
    return UserDefaults.standard.bool(forKey: "migration_completed_\(userId)")
}
```

### Phase 2: Production (Gradual Rollout)

```swift
// Check if user is in rollout group
if FeatureFlags.shared.shouldUseNewDataModel {
    // User is in rollout group
    if !isMigrationComplete() {
        // Run migration
        runMigration()
    } else {
        // Use new system
        useNewDataSystem()
    }
} else {
    // User not in rollout group - use old system
    useOldDataSystem()
}
```

---

## ⚠️ Common Issues & Solutions

### Issue 1: "Migration has already been completed"

**Cause:** Migration was already run for this user.

**Solution:**
```swift
// Reset migration flag if you need to re-migrate
UserDefaults.standard.removeObject(forKey: "migration_completed_\(userId)")

// Then rollback
try await manager.rollback()

// Then re-migrate
try await manager.migrate(dryRun: false)
```

### Issue 2: Validation fails with "Habit count mismatch"

**Cause:** Some habits failed to migrate due to parsing errors.

**Solution:**
1. Check logs for parsing errors
2. Fix invalid data in old system
3. Re-run migration

### Issue 3: "No old data found to migrate"

**Cause:** Old habits not found in UserDefaults.

**Solution:**
```swift
// Check if old data exists
let oldHabits = Habit.loadHabits()
print("Old habits count: \(oldHabits.count)")

// If 0, user has no data to migrate
```

### Issue 4: Schedule parsing fails

**Cause:** Unrecognized schedule string format.

**Solution:**
1. Check which schedule string failed (look for ⚠️ in logs)
2. Add support for that format in `Schedule.fromLegacyString()`
3. Re-run migration

---

## 🧹 Post-Migration Cleanup

### After 90 Days in Production

Once migration is stable and all users migrated:

```swift
// 1. Remove old models
// Delete: Core/Models/Habit.swift

// 2. Remove dual-write wrapper
// Delete: DualWriteProgressService.swift

// 3. Remove feature flag
// Delete: FeatureFlags.shared.useNewDataModel

// 4. Remove migration code (optional - keep for reference)
// Archive: Core/Migration/
```

---

## 📝 Migration Checklist

### Pre-Migration
- [ ] Backup user data
- [ ] Test with sample data
- [ ] Dry run succeeds
- [ ] Validation passes

### During Migration
- [ ] Monitor progress
- [ ] Check for errors
- [ ] Verify validation passes

### Post-Migration
- [ ] Verify data in new system
- [ ] Test app functionality
- [ ] Monitor crash reports
- [ ] Check user feedback

### If Issues Arise
- [ ] Rollback immediately
- [ ] Investigate errors
- [ ] Fix issues
- [ ] Re-test with sample data
- [ ] Try migration again

---

## 🔗 Related Documentation

- [New Data Architecture Design](NEW_DATA_ARCHITECTURE_DESIGN.md)
- [Migration Mapping](MIGRATION_MAPPING.md)
- [Phase 2 Service Layer](PHASE2_SERVICE_LAYER.md) *(coming soon)*

---

## 💡 Tips

1. **Always test with dry run first**
2. **Monitor logs during migration**
3. **Keep rollback capability**
4. **Don't delete old code until fully migrated**
5. **Gradual rollout in production**
6. **Have a rollback plan**
7. **Test with real user data shapes**
8. **Monitor performance with large datasets**

---

## 🆘 Support

If migration fails:
1. Check logs for specific errors
2. Run validator to see what failed
3. Try rollback and re-migrate
4. Generate test data to reproduce issue
5. Check existing migration tests
6. File bug report with migration summary

---

**Last Updated:** Phase 2A Complete  
**Status:** ✅ Ready for Testing

