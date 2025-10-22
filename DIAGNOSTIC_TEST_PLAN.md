# 🧪 Diagnostic Test Plan - Find Root Cause

## 🎯 Objective

Trace the complete flow of creating Habit3 to identify where and why data is lost.

---

## 📋 Test Procedure

### **Test 1: Create Habit3 and Watch Console**

1. **Build and run the app** with new logging
2. **Open Xcode console** (⌘⇧Y)
3. **Filter for these keywords:**
   - `SAVE_`
   - `SYNC_`
   - `FIRESTORE`
   - `Habit3`

4. **Create Habit3:**
   - Tap "+" button
   - Fill in details:
     - Name: "Habit3"
     - Type: Formation
     - Goal: "5 times per day"
   - Tap "Save"

5. **Watch console for THIS EXACT SEQUENCE:**

```
Expected Success Pattern:
==========================
🎯 [2/8] HomeView.onSave: received habit from CreateHabitFlowView
  → Habit: 'Habit3', ID: XXXXXXXX
🎯 [3/8] HomeViewState.createHabit: creating habit
🎯 [4/8] HomeViewState.createHabit: calling HabitRepository
🎯 [5/8] HabitRepository.createHabit: persisting habit
🎯 [6/8] HabitStore.createHabit: storing habit
🎯 [7/8] HabitStore.saveHabits: persisting 3 habits

💾 SAVE_START[abc12345]: Saving 3 habits
  [0] 'Habit1' (id: B4980CC0, syncStatus: pending)
  [1] 'Habit2' (id: 8EFC3071, syncStatus: pending)
  [2] 'Habit3' (id: XXXXXXXX, syncStatus: pending)
✅ SAVE_LOCAL[abc12345]: Successfully saved to SwiftData
🚀 SAVE_BACKGROUND[abc12345]: Launching background sync task...
✅ SAVE_COMPLETE[abc12345]: Returning to caller (background task still running)

📤 SYNC_START[abc12345]: Background task running, self=alive
📤 SYNC_FIRESTORE: Processing 3 habits
  → Checking 'Habit1' (syncStatus: pending, lastSynced: never)
  📤 SYNCING: 'Habit1' to Firestore...
  ✅ SUCCESS: 'Habit1' synced and status updated
  → Checking 'Habit2' (syncStatus: pending, lastSynced: never)
  📤 SYNCING: 'Habit2' to Firestore...
  ✅ SUCCESS: 'Habit2' synced and status updated
  → Checking 'Habit3' (syncStatus: pending, lastSynced: never)
  📤 SYNCING: 'Habit3' to Firestore...
  ✅ SUCCESS: 'Habit3' synced and status updated
📤 SYNC_COMPLETE: synced=3, skipped=0, failed=0
✅ SYNC_END[abc12345]: Background task complete
```

6. **❌ IF YOU SEE THESE - BUGS FOUND:**

```
Bug Pattern #1: self is NIL
=============================
📤 SYNC_START[abc12345]: Background task running, self=NIL!
❌ SYNC_FATAL[abc12345]: self is NIL! Sync will be skipped!
✅ SYNC_END[abc12345]: Background task complete

→ DIAGNOSIS: Task.detached deallocated before sync completed
→ CAUSE: DualWriteStorage instance released too early
→ FIX: Remove [weak self], use Task { } instead


Bug Pattern #2: Firestore Sync Failed
======================================
📤 SYNCING: 'Habit3' to Firestore...
❌ FAILED: 'Habit3' sync failed, error saved: [error details]
📤 SYNC_COMPLETE: synced=2, skipped=0, failed=1

→ DIAGNOSIS: Firestore API error
→ CAUSE: Check error message (auth? network? quota?)
→ FIX: Implement retry queue


Bug Pattern #3: Missing SYNC_END
=================================
🚀 SAVE_BACKGROUND[abc12345]: Launching background sync task...
✅ SAVE_COMPLETE[abc12345]: Returning to caller
[...no SYNC_START or SYNC_END logs...]

→ DIAGNOSIS: Background task never started
→ CAUSE: Task deallocated before execution
→ FIX: Remove Task.detached


Bug Pattern #4: Status Update Failed
=====================================
✅ SUCCESS: 'Habit3' synced and status updated

[But later when you reload:]

✅ DualWriteStorage: Loaded 2 habits from Firestore

→ DIAGNOSIS: Firestore says it synced, but not in database
→ CAUSE: createHabit() didn't actually save
→ FIX: Check FirestoreService.createHabit()
```

