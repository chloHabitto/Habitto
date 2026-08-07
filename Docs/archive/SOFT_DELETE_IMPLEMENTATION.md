# Soft Delete System Implementation

**Date:** 2025  
**Status:** ✅ Implemented  
**Purpose:** Prevent accidental data loss with comprehensive audit logging

---

## Overview

Habits are now **soft-deleted** instead of permanently removed. This provides:
- Complete audit trail of all deletions
- Ability to investigate missing habits
- Protection against accidental data loss
- Sync conflict detection and logging

---

## Implementation Changes

### 1. Model Changes

#### HabitData Model (HabitDataModel.swift)

**New Fields:**
```swift
/// When the habit was soft-deleted (nil = active, Date = soft-deleted)
var deletedAt: Date?

/// Source of the deletion action for audit trail
/// Values: "user", "sync", "migration", "cleanup"
var deletionSource: String?
```

**New Methods:**
```swift
/// Soft delete this habit (marks as deleted without removing from database)
func softDelete(source: String, context: ModelContext)

/// Check if this habit is soft-deleted
var isSoftDeleted: Bool { deletedAt != nil }

/// Restore a soft-deleted habit (undelete)
func restore()
```

#### HabitDeletionLog Model (HabitDataModel.swift)

**New Model:**
```swift
@Model
final class HabitDeletionLog {
    var id: UUID              // Unique identifier
    var habitId: UUID         // ID of deleted habit
    var habitName: String     // Name preserved for debugging
    var userId: String        // User who owned the habit
    var deletedAt: Date       // When deletion occurred
    var source: String        // "user", "sync", "migration", "cleanup"
    var metadata: String?     // Optional JSON for additional context
}
```

**Purpose:** Complete audit trail for investigating data loss.

---

### 2. Query Changes

All habit queries now filter out soft-deleted habits:

**Before:**
```swift
predicate = #Predicate<HabitData> { habitData in
  habitData.userId == userId
}
```

**After:**
```swift
predicate = #Predicate<HabitData> { habitData in
  habitData.userId == userId && habitData.deletedAt == nil
}
```

**Files Updated:**
- `Core/Data/SwiftData/SwiftDataStorage.swift` - loadHabits()
- `Core/Data/Sync/SyncEngine.swift` - reconcileDeletedHabits()

---

### 3. Deletion Logic Changes

#### SwiftDataStorage.deleteHabit()

**Before:** Hard delete with `modelContext.delete(habitData)`

**After:** Soft delete with audit logging
```swift
habitData.softDelete(source: "user", context: container.modelContext)
```

**Logging:**
```
🗑️ [SOFT_DELETE] Habit soft-deleted:
   ID: abc12345...
   Name: 'Morning Run'
   UserId: 'xyz98765...'
   Source: user
   DeletedAt: 2025-01-18 14:23:45
   Call stack: [debug info]
```

#### HabitStore.deleteHabit()

**Changes:**
- Updated logging to indicate soft delete
- Added TODO for Firestore soft delete (currently still hard-deletes from Firestore)
- Calls `activeStorage.deleteHabit()` which now soft-deletes

#### SyncEngine.reconcileDeletedHabits()

**Major Changes:**

1. **Soft Delete Instead of Hard Delete:**
   - Local habits deleted remotely are now **soft-deleted** (not removed)
   - Preserves audit trail for sync conflicts

2. **Sync Conflict Detection:**
   ```swift
   if hasCompletionRecords {
       logger.warning("⚠️ [SYNC_CONFLICT] Habit '\(name)' deleted remotely but HAS LOCAL COMPLETION RECORDS")
       logger.warning("   Action: SOFT-DELETING locally (preserving data for investigation)")
   }
   ```

3. **Completion Records Preserved:**
   - Completion records are **NOT deleted** during sync conflicts
   - Allows investigation of why a habit was deleted

---

## Deletion Sources

| Source | Description | Example |
|--------|-------------|---------|
| `user` | User explicitly deleted the habit | Swipe-to-delete in UI |
| `sync` | Sync engine detected remote deletion | Habit deleted on another device |
| `migration` | Deleted during data migration | Schema upgrade cleanup |
| `cleanup` | Automated cleanup (future) | Hard-delete after 30+ days |

---

## Diagnostic Logging

When a habit is soft-deleted, the following is logged:

```
🗑️ [SOFT_DELETE] Habit soft-deleted:
   ID: abc12345...
   Name: 'Morning Run'
   UserId: 'xyz98765...'
   Source: user
   DeletedAt: 2025-01-18 14:23:45
#if DEBUG
   Call stack:
      Frame 1: HabitData.softDelete(source:context:)
      Frame 2: SwiftDataStorage.deleteHabit(id:)
      Frame 3: HabitStore.deleteHabit(_:)
      Frame 4: HabitsTabView.deleteHabit(at:)
      Frame 5: ...
#endif
```

