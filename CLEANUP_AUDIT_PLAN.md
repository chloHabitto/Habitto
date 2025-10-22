# Code Cleanup Audit Plan

## Overview
This document identifies all diagnostic logging added during the debugging session and categorizes what should be removed, kept, or modified for production.

---

## Priority 1: Remove Diagnostic Logging

### Files Modified During Debug Session

Based on grep analysis, the following files have diagnostic print statements:

| File | Print Count | Category | Action Required |
|------|-------------|----------|-----------------|
| DualWriteStorage.swift | ~30 | Sync logging | Review & clean |
| HabitDataModel.swift | ~10 | Data model logging | Review & clean |
| HabitStore.swift | ~40 | Persistence logging | Review & clean |
| HomeTabView.swift | ~50 | UI flow logging | Review & clean |
| SwiftDataStorage.swift | ~20 | Database logging | Review & clean |

---

## File-by-File Cleanup Plan

### 1. Core/Data/Storage/DualWriteStorage.swift

**Purpose**: Dual-write to local SwiftData + Firestore

#### Logs to REMOVE (Verbose Success Messages):
```swift
// Lines ~50-94 in saveHabits()
print("💾 SAVE_START[\(taskId)]: Saving \(habits.count) habits")
print("✅ SAVE_LOCAL[\(taskId)]: Successfully saved to SwiftData")
print("🚀 SAVE_BACKGROUND[\(taskId)]: Launching background sync task...")
print("📤 SYNC_START[\(taskId)]: Background task running, self captured")
print("✅ SYNC_END[\(taskId)]: Background task complete")
print("✅ SAVE_COMPLETE[\(taskId)]: Returning to caller...")

// Lines ~101-161 in syncHabitsToFirestore()
print("📤 SYNC_FIRESTORE: Processing \(habits.count) habits")
print("  → Checking '\(habit.name)' (syncStatus: \(habit.syncStatus)...)")
print("  ⏭️ SKIP: '\(habit.name)' was synced \(Int(timeSinceSync))s ago")
print("  📤 SYNCING: '\(habit.name)' to Firestore...")
print("  ✅ SUCCESS: '\(habit.name)' synced and status updated")
print("📤 SYNC_COMPLETE: synced=\(syncedCount), skipped=\(skippedCount)...")

// Lines ~169-181 in loadHabits()
print("📂 LOAD: Using local-first strategy - loading from SwiftData")
print("✅ LOAD: Loaded \(filtered.count) habits from SwiftData successfully")

// Lines ~176-205 in loadHabits() - NEW sync-down feature
print("📂 LOAD: Local storage is empty, attempting to sync from Firestore...")
print("📥 SYNC_DOWN: Found \(firestoreHabits.count) habits in Firestore, saving to local...")
print("✅ SYNC_DOWN: Successfully synced \(syncedFiltered.count) habits from Firestore")
print("📂 LOAD: No habits found in Firestore either - fresh install")
```

#### Logs to KEEP (Critical Errors):
```swift
// Line ~77-81
print("❌ SAVE_LOCAL[\(taskId)]: FAILED - \(error.localizedDescription)")
print("❌ Error type: \(type(of: error))")
print("❌ Full error: \(error)")

// Line ~147-151
print("  ❌ FAILED: '\(habit.name)' sync failed, error saved: \(error)")
print("  ❌ CRITICAL: '\(habit.name)' sync failed AND couldn't save error state!")

// Line ~179
print("❌ LOAD_FAILED: SwiftData load error: \(error)")

// Line ~201
print("⚠️ SYNC_DOWN: Failed to sync from Firestore: \(error)")
```

#### Logs to MODIFY (Convert to Logger):
```swift
// Change verbose success to logger.debug (only in DEBUG builds)
#if DEBUG
dualWriteLogger.debug("Loaded \(filtered.count) habits from local storage")
dualWriteLogger.debug("Synced \(syncedCount) habits to Firestore")
#endif

// Keep error logging but use logger instead of print
dualWriteLogger.error("Failed to save habits: \(error)")
```