---

### **Test 2: Check What's Actually Stored**

After creating Habit3, **without restarting the app**:

1. **Go to More tab → Debug section**
2. **Tap "🔧 Fix Missing Baseline/Target"**
3. **Check console for:**

```
🔍 FIX_BASELINE: Found X habits in Firestore
   📋 Document IDs: [list of IDs]
   - 'Habit1' (ID: B4980CC0...)
   - 'Habit2' (ID: 8EFC3071...)
   - 'Habit3' (ID: XXXXXXXX...)  ← Should be here!
```

**If Habit3 is missing:**
→ Firestore sync failed or didn't run

**If Habit3 is there:**
→ Sync succeeded, but loading is broken

---

### **Test 3: Restart App and Watch Load**

1. **Force quit the app**
2. **Restart**
3. **Watch console for:**

```
DualWriteStorage: Loading habits
✅ DualWriteStorage: Loaded X habits from Firestore
🔄 LOAD_HABITS_COMPLETE: Loaded X habits
```

**Expected:** X = 3 (Habit1, Habit2, Habit3)
**If X = 2:** Habit3 was never synced to Firestore
**If X = 0:** All habits lost (migration status wrong)

---

### **Test 4: Check Local Storage**

Add this temporary debug code to `MoreTabView.swift`:

```swift
Button("🔍 Check Local Storage") {
  Task {
    let container = try await SwiftDataContainer.shared.container
    let context = container.mainContext
    let descriptor = FetchDescriptor<HabitData>()
    let habits = try context.fetch(descriptor)
    
    print("📊 LOCAL STORAGE CHECK:")
    print("   SwiftData has \(habits.count) habits:")
    for habit in habits {
      print("   - '\(habit.name)' (id: \(habit.id))")
    }
  }
}
```

**Expected:** 3 habits in SwiftData
**If missing:** Local write also failed (critical!)

---

## 🎯 What to Look For

### ✅ **Success Indicators:**
- ✅ All 3 habits in SwiftData
- ✅ All 3 habits in Firestore
- ✅ `self=alive` in background task
- ✅ `synced=3, failed=0`
- ✅ `SYNC_END` appears in console

### ❌ **Failure Indicators:**
- ❌ `self=NIL!` → Task deallocated bug
- ❌ `failed=1` or `failed=2` → Firestore API error
- ❌ Missing `SYNC_END` → Task interrupted
- ❌ Only 2 habits in Firestore → Sync failed silently
- ❌ 3 habits locally, 2 in Firestore → Background task skipped

---

## 📊 Report Template

After running tests, **copy and paste this filled out:**

```
DIAGNOSTIC REPORT: Habit3 Data Loss
====================================

Test 1: Console Logs During Creation
-------------------------------------
[Paste all console output from SAVE_START through SYNC_END]

Key Findings:
- self status: [alive / NIL]
- Habits saved locally: [count]
- Habits synced to Firestore: [count]
- Any errors: [yes/no, details]

Test 2: Firestore Check
------------------------
[Paste output from Fix Baseline/Target button]

Habits in Firestore: [count]
- Habit1: [yes/no]
- Habit2: [yes/no]
- Habit3: [yes/no]

Test 3: After Restart
----------------------
Habits loaded: [count]
Habit3 visible: [yes/no]

Root Cause Identified:
----------------------
[Based on patterns above, state which bug pattern matched]

Recommended Fix:
----------------
[Based on diagnosis]
```

---

## 🔧 Quick Fixes to Try

### **If self=NIL:**
```swift
// Change Task.detached to Task in DualWriteStorage.swift
Task { [primaryStorage] in  // Remove weak self
  await syncHabitsToFirestore(habits: updatedHabits, primaryStorage: primaryStorage)
}
```

### **If Firestore fails:**
Check error message:
- Auth error → Firebase auth expired
- Network error → No internet
- Quota error → Firebase free tier limit

### **If background task never runs:**
Add stronger reference:
```swift
let storage = self  // Keep strong reference
Task.detached { [primaryStorage] in
  await storage.syncHabitsToFirestore(...)
}
```

---

## 🎯 Expected Outcome

After running these tests, you'll know **EXACTLY** which bug is causing data loss:

1. **Task deallocated** → Fix: Remove `[weak self]`
2. **Firestore API error** → Fix: Implement retry queue
3. **Silent failure** → Fix: Change `try?` to `try`
4. **Skip optimization** → Fix: Remove 60s skip logic

**Run the tests and report back with the console output!** 🔍

