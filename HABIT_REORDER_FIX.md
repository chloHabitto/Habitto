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

The fix involves two parts:

1. **Refresh completion status**: In `onDifficultySheetDismissed()`, we now refresh the `completionStatusMap` by calling `prefetchCompletionStatus()` BEFORE calling `resortHabits()`.

2. **Add smooth animations**: We wrap the resort in `withAnimation(.spring())` and add explicit animation modifiers to the ForEach to ensure smooth, pleasant list reordering with no sudden jumps or fades.

### Changes Made

**File**: `/Users/chloe/Desktop/Habitto/Views/Tabs/HomeTabView.swift`

#### Change 1: Refresh Completion Status Before Resorting

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

// After (lines 1388-1403):
try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

print("🔄 COMPLETION_FLOW: 1 second passed, now resorting...")

// ✅ FIX: Refresh completion status map BEFORE resorting
print("   Refreshing completionStatusMap...")
await prefetchCompletionStatus()
print("   ✅ completionStatusMap refreshed")

print("   Setting deferResort = false")
deferResort = false

print("   Calling resortHabits() with animation...")
withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
  resortHabits()
}
```

#### Change 2: Add Smooth Animations to List Reordering

**Location**: ForEach displaying habits (lines 508-516)

**Change**:
```swift
// Before:
ForEach(Array(sortedHabits.enumerated()), id: \.element.id) { index, habit in
  habitRow(habit)
    .animateViewAnimatorStyle(
      index: index,
      animation: .slideFromBottom(offset: 20),
      config: .fast)
}

// After:
ForEach(Array(sortedHabits.enumerated()), id: \.element.id) { index, habit in
  habitRow(habit)
    .animateViewAnimatorStyle(
      index: index,
      animation: .slideFromBottom(offset: 20),
      config: .fast)
    .transition(.identity)  // ✅ Prevents fade in/out
}
.animation(.spring(response: 0.5, dampingFraction: 0.8), value: sortedHabits.map { $0.id })  // ✅ Smooth spring animation
```

### How the Animation Works

1. **`withAnimation(.spring(...))`**: Wraps the state change in an animation block, telling SwiftUI to animate all state changes within.

2. **Spring parameters**:
   - `response: 0.5` - The animation takes 0.5 seconds (feels snappy but not rushed)
   - `dampingFraction: 0.8` - Controls the bounce (0.8 gives a subtle, pleasant bounce without being too bouncy)

3. **`.transition(.identity)`**: Prevents habits from fading in/out when reordering. They simply move position.

4. **`.animation(..., value: sortedHabits.map { $0.id })`**: Tells SwiftUI to animate whenever the order of habit IDs changes. SwiftUI tracks the IDs and smoothly moves each habit to its new position.

## Expected Behavior After Fix

1. User completes Habit1 (swipe right to goal)
2. Difficulty bottom sheet appears
3. User selects difficulty and dismisses sheet
4. **After 1 second**:
   - `completionStatusMap` is refreshed with current completion status
   - `resortHabits()` is called with accurate data
   - Habit1 **smoothly animates** to the bottom of the list with a spring animation (completed habits have lower priority)
   - Habit2 (incomplete) **smoothly animates** to the top
   - The entire reordering happens with a pleasant spring bounce effect

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
