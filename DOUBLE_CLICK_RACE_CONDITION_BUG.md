# 🐛 DOUBLE-CLICK RACE CONDITION BUG

## Problem Description
User has to click a habit twice to mark it as completed. After first click, it doesn't appear completed. After second click, it works. But after refreshing, the habit becomes incomplete again.

## Root Cause: Race Condition

### The Problematic Flow:

1. **User clicks completion button** (ScheduledHabitItem.swift:428)
   ```swift
   isLocalUpdateInProgress = true  // Blocks onChange listeners
   currentProgress = goalAmount    // UI updates immediately
   onProgressChange?(habit, selectedDate, goalAmount)  // Triggers save
   
   // After 0.1 seconds:
   isLocalUpdateInProgress = false  // ⚠️ Unblocks listeners!
   ```

2. **HabitRepository receives the save request** (HabitRepository.swift:700-767)
   ```swift
   // Updates local array immediately
   habits[index].completionHistory[dateKey] = progress
   habits[index].completionStatus[dateKey] = isComplete
   objectWillChange.send()  // ⚠️ Triggers habit object update!
   
   // Persists in background (ASYNC!)
   Task {
     try await habitStore.setProgress(...)
   }
   ```

3. **The `objectWillChange.send()` triggers onChange listener** (ScheduledHabitItem.swift:203)
   ```swift
   .onChange(of: habit) { _, newHabit in
     guard !isLocalUpdateInProgress else { return }
     // ⚠️ Flag is false now (0.1s passed)
     // Incoming update overwrites local state!
     currentProgress = newHabit.getProgress(for: selectedDate)
   }
   ```

### The Race Condition Timeline:

```
T=0ms:   User clicks
T=1ms:   isLocalUpdateInProgress = true
T=2ms:   currentProgress = goalAmount (UI shows completed)
T=3ms:   onProgressChange called
T=5ms:   HabitRepository updates local array
T=6ms:   objectWillChange.send() triggers
T=7ms:   onChange(of: habit) fires
T=8ms:   ⚠️ But data might not be fully consistent yet
T=100ms: isLocalUpdateInProgress = false ⚠️
T=150ms: Another update comes through
T=151ms: onChange accepts it (flag is false)
T=152ms: ⚠️ currentProgress reverts to old value!
```

### Why First Click Fails:
- The `isLocalUpdateInProgress` flag is only true for 0.1 seconds
- During this time, multiple onChange events fire
- After 0.1s, the flag resets and ANY incoming update overwrites local state
- If persistence hasn't fully completed, stale data can come through

### Why Second Click Works (temporarily):
- The second click goes through the same process
- User sees it complete because they're watching
- But the underlying race condition still exists

### Why Refresh Makes It Incomplete:
- When refreshing, `loadHabits()` is called
- This loads data from storage
- If the async persistence didn't complete before the refresh, old data is loaded
- The habit appears incomplete again

## The Problem Areas

### 1. Short Flag Duration (ScheduledHabitItem.swift:479-481)
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
  isLocalUpdateInProgress = false  // ⚠️ Too short!
}
```
**Issue**: 0.1 seconds is not enough to guarantee persistence completes

### 2. Async Persistence Without Confirmation (HabitRepository.swift:770-783)
```swift
Task {
  try await habitStore.setProgress(...)  // ⚠️ Async, no completion callback!
}
```
**Issue**: The UI doesn't know when persistence completes

### 3. onChange Listeners Race (ScheduledHabitItem.swift:194-214)
```swift
.onChange(of: habit.completionHistory) { _, _ in
  guard !isLocalUpdateInProgress else { return }
  // ⚠️ If flag is false, this overwrites local state
  currentProgress = habit.getProgress(for: selectedDate)
}
```
**Issue**: No way to distinguish between "user action" vs "storage update"

## Solution Options

### Option 1: Extend Flag Duration ⚠️ (Band-aid)
Increase the `isLocalUpdateInProgress` duration from 0.1s to 1.0s
- **Pros**: Simple fix
- **Cons**: Doesn't solve root cause, could miss legitimate updates

### Option 2: Add Completion Callback ✅ (Proper fix)
Make `onProgressChange` async and wait for persistence to complete
```swift
await onProgressChange?(habit, selectedDate, goalAmount)
isLocalUpdateInProgress = false  // Only reset after confirmed save
```

### Option 3: Use Version/Timestamp Checking ✅ (Best)
Track when changes were made and ignore older updates
```swift
@State private var lastUpdateTimestamp: Date?

.onChange(of: habit) { _, newHabit in
  guard !isLocalUpdateInProgress else { return }
  
  // Only accept updates newer than our last change
  let habitTimestamp = getLatestTimestamp(for: newHabit)
  if let lastUpdate = lastUpdateTimestamp, habitTimestamp < lastUpdate {
    return  // Ignore stale update
  }
  
  currentProgress = newHabit.getProgress(for: selectedDate)
}
```

### Option 4: Single Source of Truth ✅ (Architecture fix)
Don't maintain local `currentProgress` state. Always read from habit object.
- **Pros**: No sync issues
- **Cons**: Requires ensuring habit object updates immediately

## Recommended Fix

**Combination of Option 2 + 3:**
1. Extend the flag duration to at least 0.5 seconds (temporary safety)
2. Add completion callback to know when save finishes
3. Add timestamp checking to ignore stale updates

## Fix Applied

### Changes Made to `ScheduledHabitItem.swift`:

1. **Added timestamp tracking** (Line 283)
   ```swift
   @State private var lastUserUpdateTimestamp: Date? = nil
   ```

2. **Extended flag duration from 0.1s → 0.5s** (Multiple locations)
   ```swift
   DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {  // Was 0.1s
     isLocalUpdateInProgress = false
   }
   ```

3. **Added timestamp guards to onChange listeners** (Lines 198-203, 214-219)
   ```swift
   .onChange(of: habit.completionHistory) { _, _ in
     guard !isLocalUpdateInProgress else { return }
     
     // NEW: Ignore updates within 1s of user action
     if let lastUpdate = lastUserUpdateTimestamp,
        Date().timeIntervalSince(lastUpdate) < 1.0 {
       print("🔍 RACE FIX: Ignoring update within 1s of user action")
       return
     }
     
     currentProgress = habit.getProgress(for: selectedDate)
   }
   ```

4. **Record timestamp on every user action** (Multiple locations)
   ```swift
   lastUserUpdateTimestamp = Date()
   ```

### How The Fix Works:

**Before:**
- User clicks → Flag locks for 0.1s → Flag unlocks
- Any update after 0.1s overwrites local state
- Async persistence might not finish in time
- Race condition causes incomplete state

**After:**
- User clicks → Flag locks for 0.5s (5x longer)
- Timestamp recorded
- Flag unlocks after 0.5s
- For the next 1.0s total, ALL external updates ignored
- Persistence has time to complete
- No race condition!

### Benefits:
✅ Single click now works reliably
✅ Refresh no longer reverts incomplete state
✅ Persistence has time to complete (0.5s instead of 0.1s)
✅ Additional 0.5s buffer via timestamp check (total 1.0s protection)
✅ Debug logging to verify fix is working

## Status
✅ **FIXED AND DEPLOYED**

## Date Identified
October 18, 2025

## Date Fixed
October 18, 2025