**Recommendation**:
- Remove ~20 verbose success print statements
- Keep ~5 critical error prints
- Convert ~3 informational logs to logger.debug with #if DEBUG

---

### 2. Core/Data/SwiftData/HabitDataModel.swift

**Purpose**: SwiftData model and conversion to Habit

#### Logs to REMOVE:
```swift
// Lines ~174-183 in toHabit()
print("🔍 toHabit(): Found \(completionRecords.count) orphaned CompletionRecords...")
print("🔍 toHabit(): Using \(completionRecords.count) CompletionRecords from relationship...")

// Lines ~218-228 in toHabit()
print("🔧 HOTFIX: toHabit() for '\(name)':")
print("  → CompletionRecords: \(completionRecords.count)")
print("  → completionHistory entries: \(completionHistoryDict.count)")
print("  → completionStatus entries: \(completionStatusDict.count)")
print("  → completionTimestamps entries: \(completionTimestampsDict.count)")
print("  → Completed days: \(completedCount)/\(completionRecords.count)")
```

#### Logs to KEEP:
```swift
// Line ~176
print("❌ toHabit(): Failed to query CompletionRecords: \(error)")
```

**Recommendation**:
- Remove ~10 diagnostic print statements about conversion
- Keep 1 error log
- This is internal model code, shouldn't have verbose logging in production

---

### 3. Core/Data/Repository/HabitStore.swift

**Purpose**: Core data persistence layer

#### Logs to REMOVE (Timing/Debug):
```swift
// All the timing logs we added:
print("    ⏱️ HABITSTORE_START: setProgress() at \(DateFormatter...)")
print("    ⏱️ SAVE_START: saveHabits() at \(DateFormatter...)")
print("    ⏱️ SAVE_END: saveHabits() at \(DateFormatter...)")
print("    ⏱️ HABITSTORE_END: setProgress() at \(DateFormatter...)")

// Progress tracking logs:
print("🎯 DEBUG: HabitStore.setProgress called - will create CompletionRecord")
print("🎯 PERSIST_START: Habit1 progress=10 date=2025-10-22")
print("✅ PERSIST_SUCCESS: Habit1 saved in 0.035s")

// CompletionRecord creation logs:
print("🎯 createCompletionRecordIfNeeded: Starting for habit '\(habit.name)'...")
print("🎯 createCompletionRecordIfNeeded: Getting modelContext...")
print("🎯 createCompletionRecordIfNeeded: Creating predicate...")
print("🎯 createCompletionRecordIfNeeded: Found \(existingRecords.count) existing records")
print("🎯 createCompletionRecordIfNeeded: Creating new record...")
print("🎯 createCompletionRecordIfNeeded: Inserting record into context...")
print("✅ createCompletionRecordIfNeeded: Context saved successfully")
```

#### Logs to KEEP:
```swift
// Critical validation errors:
logger.error("Critical validation errors found, aborting save")
logger.error("Habit not found in storage: \(habit.name)")

// Important state changes (use logger.info):
logger.info("Setting progress to \(progress) for habit '\(habit.name)' on \(dateKey)")
logger.info("Successfully updated progress for habit '\(habit.name)' on \(dateKey)")

// Database errors:
logger.error("❌ createCompletionRecordIfNeeded: Failed to create/update...")
```

#### Logs to MODIFY:
```swift
// Convert formation vs breaking habit debug logs to #if DEBUG
#if DEBUG
if habit.habitType == .breaking {
  logger.debug("🔍 BREAKING HABIT - '\(habit.name)' | Progress: \(progress)")
} else {
  logger.debug("🔍 FORMATION HABIT - '\(habit.name)' | Progress: \(progress)")
}
#endif
```

**Recommendation**:
- Remove ~30 verbose diagnostic print statements
- Keep ~8 logger statements for errors and important state changes
- Wrap ~5 debug logs in #if DEBUG

---

### 4. Views/Tabs/HomeTabView.swift

**Purpose**: Main UI orchestration

