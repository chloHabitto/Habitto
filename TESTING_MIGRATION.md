# Testing Event-Sourcing Migration

## 🧪 **Migration Test Plan**

This document outlines how to test the Priority 4 migration script that converts `completionHistory` → `ProgressEvent` records.

---

## **Pre-Test Setup**

### **1. Create Test Data (Before Migration)**

1. **Launch the app** (fresh install or clear data)
2. **Create 2-3 test habits**:
   - Habit 1: "Test Habit A" (Formation)
   - Habit 2: "Test Habit B" (Breaking)
   - Habit 3: "Test Habit C" (Formation)

3. **Complete habits on different dates**:
   - **Today**: Complete Habit 1 and Habit 2
   - **Yesterday**: Complete Habit 1 and Habit 3
   - **2 days ago**: Complete Habit 2 only

4. **Verify completionHistory exists**:
   ```swift
   // In Xcode console or debug view
   let habits = HabitRepository.shared.habits
   for habit in habits {
       print("Habit: \(habit.name)")
       print("  completionHistory: \(habit.completionHistory)")
   }
   ```

**Expected**: Each habit should have `completionHistory` entries like:
```
completionHistory: ["2025-01-15": 1, "2025-01-14": 1]
```

---

## **Step 1: Trigger Migration**

### **Option A: Automatic Migration (Recommended)**

Migration runs automatically when:
- User signs in for the first time
- `MigrationRunner.runIfNeeded()` is called

**To trigger manually**:
```swift
// In Xcode console or debug view
Task {
    let userId = await CurrentUser().idOrGuest
    try await MigrationRunner.shared.runIfNeeded(userId: userId)
}
```

### **Option B: Force Migration**

If migration was already completed, force re-run:
```swift
// Temporarily enable force migration flag
// (Check FeatureFlagProvider implementation)
```

---

## **Step 2: Verify Migration Results**

### **Check 1: ProgressEvent Records Created**

```swift
// In Xcode console
let context = SwiftDataContainer.shared.modelContext
let descriptor = FetchDescriptor<ProgressEvent>()
let events = try context.fetch(descriptor)

print("Total ProgressEvents: \(events.count)")

// Group by habit
let eventsByHabit = Dictionary(grouping: events) { $0.habitId }
for (habitId, habitEvents) in eventsByHabit {
    print("Habit \(habitId): \(habitEvents.count) events")
    for event in habitEvents.sorted(by: { $0.dateKey < $1.dateKey }) {
        print("  - \(event.dateKey): progressDelta=\(event.progressDelta), type=\(event.eventType)")
    }
}
```

**Expected Results**:
- ✅ Each `completionHistory` entry with `progress > 0` should have a corresponding `ProgressEvent`
- ✅ Event type should be `.bulkAdjust` (stored as `"BULK_ADJUST"`)
- ✅ `progressDelta` should match the original `completionHistory` value
- ✅ `operationId` should start with `"migration_"` prefix
- ✅ `synced` should be `false` (will sync later)

### **Check 2: Idempotency (Run Migration Twice)**

Run migration again:
```swift
Task {
    let userId = await CurrentUser().idOrGuest
    try await MigrationRunner.shared.runIfNeeded(userId: userId)
}
```

**Expected**: No duplicate events created (migration should detect existing events and skip)

### **Check 3: Event Replay Works**

Verify that progress calculated from events matches `completionHistory`:

```swift
let habit = HabitRepository.shared.habits.first!
let dateKey = "2025-01-15" // Use a date that was completed

// Get progress from events
let modelContext = SwiftDataContainer.shared.modelContext
let result = await ProgressEventService.shared.calculateProgressFromEvents(
    habitId: habit.id,
    dateKey: dateKey,
    goalAmount: 1, // Adjust based on habit goal
    legacyProgress: habit.completionHistory[dateKey],
    modelContext: modelContext
)

print("Event-sourced progress: \(result.progress)")
print("Legacy progress: \(habit.completionHistory[dateKey] ?? 0)")
print("Match: \(result.progress == (habit.completionHistory[dateKey] ?? 0))")
```

**Expected**: Event-sourced progress should match legacy progress

### **Check 4: completionHistory Preserved**

```swift
let habits = HabitRepository.shared.habits
for habit in habits {
    print("Habit: \(habit.name)")
    print("  completionHistory: \(habit.completionHistory)")
    print("  ✅ Preserved: \(!habit.completionHistory.isEmpty)")
}
```

