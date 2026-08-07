# Soft Delete Testing Guide

**Issue:** Schema changes not appearing (showing 13 entities instead of 14)

---

## Step 1: Clean Build Process

### 1.1 Clean Build Folder
```
In Xcode:
Product → Clean Build Folder (⌘⇧K)
```

### 1.2 Delete DerivedData (Important!)
```bash
# Option A: Via Xcode
Xcode → Preferences → Locations → DerivedData → Click arrow → Delete folder

# Option B: Via Terminal
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### 1.3 Delete App from Device/Simulator
```
1. Long press the Habitto app icon
2. Select "Remove App"
3. Confirm deletion
4. This removes the OLD database with 13 entities
```

### 1.4 Rebuild and Install
```
In Xcode:
Product → Build (⌘B)
Product → Run (⌘R)
```

---

## Step 2: Verify Schema Changes

### 2.1 Check Console Logs on App Launch

**Expected Output:**
```
🔧 SwiftData: Schema version: 1.0.0
🔧 SwiftData: Schema includes 14 entities  ✅ (was 13)
```

**If still showing 13:** Database file wasn't deleted. Try:
```bash
# Manually delete database files
cd ~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/data/Containers/Data/Application/[APP_ID]/Library/Application\ Support
rm -rf default.store*
```

### 2.2 Check Query Predicate Logs

**Expected Output:**
```
🔍 [SWIFTDATA_LOAD] Query predicate: userId == 'abc12345...' AND deletedAt == nil  ✅
```

**If missing "AND deletedAt == nil":** Code changes didn't compile. Check:
```
1. Clean build folder again
2. Quit Xcode completely
3. Restart Xcode
4. Rebuild
```

---

## Step 3: Test Soft Delete

### 3.1 Create Test Habit

1. Open app
2. Create a new habit (e.g., "Test Habit Delete")
3. Note the habit ID from logs (will show during creation)

### 3.2 Delete the Habit

1. Go to Habits tab
2. Swipe left on "Test Habit Delete"
3. Tap Delete

### 3.3 Verify Soft Delete Logs

**Expected Console Output:**
```
🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - START for habit ID: ABC123...
🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - Found habit: 'Test Habit Delete'
🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - Performing SOFT DELETE (marking as deleted)
🗑️ [SOFT_DELETE] Habit soft-deleted:
   ID: ABC123...
   Name: 'Test Habit Delete'
   UserId: 'xyz98765...'
   Source: user
   DeletedAt: 2025-01-18 14:23:45
   Call stack:
      Frame 1: HabitData.softDelete(source:context:)
      Frame 2: SwiftDataStorage.deleteHabit(id:)
      ...
🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - modelContext.save() completed
🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - WAL checkpoint completed
🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - END - Successfully soft-deleted
```

**If seeing old DELETE_FLOW logs:** Code changes didn't compile or app using old binary.

---

## Step 4: Verify Data in Database

### 4.1 Check Soft-Deleted Habit Exists

Add this code temporarily to verify soft delete worked:

```swift
// In SwiftDataStorage.swift, add to loadHabits() after query:

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🔍 [DEBUG] Checking for soft-deleted habits...")

// Query ALL habits including soft-deleted
let allHabitsDescriptor = FetchDescriptor<HabitData>()
let allHabits = try container.modelContext.fetch(allHabitsDescriptor)

let softDeleted = allHabits.filter { $0.deletedAt != nil }
print("   Total habits in DB: \(allHabits.count)")
print("   Active habits: \(allHabits.count - softDeleted.count)")
print("   Soft-deleted habits: \(softDeleted.count)")

