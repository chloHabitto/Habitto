# Soft Delete Verification Steps

**Issue:** Schema showing 13 entities instead of 14, query predicates missing "AND deletedAt == nil"

---

## ✅ Step 1: Verify Schema Changes

I've confirmed that `HabitDeletionLog.self` **IS** in the schema array at:
- **File:** `Core/Data/SwiftData/Migrations/HabittoSchemaV1.swift`
- **Line:** 46

The schema changes are correct in the code.

---

## 🧹 Step 2: Clean Build Process

The issue is that SwiftData is using the **old database** with the old schema. Follow these steps **exactly**:

### 2.1 Clean Build Folder
```
1. Open Xcode
2. Product → Clean Build Folder (⌘⇧K)
3. Wait for completion
```

### 2.2 Delete DerivedData (CRITICAL!)
```
Option A - Via Xcode:
1. Xcode → Settings → Locations
2. Click arrow next to DerivedData path
3. Delete the entire DerivedData folder
4. Close Finder

Option B - Via Terminal:
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### 2.3 Delete App from Simulator/Device (CRITICAL!)
```
1. Long press Habitto app icon
2. Select "Remove App"  
3. Confirm "Delete App"

This removes the OLD database file with 13 entities!
```

### 2.4 Quit and Restart Xcode
```
1. Xcode → Quit Xcode (⌘Q)
2. Wait 5 seconds
3. Reopen Xcode
4. Open Habitto.xcodeproj
```

### 2.5 Rebuild
```
1. Product → Build (⌘B)
2. Wait for build to complete
3. Product → Run (⌘R)
```

---

## 🔍 Step 3: Verify Changes Took Effect

### 3.1 Check Console on App Launch

**Look for these lines:**

```
🔧 SwiftData: Schema version: 1.0.0
🔧 SwiftData: Schema includes 14 entities  ← Should be 14 (not 13)
```

**If still showing 13:**
- Database wasn't deleted
- Try manually: Settings app → General → iPhone Storage → Habitto → Delete App

### 3.2 Check Query Predicate Logs

**When loading habits, look for:**

```
🔍 [SWIFTDATA_LOAD] Query predicate: userId == 'abc12345...' AND deletedAt == nil  ← Should see this
```

**If missing "AND deletedAt == nil":**
- Code changes didn't compile
- Try: Clean Build Folder again → Quit Xcode → Delete DerivedData → Rebuild

---

## 🧪 Step 4: Test Soft Delete

### Manual Test

1. **Create a habit:**
   - Create any habit (e.g., "Test Delete")

2. **Delete the habit:**
   - Swipe left on the habit
   - Tap Delete

3. **Check Console Logs:**

**Expected:**
```
🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - START for habit ID: ABC123...
🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - Found habit: 'Test Delete'
🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - Performing SOFT DELETE
🗑️ [SOFT_DELETE] Habit soft-deleted:
   ID: ABC123...
   Name: 'Test Delete'
   UserId: 'xyz98765...'
   Source: user
   DeletedAt: 2025-01-18 14:23:45
🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - END - Successfully soft-deleted
```

**If seeing old logs:**
```
🗑️ DELETE_FLOW: ...  ← OLD LOGS (means changes didn't take effect)
```

### Optional: Add Debug Logging for Verification

Add this temporary code to `SwiftDataStorage.loadHabits()` after the query:

```swift
// Temporary debug code - check for soft-deleted habits
let allHabitsDebug = try container.modelContext.fetch(FetchDescriptor<HabitData>())
let softDeletedDebug = allHabitsDebug.filter { $0.deletedAt != nil }
print("🔍 [DEBUG] Total: \(allHabitsDebug.count), Active: \(habitDataArray.count), Soft-deleted: \(softDeletedDebug.count)")
if !softDeletedDebug.isEmpty {
    for habit in softDeletedDebug {
        print("   Soft-deleted: '\(habit.name)' at \(habit.deletedAt?.description ?? "nil")")
    }
}
```

This will show you if soft-deleted habits exist in the database.

---

## ❌ Troubleshooting

### Problem: Still showing 13 entities

**Solution 1: Nuclear Option**
```bash
# Terminal commands:
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Library/Application\ Support/default.store*

# Then rebuild in Xcode
```

**Solution 2: Check Build Settings**
```
1. Xcode → Project Navigator → Select Habitto project
2. Select Habitto target → Build Settings
3. Search for "Optimization Level"
4. Ensure Debug is set to "No Optimization [-Onone]"
```

### Problem: Query predicate doesn't show "AND deletedAt == nil"

**Check the code:**
```swift
// File: Core/Data/SwiftData/SwiftDataStorage.swift
// Around line 437

// Should look like this:
descriptor.predicate = #Predicate<HabitData> { habitData in
  habitData.userId == userId && habitData.deletedAt == nil  // ← Both conditions
}
```

**If correct but still not working:**
1. Clean Build Folder (⌘⇧K)
2. Quit Xcode completely
3. Delete DerivedData
4. Reopen Xcode
5. Rebuild

### Problem: [SOFT_DELETE] logs not appearing

**This means the old code is running. Try:**
```
1. Quit app on simulator
2. Delete app from simulator
3. In Xcode: Product → Clean Build Folder
4. Quit Xcode
5. Delete DerivedData folder
6. Restart Xcode
7. Rebuild and run
```

### Problem: Crash on launch

**If you see:**
```
Fatal error: Schema mismatch
```

**Solution:**
```
The database schema doesn't match the code.
1. Delete app from device (removes old database)
2. Rebuild and reinstall
```

---

## ✅ Success Checklist

After following all steps, verify:

- [ ] Console shows: "Schema includes **14** entities"
- [ ] Console shows: "Query predicate: userId == '...' **AND deletedAt == nil**"
- [ ] Deleting a habit shows **[SOFT_DELETE]** logs (not DELETE_FLOW)

---

## 📊 What Each File Does

| File | Purpose |
|------|---------|
| `HabitDataModel.swift` | Added `deletedAt` and `deletionSource` fields + `HabitDeletionLog` model |
| `HabittoSchemaV1.swift` | Added `HabitDeletionLog.self` to schema (line 46) |
| `SwiftDataStorage.swift` | Updated queries to filter `deletedAt == nil`, updated `deleteHabit()` to soft-delete |
| `HabitStore.swift` | Updated logging to show soft delete |
| `SyncEngine.swift` | Updated to soft-delete during sync conflicts |

---

## 🚨 If Nothing Works

If you've tried everything and it's still not working:

1. **Verify code changes are actually in the files:**
   ```
   Open each file and manually check:
   - HabitDataModel.swift line ~77: deletedAt: Date?
   - HabittoSchemaV1.swift line 46: HabitDeletionLog.self
   - SwiftDataStorage.swift line ~437: && habitData.deletedAt == nil
   ```

2. **Create a new build:**
   ```
   1. Close Xcode
   2. Delete these folders:
      - ~/Library/Developer/Xcode/DerivedData
      - ~/Library/Caches/com.apple.dt.Xcode
   3. Restart Mac (yes, really)
   4. Open Xcode
   5. Clean Build Folder
   6. Delete app from simulator
   7. Rebuild
   ```

3. **Check for compiler errors:**
   ```
   If there were any compiler errors during build,
   the old binary might still be running.
   ```

---

## 📝 Next Steps After Verification

Once soft delete is working:

1. ✅ Monitor deletion logs in console
2. ✅ Test sync conflicts (delete habit on another device)
3. ✅ Consider adding restore UI
4. ✅ Plan cleanup task for habits deleted > 30 days
5. ✅ Add Firestore soft delete support (TODO)

---

**Created:** 2025-01-18  
**Status:** Ready for testing after clean build

