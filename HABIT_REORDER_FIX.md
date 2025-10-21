# Habit Reordering Bug Fix

## Problem

After completing a habit and dismissing the difficulty bottom sheet, the completed habit was not moving to the bottom of the list immediately. It only moved after refreshing the view (e.g., switching tabs).

## Root Cause

The issue was in the `HomeTabView.swift` file. The `resortHabits()` function relies on `completionStatusMap` to determine which habits are completed and should be moved to the bottom.

**The bug**: `completionStatusMap` was stale. It was populated earlier by `prefetchCompletionStatus()` but was never refreshed after a habit was completed. When `resortHabits()` was called 1 second after the difficulty sheet was dismissed, it used the old map that still showed the completed habit as incomplete.

### Evidence from Logs

```
🔄 COMPLETION_FLOW: 1 second passed, now resorting...
🔄 resortHabits() called - deferResort: false
   ✅ resortHabits() proceeding...
   ✅ resortHabits() completed - sortedHabits count: 2
      [0] Habit1 - completed: false  ⚠️ WRONG! (should be true)
      [1] Habit2 - completed: false
```

## Solution

In the `onDifficultySheetDismissed()` method, we now refresh the `completionStatusMap` by calling `prefetchCompletionStatus()` BEFORE calling `resortHabits()`.

### Changes Made

**File**: `/Users/chloe/Desktop/Habitto/Views/Tabs/HomeTabView.swift`

**Function**: `onDifficultySheetDismissed()`

**Change**:
```swift
// Before (lines 1388-1395):
try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

print("🔄 COMPLETION_FLOW: 1 second passed, now resorting...")
print("   Setting deferResort = false")
deferResort = false

print("   Calling resortHabits()...")
resortHabits()

// After (lines 1388-1401):
try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

print("🔄 COMPLETION_FLOW: 1 second passed, now resorting...")

// ✅ FIX: Refresh completion status map BEFORE resorting
print("   Refreshing completionStatusMap...")
await prefetchCompletionStatus()
print("   ✅ completionStatusMap refreshed")

print("   Setting deferResort = false")
deferResort = false

print("   Calling resortHabits()...")
resortHabits()
```

## Expected Behavior After Fix

1. User completes Habit1 (swipe right to goal)
2. Difficulty bottom sheet appears
3. User selects difficulty and dismisses sheet
4. **After 1 second**:
   - `completionStatusMap` is refreshed with current completion status
   - `resortHabits()` is called with accurate data
   - Habit1 moves to the bottom of the list (completed habits have lower priority)
   - Habit2 (incomplete) stays at the top

## Testing

1. Build and run the app (Cmd+R)
2. Complete Habit1 by tapping to reach goal (10/10)
3. Select a difficulty (e.g., "Medium") and dismiss the sheet
4. **Wait 1 second**
5. Observe: Habit1 should smoothly move to the bottom
6. Check console logs for:
   ```
   🔄 COMPLETION_FLOW: 1 second passed, now resorting...
      Refreshing completionStatusMap...
   ✅ HomeTabView: Prefetched completion status for 2 habits from local data
      ✅ completionStatusMap refreshed
      Setting deferResort = false
      Calling resortHabits()...
   🔄 resortHabits() called - deferResort: false
      ✅ resortHabits() proceeding...
      ✅ resortHabits() completed - sortedHabits count: 2
         [0] Habit2 - completed: false
         [1] Habit1 - completed: true  ✅ CORRECT!
   ```

## Related Files

- `/Users/chloe/Desktop/Habitto/Views/Tabs/HomeTabView.swift` - Contains the fix
- `/Users/chloe/Desktop/Habitto/FIREBASE_INIT_CRASH_FIX.md` - Previous fix for Firebase initialization

## Status

✅ **FIXED** - Habit reordering now works correctly after difficulty sheet dismissal.

---

**Date**: October 21, 2025
**Fix Applied**: Lines 1392-1395 in `HomeTabView.swift`