**Expected**: `completionHistory` should still exist (for rollback safety)

---

## **Step 3: Test Edge Cases**

### **Edge Case 1: Habit with Zero Progress**

Create a habit but don't complete it. Migration should skip it (no event created).

### **Edge Case 2: Invalid DateKey Format**

If any `completionHistory` has invalid dateKey format, migration should skip it and log a warning.

### **Edge Case 3: Habit Already Has Events**

If a habit already has `ProgressEvent` records (from user interactions), migration should skip that habit+date combination.

### **Edge Case 4: Multiple Migrations**

Run migration multiple times. Should be idempotent (no duplicates).

---

## **Step 4: Verify Integration**

### **Test Habit Completion After Migration**

1. Complete a habit **after** migration
2. Verify that:
   - New `ProgressEvent` is created (type: `.toggleComplete` or `.increment`)
   - Progress calculated from events includes both migration events and new events
   - `completionHistory` is still updated (for backward compatibility)

### **Test Progress Queries**

```swift
// Test HabitStore.getProgress() uses event replay
let habit = HabitRepository.shared.habits.first!
let date = Date() // Today

let progress = await HabitStore.shared.getProgress(for: habit, date: date)
print("Progress from event replay: \(progress)")
```

**Expected**: Should use events if available, fallback to `completionHistory` if no events

---

## **Console Logs to Watch For**

### **✅ Success Indicators**:
```
MigrationRunner: Migrating completionHistory to ProgressEvent records for user {userId}
MigrationRunner: Migrating {count} completion entries for habit '{name}'
MigrationRunner: Created ProgressEvent for habit '{name}' on {dateKey} with progress {progress}
MigrationRunner: ✅ Migrated {count} completionHistory entries to ProgressEvent records
```

### **⚠️ Warning Indicators**:
```
MigrationRunner: Invalid dateKey format: {dateKey}, skipping
MigrationRunner: Events already exist for habit '{name}' on {dateKey}, skipping
MigrationRunner: Migration event already exists with operationId {id}, skipping
```

### **❌ Error Indicators**:
```
MigrationRunner: Migration failed for user {userId}: {error}
```

---

## **Quick Test Checklist**

- [ ] Migration runs without errors
- [ ] ProgressEvent records created for all non-zero completionHistory entries
- [ ] Event type is `.bulkAdjust`
- [ ] operationId starts with `"migration_"`
- [ ] Events marked as `synced: false`
- [ ] Migration is idempotent (no duplicates on re-run)
- [ ] Event replay calculates correct progress
- [ ] completionHistory preserved for rollback
- [ ] New habit completions create new events (not migration events)
- [ ] Progress queries use event replay when available

---

## **Troubleshooting**

### **Issue: No events created**

**Possible causes**:
1. Migration already completed (check `MigrationState`)
2. No habits with `completionHistory` entries
3. Migration disabled by feature flag

**Solution**:
```swift
// Check migration state
let context = SwiftDataContainer.shared.modelContext
let state = try MigrationState.findOrCreateForUser(userId: userId, in: context)
print("Migration completed: \(state.isCompleted)")
print("Migration version: \(state.migrationVersion)")
```

### **Issue: Duplicate events**

**Possible causes**:
1. Migration ran multiple times without idempotency check
2. operationId not being set correctly

**Solution**: Check if events have correct `operationId` format: `"migration_{habitId}_{dateKey}"`

### **Issue: Progress mismatch**

**Possible causes**:
1. Event `progressDelta` doesn't match `completionHistory` value
2. Multiple events for same habit+date (shouldn't happen with migration)

**Solution**: Verify events are created correctly:
```swift
let events = try context.fetch(ProgressEvent.eventsForHabitDate(habitId: habit.id, dateKey: dateKey))
let totalProgress = events.reduce(0) { $0 + $1.progressDelta }
print("Total from events: \(totalProgress), Expected: \(habit.completionHistory[dateKey] ?? 0)")
```

---

## **Next Steps After Testing**

Once migration is verified working:

1. ✅ **Priority 1**: Event-sourcing integration - COMPLETE
2. ✅ **Priority 2**: XP award system - COMPLETE  
3. ✅ **Priority 4**: Migration script - COMPLETE
4. ⏭️ **Priority 3**: Sync Engine - Ready to implement

The sync engine will upload these migrated events to Firestore for cloud sync.