if !softDeleted.isEmpty {
    print("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("   📋 Soft-deleted habits:")
    for habit in softDeleted {
        print("      Name: '\(habit.name)'")
        print("      DeletedAt: \(habit.deletedAt?.description ?? "nil")")
        print("      Source: \(habit.deletionSource ?? "nil")")
    }
}
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
```

**Expected Output After Deleting Test Habit:**
```
🔍 [DEBUG] Checking for soft-deleted habits...
   Total habits in DB: 3
   Active habits: 2
   Soft-deleted habits: 1
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   📋 Soft-deleted habits:
      Name: 'Test Habit Delete'
      DeletedAt: 2025-01-18 14:23:45 +0000
      Source: user
```

### 4.2 Check HabitDeletionLog

```swift
// Add this to verify deletion log was created:

print("🔍 [DEBUG] Checking HabitDeletionLog...")
let logDescriptor = FetchDescriptor<HabitDeletionLog>(
    sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
)
let logs = try container.modelContext.fetch(logDescriptor)
print("   Total deletion logs: \(logs.count)")

if !logs.isEmpty {
    print("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("   📋 Recent deletions:")
    for log in logs.prefix(5) {
        print("      Habit: '\(log.habitName)'")
        print("      DeletedAt: \(log.deletedAt)")
        print("      Source: \(log.source)")
        print("      HabitId: \(log.habitId.uuidString.prefix(8))...")
    }
}
```

**Expected Output:**
```
🔍 [DEBUG] Checking HabitDeletionLog...
   Total deletion logs: 1
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   📋 Recent deletions:
      Habit: 'Test Habit Delete'
      DeletedAt: 2025-01-18 14:23:45 +0000
      Source: user
      HabitId: ABC123...
```

---

## Step 5: Verify Habit is Hidden from UI

### 5.1 Check Habits Tab

- The deleted habit should NOT appear in the habits list
- Other habits should still be visible

### 5.2 Check Query Filtering

**Console should show:**
```
🔍 [SWIFTDATA_LOAD] Habits matching userId predicate: 2
   (Note: This should be 1 less than before deletion)
```

---

## Step 6: Test Sync Conflict Detection

### 6.1 Simulate Sync Conflict

This is more complex but you can test manually:

1. Create a habit on Device A
2. Add completion records to it
3. Delete the habit from Firestore manually
4. Trigger sync on Device A

**Expected:**
```
⚠️ [SYNC_CONFLICT] Habit 'Morning Run' deleted remotely but HAS LOCAL COMPLETION RECORDS
   HabitId: ABC123...
   Local completion records: 5
   Action: SOFT-DELETING locally (preserving data for investigation)
🗑️ [SOFT_DELETE] SyncEngine: Soft-deleting locally orphaned habit 'Morning Run'
```

---

## Troubleshooting

### Issue: Still showing 13 entities

**Solution:**
```bash
# Nuclear option - delete everything
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Library/Application\ Support/default.store*

# Then rebuild
```

### Issue: Query predicate doesn't show "AND deletedAt == nil"

**Solution:**
1. Check `SwiftDataStorage.swift` line ~437
2. Verify the predicate includes both conditions
3. Clean build and restart Xcode

### Issue: Old DELETE_FLOW logs still appearing

**Solution:**
- Code changes didn't compile
- Try: Clean Build Folder → Quit Xcode → Delete DerivedData → Restart Xcode → Build

### Issue: Soft delete logs not appearing

**Checklist:**
- [ ] Did you clean build folder?
- [ ] Did you delete the app from device?
- [ ] Did you delete DerivedData?
- [ ] Did you restart Xcode?
- [ ] Did you rebuild after changes?

---

## Success Criteria

✅ **Schema Check**
- Console shows: "Schema includes 14 entities"

✅ **Query Check**  
- Console shows: "Query predicate: userId == '...' AND deletedAt == nil"

✅ **Soft Delete Check**
- Console shows: "[SOFT_DELETE]" logs (not "[DELETE_FLOW]")
- Habit has `deletedAt` set (not removed from DB)

✅ **Deletion Log Check**
- `HabitDeletionLog` entry exists with correct fields

✅ **UI Check**
- Deleted habit doesn't appear in habits list
- Other habits still visible

---

## Quick Test Script

Once app is running with correct schema:

```swift
// Run this in a test or debug view
func testSoftDelete() async {
    // 1. Create test habit
    let testHabit = Habit(
        id: UUID(),
        name: "Soft Delete Test",
        // ... other properties
    )
    try await habitStore.saveHabit(testHabit)
    print("✅ Created test habit")
    
    // 2. Delete it
    try await habitStore.deleteHabit(testHabit)
    print("✅ Deleted test habit")
    
    // 3. Verify soft delete
    let context = SwiftDataContainer.shared.modelContext
    let allHabits = try context.fetch(FetchDescriptor<HabitData>())
    let softDeleted = allHabits.first { $0.id == testHabit.id }
    
    assert(softDeleted != nil, "Habit should exist in DB")
    assert(softDeleted?.deletedAt != nil, "Habit should have deletedAt set")
    assert(softDeleted?.deletionSource == "user", "Habit should have source='user'")
    print("✅ Soft delete verified")
    
    // 4. Verify deletion log
    let logs = try context.fetch(FetchDescriptor<HabitDeletionLog>())
    let log = logs.first { $0.habitId == testHabit.id }
    
    assert(log != nil, "Deletion log should exist")
    assert(log?.habitName == "Soft Delete Test", "Log should preserve name")
    assert(log?.source == "user", "Log should have source='user'")
    print("✅ Deletion log verified")
    
    print("🎉 All tests passed!")
}
```

---

**Next Steps After Successful Testing:**

1. Monitor deletion logs in production
2. Consider adding restore UI
3. Implement cleanup task for habits deleted > 30 days ago
4. Add Firestore soft delete support

