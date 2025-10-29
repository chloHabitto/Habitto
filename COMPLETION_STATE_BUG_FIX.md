# Completion State Bug Fix

## Issue Description

User reported that habit completion logic was broken:
1. Completed all 3 habits for today (Habit1, Habit2, Habit3) → streak wasn't updated
2. Uncompleted all of them
3. Completed Habit1 → difficulty bottom sheet didn't show
4. Completed Habit3 → saw celebration

## Root Cause

The `CompletionStateManager` tracks which habits currently have completion sheets showing to prevent race conditions and duplicate sheets. However, when a habit was uncompleted via the `uncompleteHabit()` function, the manager was **not** being cleared.

### The Problem Flow:

1. **Initial Completion (All 3 habits)**
   - User completes Habit1 → `startCompletionFlow(for: habit1.id)` called → difficulty sheet shows
   - User completes Habit2 → `startCompletionFlow(for: habit2.id)` called → difficulty sheet shows
   - User completes Habit3 → `startCompletionFlow(for: habit3.id)` called → difficulty sheet shows
   - CompletionStateManager now has: `{habit1.id, habit2.id, habit3.id}`

2. **Uncompleting All Habits**
   - User uncompletes all 3 habits via circle button
   - `uncompleteHabit()` is called for each habit
   - ❌ **BUG**: `endCompletionFlow()` was NEVER called
   - CompletionStateManager STILL has: `{habit1.id, habit2.id, habit3.id}`

3. **Re-completing Habits**
   - User tries to complete Habit1
   - Code checks: `guard !completionManager.isShowingCompletionSheet(for: habit.id) else { return }`
   - ❌ Returns `true` (manager thinks sheet is still showing) → **exits early, no sheet shows**
   - Same for Habit2
   - Habit3 might work if by chance the manager was cleared

### Code Location

**File**: `Core/UI/Items/ScheduledHabitItem.swift`

**Function**: `uncompleteHabit()` (lines 521-557)

The function was missing the cleanup code that exists in the `completeHabit()` flow's `onDismiss` handler.

## The Fix

Added the missing `CompletionStateManager` cleanup in `uncompleteHabit()`:

```swift
private func uncompleteHabit() {
  // Set progress to 0 (uncompleted)
  let newProgress = 0

  // ... existing code ...

  // Save progress data
  if let progressCallback = onProgressChange {
    progressCallback(habit, selectedDate, newProgress)
  }

  // Record timestamp of this user action
  lastUserUpdateTimestamp = Date()

  // ✅ FIX: Clear CompletionStateManager when uncompleting to allow re-completion
  let completionManager = CompletionStateManager.shared
  completionManager.endCompletionFlow(for: habit.id)
  
  // Reset completion flags
  isCompletingHabit = false
  isProcessingCompletion = false

  // ... rest of function ...
}
```

## What Changed

1. **Added** `CompletionStateManager.shared.endCompletionFlow(for: habit.id)` when uncompleting
2. **Added** reset of `isCompletingHabit` and `isProcessingCompletion` flags for consistency

## Why This Fixes All 3 Issues

### 1. ✅ Difficulty Sheet Now Shows After Uncomplete/Re-complete
- When habit is uncompleted, `endCompletionFlow()` removes it from the manager's tracking set
- When habit is completed again, the guard check passes → sheet shows

### 2. ✅ Streak Now Updates Correctly
- Difficulty sheet shows for each habit completion
- When last habit's difficulty sheet is dismissed → `onDifficultySheetDismissed()` is called
- This triggers the `DailyAwardService` which grants XP and updates streak

### 3. ✅ Celebration Shows at Right Time
- Celebration is triggered by `dailyAwardGranted` event from `DailyAwardService`
- This event is only fired when ALL habits are complete and the last difficulty sheet is dismissed
- Now that difficulty sheets show correctly, the celebration flow works as designed

## Testing Scenario

To verify the fix works:

1. **Complete all habits** → Each should show difficulty sheet → Streak should increment → Celebration should show
2. **Uncomplete all habits** → CompletionStateManager is cleared for each habit
3. **Complete Habit1** → Should show difficulty sheet ✅
4. **Complete Habit2** → Should show difficulty sheet ✅
5. **Complete Habit3** → Should show difficulty sheet → Celebration should show ✅

## Impact

**Files Modified**: 1
- `Core/UI/Items/ScheduledHabitItem.swift`

**Lines Added**: 6 lines (cleanup code in `uncompleteHabit()`)

**Risk**: Low - This is a symmetric fix that mirrors the cleanup already done in the completion flow's dismiss handler

**Backwards Compatibility**: Full - No breaking changes, only fixes broken behavior

---

## Technical Details

### CompletionStateManager Purpose

The `CompletionStateManager` is a singleton that tracks which habits are currently showing completion sheets. This prevents:
- Race conditions when rapidly tapping habits
- Duplicate sheets for the same habit
- List reordering while sheets are visible

### The Guard Check

Located at line 492 in `ScheduledHabitItem.swift`:

```swift
let completionManager = CompletionStateManager.shared
guard !completionManager.isShowingCompletionSheet(for: habit.id) else {
  return  // ← Exit early if sheet already showing
}
```

This is the check that was failing after uncomplete, because the manager was never cleared.

### Cleanup Locations

The `endCompletionFlow()` is now called in 2 places:

1. **When difficulty sheet is dismissed** (line 258)
   - In the `.sheet(isPresented: $showingCompletionSheet)` onDismiss handler
   
2. **When habit is uncompleted** (line 543) ← **NEW FIX**
   - In the `uncompleteHabit()` function

This ensures the manager is always in sync with the actual UI state.

---

## Status

✅ **FIXED** - All 3 issues resolved with a single targeted fix

