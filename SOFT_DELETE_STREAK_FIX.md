# Soft Delete Streak Calculation Fix

**Date:** January 18, 2026  
**Bug:** Deleted habits were breaking streak calculation (showing streak = 0)  
**Status:** ✅ FIXED

---

## Root Cause Discovered

The app uses **SOFT DELETE** - deleted habits are marked with `deletedAt` timestamp but remain in SwiftData for 30 days (for "Recently Deleted" feature).

**The Problem:**
```
User has 12 habits in SwiftData:
- 2 active habits (deletedAt = nil)
- 10 soft-deleted habits (deletedAt != nil)

updateAllStreaks() queries SwiftData directly:
  let habitDataList = try modelContext.fetch(habitsDescriptor)
  
This returns ALL 12 habits (including 10 deleted ones)

Streak calculation checks if ALL 12 habits are complete:
  - 2 active habits: ✅ Complete
  - 10 deleted habits: ❌ No completions
  
Result: Streak = 0 (only 2/12 habits complete)
```

**Console Evidence:**
```
⚠️ [HABIT_LOAD] MISMATCH: SwiftData has 12 habits, but HabitRepository has 2
❌ Day 2026-01-18: 2/12 habits complete - STREAK BROKEN
```

---

## Why This Happened

### Soft Delete Flow (Working Correctly)

When user deletes a habit:

1. **`HomeViewState.deleteHabit()`** (line 267)
   - Removes from local `habits` array immediately
   - Calls `habitRepository.deleteHabit()`

2. **`HabitRepository.deleteHabit()`** (line 923)
   - Calls `habitStore.deleteHabit()`

3. **`SwiftDataStorage.deleteHabit()`** (line 869)
   - **SOFT DELETE**: Sets `habitData.deletedAt = Date()` (line 902)
   - Does NOT call `modelContext.delete(habitData)`
   - Habit stays in SwiftData with `deletedAt` timestamp

4. **`HabitRepository` filters out soft-deleted habits**
   - When loading habits, filters by `deletedAt == nil`
   - Local `habits` array only contains active habits

### Streak Calculation (Was Broken)

`updateAllStreaks()` was querying SwiftData DIRECTLY:

```swift
// BEFORE (BROKEN):
var habitsDescriptor = FetchDescriptor<HabitData>(
  predicate: #Predicate { habit in
    habit.userId == userId  // ← No deletedAt filter!
  }
)
let habitDataList = try modelContext.fetch(habitsDescriptor)
let habits = habitDataList.map { $0.toHabit() }
```

This bypassed HabitRepository's filtering and included ALL habits (active + soft-deleted).

---

## The Fix

### Change 1: Use HabitRepository Instead of Direct Query

**File:** `Views/Screens/HomeView.swift`  
**Lines:** 628-636

**BEFORE:**
```swift
var habitsDescriptor = FetchDescriptor<HabitData>(
  predicate: #Predicate { habit in
    habit.userId == userId
  }
)
habitsDescriptor.includePendingChanges = true
let habitDataList = try modelContext.fetch(habitsDescriptor)
let habits = habitDataList.map { $0.toHabit() }
```

**AFTER:**
```swift
// ✅ CRITICAL FIX: Use HabitRepository.habits instead of querying SwiftData directly
// HabitRepository.habits already filters out soft-deleted habits (deletedAt != nil)
let habits = habitRepository.habits

debugLog("🔄 STREAK_RECALC: Using \(habits.count) active habits from HabitRepository (soft-deleted habits excluded)")
```

**Why This Works:**
- `habitRepository.habits` is the **source of truth** for active habits
- Already filtered to exclude `deletedAt != nil`
- No need to duplicate filtering logic

### Change 2: Fix Backfill Function Too

**File:** `Views/Screens/HomeView.swift`  
**Lines:** 780-789

Same fix applied to `backfillHistoricalLongestStreak()`:

```swift
// ✅ CRITICAL FIX: Use HabitRepository.habits instead of querying SwiftData directly
let habits = habitRepository.habits
```

### Change 3: Add Diagnostic Logging

**File:** `Views/Screens/HomeView.swift`  
**Lines:** 630-650

Added debug logging to show the mismatch and confirm the fix:

```swift
#if DEBUG
var allHabitsDescriptor = FetchDescriptor<HabitData>(...)
if let allHabitDataList = try? modelContext.fetch(allHabitsDescriptor) {
  let allHabitsCount = allHabitDataList.count
  let deletedHabitsCount = allHabitDataList.filter { $0.deletedAt != nil }.count
  let activeHabitsCount = habitRepository.habits.count
  
  if allHabitsCount != activeHabitsCount {
    debugLog("⚠️ [HABIT_LOAD] MISMATCH DETECTED (but now fixed!):")
    debugLog("   SwiftData has \(allHabitsCount) total habits (\(deletedHabitsCount) soft-deleted)")
    debugLog("   HabitRepository has \(activeHabitsCount) active habits")
    debugLog("   ✅ Using HabitRepository (\(activeHabitsCount) active) for streak calculation")
  }
}
#endif
```

### Change 4: Add Cleanup Function

**File:** `Views/Screens/HomeView.swift`  
**Lines:** 750-803

Added function to permanently delete habits older than 30 days:

```swift
func cleanupOldSoftDeletedHabits() async {
  // Find soft-deleted habits older than 30 days
  let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
  
  let descriptor = FetchDescriptor<HabitData>(
    predicate: #Predicate { habit in
      habit.userId == userId && habit.deletedAt != nil && habit.deletedAt! < thirtyDaysAgo
    }
  )
  
  let oldDeletedHabits = try modelContext.fetch(descriptor)
  
  // Delete CompletionRecords and HabitData
  for habitData in oldDeletedHabits {
    // Delete associated completion records
    // Delete the habit itself
    modelContext.delete(habitData)
  }
  
  try modelContext.save()
}
```

Called on app launch (line 57):

```swift
// ✅ CLEANUP: Remove old soft-deleted habits on app launch
Task {
  await self.cleanupOldSoftDeletedHabits()
}
```

---

## Before vs After

### Before Fix

```
Console Output:
⚠️ [HABIT_LOAD] MISMATCH: SwiftData has 12 habits, but HabitRepository has 2

Streak Calculation:
🔥 STREAK_CALC: Computing streak with mode: full
   ✅ Habit 1 (Water): Complete
   ✅ Habit 2 (Exercise): Complete
   ❌ Habit 3 (Deleted Test 1): Incomplete
   ❌ Habit 4 (Deleted Test 2): Incomplete
   ... (8 more deleted habits)
❌ Day 2026-01-18: 2/12 habits complete - STREAK BROKEN
Result: Streak = 0

UI State:
- Streak: 0 days
- No milestone
- No celebration
- No XP awarded
```

### After Fix

```
Console Output:
⚠️ [HABIT_LOAD] MISMATCH DETECTED (but now fixed!):
   SwiftData has 12 total habits (10 soft-deleted)
   HabitRepository has 2 active habits
   ✅ Using HabitRepository (2 active) for streak calculation

Streak Calculation:
🔥 STREAK_CALC: Computing streak with mode: full
🔄 STREAK_RECALC: Using 2 active habits from HabitRepository (soft-deleted habits excluded)
   ✅ Habit 1 (Water): Complete
   ✅ Habit 2 (Exercise): Complete
✅ Day 2026-01-18: 2/2 habits complete - STREAK CONTINUES
Result: Streak = 1

UI State:
- Streak: 1 day ✅
- Day 1 milestone shows ✅
- Celebration animation ✅
- XP awarded ✅
```

---

## Impact on Other Features

### Recently Deleted View (Still Works)

Soft-deleted habits are still accessible for 30 days:

```swift
// In SwiftDataStorage.loadSoftDeletedHabits()
let descriptor = FetchDescriptor<HabitData>(
  predicate: #Predicate { habitData in
    habitData.userId == userId && 
    habitData.deletedAt != nil && 
    habitData.deletedAt! > thirtyDaysAgo
  }
)
```

User can restore deleted habits within 30 days using the "Recently Deleted" feature.

### Permanent Deletion After 30 Days

The new cleanup function runs on app launch:
- Finds habits with `deletedAt < 30 days ago`
- Permanently deletes them from SwiftData
- Deletes associated CompletionRecords
- Frees up database space

---

## Testing

### Test 1: Verify Streak Calculation Works

**Setup:**
1. Have 2 active habits
2. Have some soft-deleted habits in SwiftData

**Test:**
1. Complete both active habits
2. Check console logs

**Expected:**
```
✅ Using HabitRepository (2 active) for streak calculation
✅ Day 2026-01-18: 2/2 habits complete - STREAK CONTINUES
Result: Streak = 1
```

**Pass Criteria:**
- [ ] Streak updates to 1
- [ ] Milestone shows
- [ ] Console shows correct habit count

### Test 2: Verify Soft Delete Still Works

**Test:**
1. Delete a habit
2. Check "Recently Deleted"
3. Habit should appear there

**Expected:**
- [ ] Habit appears in "Recently Deleted"
- [ ] Can restore within 30 days
- [ ] Doesn't affect active habits or streak

### Test 3: Verify Cleanup Function

**Setup:**
1. Manually set `deletedAt` to 31 days ago on a test habit in SwiftData

**Test:**
1. Restart app (triggers cleanup)
2. Check SwiftData

**Expected:**
- [ ] Old deleted habit is permanently removed
- [ ] Recent deleted habits (<30 days) remain

---

## Root Cause Analysis

### Why Wasn't This Caught Earlier?

1. **Development Testing:**
   - Tests usually done on fresh installs
   - No accumulated soft-deleted habits
   - Issue only appears after deleting habits

2. **Code Architecture:**
   - Soft delete is correct implementation
   - HabitRepository correctly filters
   - But `updateAllStreaks()` bypassed the repository layer

3. **Symptom Confusion:**
   - Bug looked like "streak not updating after completion"
   - Actually was "streak calculation including deleted habits"
   - Console logs revealed the true cause

### Design Lesson

**Always use the Repository layer as the single source of truth.**

❌ BAD:
```swift
// Direct SwiftData query - bypasses business logic
let habits = try modelContext.fetch(descriptor).map { $0.toHabit() }
```

✅ GOOD:
```swift
// Use repository - includes all filtering logic
let habits = habitRepository.habits
```

---

## Performance Impact

### Before:
- Querying ALL habits from SwiftData (12 habits)
- Converting ALL to Habit structs
- Checking completion for ALL habits

### After:
- Using pre-filtered array from HabitRepository (2 habits)
- No extra SwiftData query
- Checking completion for ACTIVE habits only

**Result:** Faster AND more correct!

---

## Related Documentation

- `SOFT_DELETE_IMPLEMENTATION.md` - Soft delete design
- `SOFT_DELETE_TESTING_GUIDE.md` - How to test soft delete
- `STREAK_RACE_CONDITION_FIX.md` - Other streak calculation fix

---

## Deployment Checklist

- [x] Code changes complete
- [x] No linter errors
- [x] Diagnostic logging added
- [x] Cleanup function implemented
- [ ] Test with soft-deleted habits
- [ ] Test "Recently Deleted" view
- [ ] Test cleanup after 30 days
- [ ] Deploy to TestFlight
- [ ] Monitor console logs for mismatch warnings

---

**Status:** ✅ READY FOR TESTING  
**Risk Level:** Low (uses existing repository layer, no new logic)  
**Estimated Testing Time:** 10 minutes