#### Logs to REMOVE (Completion Flow Debug):
```swift
// All the completion flow debug we added:
print("🎯 COMPLETION_FLOW: onHabitCompleted - habitId=\(habit.id)...")
print("  🔍 Breaking habit '\(h.name)': progress=\(progress), goal=\(goalAmount)...")
print("  🔍 Formation habit '\(h.name)': progress=\(progress), goal=\(goalAmount)...")
print("🎯 CELEBRATION_CHECK: Habit '\(h.name)' (type=\(h.habitType)) | isComplete=...")
print("🎯 COMPLETION_FLOW: Last habit completed - will trigger celebration...")
print("🎯 COMPLETION_FLOW: Habit completed, \(remainingHabits.count) remaining")

// Uncomplete flow:
print("🎯 UNCOMPLETE_FLOW: Habit '\(habit.name)' uncompleted for \(dateKey)")
print("✅ DERIVED_XP: Recalculating XP after uncomplete")
print("✅ DERIVED_XP: XP recalculated to \(completedDaysCount * 50)...")
print("✅ UNCOMPLETE_FLOW: DailyAward removed for \(dateKey)")

// Difficulty sheet dismissed:
print("🎯 COMPLETION_FLOW: onDifficultySheetDismissed - dateKey=\(dateKey)...")
print("🔄 COMPLETION_FLOW: Starting 1-second delay before resort...")
print("   deferResort (before delay): \(deferResort)")
print("   sortedHabits count (before delay): \(sortedHabits.count)")
print("✅ COMPLETION_FLOW: Resort completed!")

// XP tracking:
print("✅ INITIAL_XP: Computing XP from loaded habits")
print("✅ INITIAL_XP: Set to \(completedDaysCount * 50)...")
print("✅ DERIVED_XP: XP set to \(completedDaysCount * 50)...")
print("🎯 COMPLETION_FLOW: Current XP after award: \(currentXP)")

// Event bus:
print("🎯 STEP 12: Received dailyAwardGranted event for \(dateKey)")
print("🎯 STEP 12: Setting showCelebration = true")
print("🎯 STEP 12: Received dailyAwardRevoked event for \(dateKey)")

// Resort logging:
print("🔄 RESORT: Starting resort...")
print("   ✅ resortHabits() completed - sortedHabits count: \(sortedHabits.count)")
print("      [\(index)] \(habit.name) - completed: \(isComplete)")
```

#### Logs to KEEP:
```swift
// Important errors only (none found - all are debug logs)
```

#### Debug Counter Removal:
```swift
// Remove these debug counters entirely:
@State private var debugGrantCalls = 0
@State private var debugRevokeCalls = 0

// And their usage:
#if DEBUG
debugGrantCalls += 1
print("🔍 DEBUG: onDifficultySheetDismissed - grant call #\(debugGrantCalls)...")
#endif
```

**Recommendation**:
- Remove ~40-50 verbose print statements
- Remove debug counters
- No critical logs to keep (this is UI layer)
- Consider adding ONE error log if DailyAward operations fail

---

### 5. Core/Data/SwiftData/SwiftDataStorage.swift

**Purpose**: SwiftData persistence implementation

#### Logs to REMOVE:
```swift
// Timing logs:
print("        ⏱️ SWIFTDATA_SAVE_START: Calling modelContext.save() at ...")
print("        📊 SWIFTDATA_CONTEXT: hasChanges=\(container.modelContext.hasChanges)")
print("        ⏱️ SWIFTDATA_SAVE_END: modelContext.save() succeeded at ...")
print("        ✅ SWIFTDATA_SUCCESS: Saved \(habits.count) habits to database")
```

#### Logs to KEEP:
```swift
// All the existing logger statements (these are production-appropriate)
logger.info("✅ SUCCESS! Saved \(habits.count) habits in \(timeElapsed)s")
logger.error("❌ Fatal error in saveHabits: \(error.localizedDescription)")
logger.warning("⚠️ Failed to load existing habits, starting fresh...")
```