---

## Sync Safety Rules

### Rule 1: Never Auto-Delete Habits with Completion Records

**Before:** If remote says habit is deleted, delete it locally immediately.

**After:** 
```swift
if hasCompletionRecords {
    logger.warning("⚠️ [SYNC_CONFLICT] Habit has completion records")
    // Soft-delete instead, log warning
    habitToSoftDelete.softDelete(source: "sync", context: modelContext)
}
```

### Rule 2: Preserve Audit Trail

**Before:** Hard-delete removes all traces of the habit.

**After:**
- Habit remains in database (marked as deleted)
- HabitDeletionLog entry created
- Completion records preserved

### Rule 3: Log All Sync Conflicts

Every sync conflict is logged with:
- Habit ID and name
- Local completion record count
- Decision made (soft-delete)
- Source of conflict

---

## Schema Updates

### HabittoSchemaV1 (Migrations/HabittoSchemaV1.swift)

**Added:**
- `HabitDeletionLog.self` to models array
- Updated documentation to reflect 14 models (was 13)

**Model Count:** 13 → 14

---

## Querying Soft-Deleted Habits

### View Active Habits (Default)
```swift
let predicate = #Predicate<HabitData> { habit in
    habit.userId == userId && habit.deletedAt == nil
}
```

### View ALL Habits (Including Soft-Deleted)
```swift
let predicate = #Predicate<HabitData> { habit in
    habit.userId == userId
}
```

### View ONLY Soft-Deleted Habits
```swift
let predicate = #Predicate<HabitData> { habit in
    habit.userId == userId && habit.deletedAt != nil
}
```

### View Deletion Logs
```swift
let descriptor = FetchDescriptor<HabitDeletionLog>(
    sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
)
let logs = try modelContext.fetch(descriptor)
```

---

## Future Enhancements

### 1. Hard Delete Cleanup (30+ Days)

**Proposed Implementation:**
```swift
// Scheduled task to permanently delete habits soft-deleted > 30 days ago
func cleanupOldSoftDeletedHabits() async {
    let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
    
    let predicate = #Predicate<HabitData> { habit in
        habit.deletedAt != nil && habit.deletedAt! < thirtyDaysAgo
    }
    
    let descriptor = FetchDescriptor<HabitData>(predicate: predicate)
    let oldDeletedHabits = try modelContext.fetch(descriptor)
    
    for habit in oldDeletedHabits {
        // Log cleanup
        let log = HabitDeletionLog(
            habitId: habit.id,
            habitName: habit.name,
            userId: habit.userId,
            source: "cleanup",
            metadata: "{\"reason\": \"30+ days old\"}"
        )
        modelContext.insert(log)
        
        // Now hard delete
        modelContext.delete(habit)
    }
    
    try modelContext.save()
}
```

### 2. Firestore Soft Delete

**TODO:** Implement soft delete in Firestore (currently still hard-deletes)

```swift
// Instead of:
try await docRef.delete()

// Do:
try await docRef.updateData([
    "deletedAt": FieldValue.serverTimestamp(),
    "deletionSource": "user"
])
```

### 3. Restore UI

**Proposed Feature:** Allow users to restore recently deleted habits

```swift
// HabitsTabView -> "Recently Deleted" tab
// Shows soft-deleted habits from last 30 days
// Allows restoration with habit.restore()
```

---

## Debugging Missing Habits

### Step 1: Check Deletion Logs

```swift
let logs = try modelContext.fetch(FetchDescriptor<HabitDeletionLog>(
    sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
))

for log in logs {
    print("Habit '\(log.habitName)' deleted at \(log.deletedAt)")
    print("  Source: \(log.source)")
    print("  HabitId: \(log.habitId)")
}
```

### Step 2: Check Soft-Deleted Habits

```swift
let predicate = #Predicate<HabitData> { habit in
    habit.deletedAt != nil
}
let deletedHabits = try modelContext.fetch(FetchDescriptor(predicate: predicate))

for habit in deletedHabits {
    print("Soft-deleted habit: '\(habit.name)'")
    print("  Deleted at: \(habit.deletedAt?.description ?? "nil")")
    print("  Source: \(habit.deletionSource ?? "unknown")")
    print("  Has completion records: \(!habit.completionHistory.isEmpty)")
}
```

### Step 3: Check Sync Logs

```bash
# Filter console logs for sync conflicts
grep "SYNC_CONFLICT" console.log

# Example output:
⚠️ [SYNC_CONFLICT] Habit 'Morning Run' deleted remotely but HAS LOCAL COMPLETION RECORDS
   HabitId: abc12345...
   Local completion records: 47
   Action: SOFT-DELETING locally (preserving data for investigation)
```

