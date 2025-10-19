# 🐛 Double-Click & Refresh Race Condition Bug

## Problem Description

When completing a habit (especially Breaking habits) by clicking the circle button:
1. **First click doesn't always register** - requires a second click to mark as complete
2. **After refresh, habit reverts to incomplete** - even though it was just marked as complete
3. **Affects Breaking habits more than Formation habits** - due to different persistence timing

## Root Cause Analysis

### The Race Condition

The bug is a classic race condition in the data flow:

```
User Action (Click) → Local UI Update → Background Persistence
                          ↓
                    Notification Broadcast
                          ↓
                    Other UI Components Listen
                          ↓
                    Read Data (potentially stale!)
```

### Specific Issues

1. **Immediate Notification, Delayed Persistence**
   - `HabitRepository.setProgress()` (line 763-766) posts `habitProgressUpdated` notification IMMEDIATELY
   - But actual persistence happens asynchronously in a background Task (line 771-794)
   - UI components receive the notification before persistence completes
   
2. **Missing Timestamp Check in `onReceive` Listener**
   - `ScheduledHabitItem.swift` has `onChange(of: habit.completionHistory)` with timestamp protection (lines 194-209)
   - `ScheduledHabitItem.swift` has `onChange(of: habit)` with timestamp protection (lines 210-228)
   - BUT `onReceive(NotificationCenter...habitProgressUpdated)` (lines 229-242) is **MISSING** the timestamp check!
   - This allows the notification to override local UI state before persistence completes

3. **Timing Window**
   - User clicks → `isLocalUpdateInProgress = true` (0.5s window)
   - Background persistence starts (can take 300-1000ms+)
   - Notification fires → triggers `onReceive` → reads potentially stale data
   - If notification arrives after 0.5s but before persistence completes → UI reverts!

### Why Breaking Habits Are More Affected

Breaking habits may have more complex persistence logic due to:
- Checking `actualUsage` vs `target`
- Dual storage (Firestore + SwiftData)
- Additional validation for "breaking" completion criteria

## The Fix

### Step 1: Add Timestamp Check to `onReceive` Listener

In `Core/UI/Items/ScheduledHabitItem.swift`, update the `onReceive` listener to respect the `lastUserUpdateTimestamp`:

```swift
.onReceive(NotificationCenter.default.publisher(for: .habitProgressUpdated)) { notification in
  // Don't override local updates that are in progress
  guard !isLocalUpdateInProgress else { return }

  // ✅ FIX: If user just made a change, wait longer before accepting external updates
  if let lastUpdate = lastUserUpdateTimestamp,
     Date().timeIntervalSince(lastUpdate) < 1.0 {
    print("🔍 RACE FIX: Ignoring habitProgressUpdated notification within 1s of user action")
    return
  }

  // Listen for habit progress updates from the repository
  if let updatedHabitId = notification.userInfo?["habitId"] as? UUID,
     updatedHabitId == habit.id
  {
    let newProgress = habit.getProgress(for: selectedDate)
    withAnimation(.easeInOut(duration: 0.2)) {
      currentProgress = newProgress
    }
  }
}
```

### Step 2: Verify Existing Protections Are in Place

Confirm these existing fixes are properly implemented:
- ✅ `isLocalUpdateInProgress` flag with 0.5s delay
- ✅ `lastUserUpdateTimestamp` tracking in all user action functions
- ✅ Timestamp checks in `onChange(of: habit.completionHistory)` 
- ✅ Timestamp checks in `onChange(of: habit)`

## Testing the Fix

### Test Case 1: Breaking Habit Single Click
1. Create a Breaking habit (e.g., "Reduce coffee" baseline 5, target 3)
2. Click the completion circle once
3. **Expected**: Marks complete immediately, stays complete
4. **Previously**: Required second click

### Test Case 2: Refresh Persistence
1. Complete any habit (especially Breaking)
2. Force refresh the app (swipe up, reopen)
3. **Expected**: Habit remains complete after refresh
4. **Previously**: Reverted to incomplete

### Test Case 3: Multiple Habits Rapid Completion
1. Have 3-4 habits scheduled for today
2. Rapidly click completion circles in succession
3. **Expected**: All mark complete correctly without conflicts
4. **Previously**: Some might not save or revert

## Technical Details

### Files Modified
- `Core/UI/Items/ScheduledHabitItem.swift` - Added timestamp check to `onReceive` listener

### Timing Constants
- `isLocalUpdateInProgress` window: **0.5 seconds** (increased from 0.1s)
- `lastUserUpdateTimestamp` grace period: **1.0 seconds**
- These provide a 1.5s total protection window for async persistence

### Debug Logs Added
```
🔍 RACE FIX: Ignoring habitProgressUpdated notification within 1s of user action
🔍 RACE FIX: Ignoring completionHistory update within 1s of user action
🔍 RACE FIX: Ignoring habit update within 1s of user action
```

## Related Issues

This fix also prevents:
- Progress bar flickering during completion
- Inconsistent XP awards (if completion reverts before XP calculation)
- Streak calculation errors (if completion state is unstable)
- Celebration triggering then canceling (if habit completes then uncompletes)

## Implementation Status

- [x] Root cause identified
- [ ] Fix implemented in ScheduledHabitItem.swift
- [ ] Testing completed
- [ ] Verified on Breaking habits
- [ ] Verified on Formation habits
- [ ] Edge cases tested (rapid clicks, slow network, etc.)

---

**Date**: October 18, 2025  
**Severity**: High - Affects data integrity and user trust  
**Impact**: All habit types, but Breaking habits more affected  
**Fix Complexity**: Low - Single line addition with timestamp check