**Recommendation**:
- Remove ~5 verbose print statements
- Keep all logger.info/error/warning statements (they're appropriate)
- SwiftDataStorage already has good production logging

---

## Summary Statistics

### Total Print Statements to Remove: ~120-150
### Critical Error Logs to Keep: ~20
### Debug Logs to Wrap in #if DEBUG: ~10

---

## Production Logging Guidelines

### ✅ KEEP These Types of Logs:

1. **Critical Errors** (always use logger.error):
```swift
logger.error("Failed to save habits: \(error.localizedDescription)")
logger.error("Database corruption detected: \(errorDesc)")
logger.error("Firestore sync failed: \(error)")
```

2. **Important State Changes** (use logger.info):
```swift
logger.info("User signed in: \(userId)")
logger.info("Habit created: '\(habit.name)'")
logger.info("XP awarded: +\(xp) for completing all habits")
```

3. **Warnings** (use logger.warning):
```swift
logger.warning("Validation failed with \(errors.count) errors")
logger.warning("Failed to sync to Firestore, will retry")
```

### ❌ REMOVE These Types of Logs:

1. **Verbose Success Messages**:
```swift
print("✅ Successfully did X")
print("📂 Loading from Y")
print("🎯 Starting process Z")
```

2. **Timing/Performance Logs**:
```swift
print("⏱️ Operation started at \(time)")
print("⏱️ Operation completed in \(duration)s")
```

3. **Step-by-Step Flow Logs**:
```swift
print("🔄 Step 1: Doing X")
print("🔄 Step 2: Doing Y")
print("✅ Step 3: Complete")
```

4. **Debug Counters/Flags**:
```swift
debugCallCount += 1
print("🔍 DEBUG: Call #\(debugCallCount)")
```

### 🔧 WRAP IN #if DEBUG:

```swift
#if DEBUG
logger.debug("Habit type check: \(habit.habitType)")
logger.debug("CompletionRecords count: \(records.count)")
#endif
```

---

## Cleanup Execution Plan

### Step 1: Review This Plan (5 min)
- [ ] Review each file's cleanup requirements
- [ ] Confirm understanding of keep vs remove
- [ ] Ask questions about any unclear items

### Step 2: Backup Current State (2 min)
```bash
git add .
git commit -m "Before cleanup: All tests passing"
```

### Step 3: Clean Files One by One (20 min)
Execute cleanup in this order:
1. DualWriteStorage.swift (~5 min)
2. HabitDataModel.swift (~2 min)
3. HabitStore.swift (~6 min)
4. HomeTabView.swift (~5 min)
5. SwiftDataStorage.swift (~2 min)

### Step 4: Test After Cleanup (5 min)
```bash
# Clean build
Product → Clean Build Folder (⇧⌘K)
Product → Build (⌘B)

# Quick smoke test
- Launch app
- Complete one habit
- Close and reopen
- Verify persistence still works
```

### Step 5: Commit Clean Version (2 min)
```bash
git add .
git commit -m "Remove diagnostic logging, keep production error logs"
```

**Total Time**: ~35 minutes

---

## Next Steps After Cleanup

1. ✅ Create release notes
2. ✅ Update version number
3. ✅ Archive test documents
4. ✅ Build for distribution

---

## Questions to Answer Before Proceeding

1. **Should we keep any verbose logs for TestFlight builds?**
   - Option A: Remove all debug logs now (clean production code)
   - Option B: Wrap in #if DEBUG for debugging TestFlight issues
   - **Recommendation**: Option B for safety

2. **Should we convert print() to Logger everywhere?**
   - Option A: Use Logger consistently (better for production)
   - Option B: Keep print() for errors (simpler)
   - **Recommendation**: Option A for professionalism

3. **Should we add a feature flag for verbose logging?**
   - Could enable detailed logs for troubleshooting
   - **Recommendation**: Not needed for now, use #if DEBUG

---

## Approval Needed

**Please review this plan and confirm:**
- [ ] Agree with what to keep vs remove
- [ ] Ready to proceed with cleanup
- [ ] Backup/commit strategy is acceptable

**Once approved, I'll execute the cleanup file by file with your confirmation at each step.**