---

## Benefits

### 1. Data Loss Prevention
- Habits are never permanently deleted without trace
- All deletions are logged with timestamp and source
- Can investigate "why did my habit disappear?"

### 2. Sync Conflict Detection
- Warns when sync would delete habits with completion records
- Logs all conflicts for investigation
- Preserves data instead of auto-deleting

### 3. Audit Trail
- Complete history of all deletions
- Know who/what/when/why for every deletion
- Can restore if needed

### 4. Debugging
- Call stack logged in debug builds
- Detailed logging at every step
- Easy to trace deletion flow

---

## Migration Notes

### Existing Habits
- Existing habits have `deletedAt = nil` (active)
- No migration needed
- New fields are optional

### Compatibility
- Old code still works (queries filter `deletedAt == nil`)
- Backwards compatible
- Can be deployed without data migration

---

## Testing Recommendations

### 1. Test Soft Delete
```swift
// Delete a habit
try await habitStore.deleteHabit(habit)

// Verify it's soft-deleted
let deleted = try modelContext.fetch(FetchDescriptor<HabitData>(...))
XCTAssertNotNil(deleted.deletedAt)
XCTAssertEqual(deleted.deletionSource, "user")

// Verify deletion log exists
let logs = try modelContext.fetch(FetchDescriptor<HabitDeletionLog>(...))
XCTAssertEqual(logs.count, 1)
XCTAssertEqual(logs[0].habitId, habit.id)
```

### 2. Test Query Filtering
```swift
// Create and soft-delete a habit
let habit = HabitData(...)
habit.softDelete(source: "user", context: modelContext)
try modelContext.save()

// Verify it doesn't appear in active habits
let activeHabits = try await swiftDataStorage.loadHabits()
XCTAssertFalse(activeHabits.contains(where: { $0.id == habit.id }))
```

### 3. Test Sync Conflict Detection
```swift
// Create habit with completion records
let habit = HabitData(...)
let record = CompletionRecord(userId: "...", habitId: habit.id, ...)
modelContext.insert(record)

// Simulate sync conflict (remote deleted, local has records)
await syncEngine.reconcileDeletedHabits(...)

// Verify habit is soft-deleted (not hard-deleted)
let softDeleted = try modelContext.fetch(...)
XCTAssertNotNil(softDeleted.deletedAt)
XCTAssertEqual(softDeleted.deletionSource, "sync")
```

---

## Files Modified

1. ✅ `Core/Data/SwiftData/HabitDataModel.swift`
   - Added `deletedAt` and `deletionSource` fields to HabitData
   - Added `HabitDeletionLog` model
   - Added soft delete methods

2. ✅ `Core/Data/SwiftData/Migrations/HabittoSchemaV1.swift`
   - Added HabitDeletionLog to schema
   - Updated model count and documentation

3. ✅ `Core/Data/SwiftData/SwiftDataStorage.swift`
   - Updated loadHabits() query to filter `deletedAt == nil`
   - Updated deleteHabit() to use soft delete

4. ✅ `Core/Data/Repository/HabitStore.swift`
   - Updated logging to indicate soft delete
   - Added TODO for Firestore soft delete

5. ✅ `Core/Data/Sync/SyncEngine.swift`
   - Updated reconcileDeletedHabits() to use soft delete
   - Added sync conflict detection
   - Preserves completion records during conflicts

---

## Console Log Examples

### Successful Soft Delete (User Action)
```
🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - START for habit ID: ABC123
🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - Found habit: 'Morning Run'
🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - Performing SOFT DELETE
🗑️ [SOFT_DELETE] Habit soft-deleted:
   ID: ABC123...
   Name: 'Morning Run'
   UserId: 'xyz98765...'
   Source: user
   DeletedAt: 2025-01-18 14:23:45
🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - END - Successfully soft-deleted
```

### Sync Conflict Detected
```
⚠️ [SYNC_CONFLICT] Habit 'Evening Meditation' deleted remotely but HAS LOCAL COMPLETION RECORDS
   HabitId: DEF456...
   Local completion records: 89
   Action: SOFT-DELETING locally (preserving data for investigation)
🗑️ [SOFT_DELETE] SyncEngine: Soft-deleting locally orphaned habit 'Evening Meditation'
🗑️ [SOFT_DELETE] Habit soft-deleted:
   ID: DEF456...
   Name: 'Evening Meditation'
   UserId: 'xyz98765...'
   Source: sync
   DeletedAt: 2025-01-18 14:25:12
ℹ️ [SYNC_SAFETY] Preserving completion records in Firestore for soft-deleted habits
```

---

**Implementation Complete:** ✅  
**Next Steps:** Test in production, monitor deletion logs, consider adding restore UI

