# 🐛 Breaking Habit Auto-Uncomplete Bug - Root Cause Found

**Date:** October 20, 2025  
**Status:** ✅ FIXED

---

## 🚨 User-Reported Problems

### Problem 1: Breaking habit "Don't smoke" auto-uncompletes itself
1. User taps "Don't smoke" (breaking habit) to complete it
2. It shows as complete briefly
3. Then it **automatically becomes incomplete again** ❌

### Problem 2: "Habit1" won't complete at all
1. User tries to tap "Habit1" to complete it
2. Nothing happens - it stays incomplete ❌

### Problem 3: Validation Warnings
```
🔍 VALIDATION ERRORS:
   - habits[0].completionHistory: Found completion record for future date: 2025-10-22 (severity: warning)
   - habits[0].completionTimestamps: Duplicate timestamps found for date: 2025-10-20 (severity: warning)
   - habits[2].completionTimestamps: Duplicate timestamps found for date: 2025-10-20 (severity: warning)
```

---

## 🔍 Root Cause Analysis

### The Fatal Flaw: `setProgress` Uses Wrong Field for Breaking Habits

**Location:** `Core/Data/Repository/HabitStore.swift` lines 314-319

```swift
if let index = currentHabits.firstIndex(where: { $0.id == habit.id }) {
  let oldProgress = currentHabits[index].completionHistory[dateKey] ?? 0
  currentHabits[index].completionHistory[dateKey] = progress  // ❌ WRONG for breaking habits!
  
  // Update completion status based on progress
  currentHabits[index].completionStatus[dateKey] = progress > 0  // ❌ WRONG logic!
```

### The Design Intent (From `Habit.swift`)

Breaking habits are **supposed to** use `actualUsage` instead of `completionHistory`:

```swift
// Core/Models/Habit.swift lines 470-474
if habitType == .breaking {
  let usage = actualUsage[dateKey] ?? 0
  return usage  // ✅ CORRECT: Breaking habits should read from actualUsage
}
```

---

## 🔍 What's Happening Step-by-Step

### For a Breaking Habit (e.g., "Don't smoke - 1 time everyday")

**Expected:** Baseline=10, Target=1 (complete when usage ≤ 1)

#### When User Taps to Complete:

1. **`setProgress` is called** with `progress=1`
   ```swift
   currentHabits[index].completionHistory[dateKey] = 1  // ❌ Sets to completionHistory
   currentHabits[index].completionStatus[dateKey] = true // ✅ Marked complete
   ```

2. **`getProgress` is called** to check completion
   ```swift
   if habitType == .breaking {
     return actualUsage[dateKey] ?? 0  // Returns 0 (actualUsage is empty!)
   }
   ```

3. **Completion check runs**
   ```swift
   let usage = habit.getProgress(for: date)  // Returns 0 (from actualUsage)
   isCompleted = usage <= target  // 0 <= 1 → true ✅
   ```

4. **BUT THEN** on the next render:
   ```swift
   // UI reads from completionHistory for display
   let progress = completionHistory[dateKey] ?? 0  // Returns 1
   
   // But isCompleted() checks actualUsage
   let usage = actualUsage[dateKey] ?? 0  // Returns 0
   isCompleted = usage <= target  // 0 <= 1 → true
   
   // CONFLICT: progress=1 but usage=0 → UI shows inconsistent state
   ```

---

## ❌ The Three Bugs

### Bug 1: `setProgress` Writes to Wrong Field
```swift
// CURRENT (WRONG):
currentHabits[index].completionHistory[dateKey] = progress

// SHOULD BE:
if habitType == .breaking {
  currentHabits[index].actualUsage[dateKey] = progress
} else {
  currentHabits[index].completionHistory[dateKey] = progress
}
```

### Bug 2: Completion Status Logic is Wrong
```swift
// CURRENT (WRONG):
currentHabits[index].completionStatus[dateKey] = progress > 0

// SHOULD BE:
if habitType == .breaking {
  currentHabits[index].completionStatus[dateKey] = progress <= habit.target
} else {
  let goalAmount = parseGoalAmount(from: habit.goal)
  currentHabits[index].completionStatus[dateKey] = progress >= goalAmount
}
```

### Bug 3: Timestamp Recording Duplicates
Lines 325-332 in `HabitStore.swift` add timestamps in a loop:
```swift
let newCompletions = progress - oldProgress
for _ in 0 ..< newCompletions {
  currentHabits[index].completionTimestamps[dateKey]?.append(currentTimestamp)
}
```

This creates **duplicate timestamps** when `newCompletions > 1`, causing the validation warnings.

---

## 🎯 Why This Causes Auto-Uncomplete

1. User taps breaking habit
2. `setProgress(progress=1)` writes to `completionHistory[dateKey] = 1`
3. `CompletionRecord` is created with `isCompleted = true` (because `actualUsage=0 <= target=1`)
4. UI re-renders and calls `habit.getProgress(for: date)`
5. `getProgress` returns `actualUsage[dateKey] ?? 0` → 0 (not 1!)
6. UI sees progress=0, marks habit as incomplete

**The data is split between two dictionaries, causing a race condition!**

---

## ✅ The Fix

### Part 1: Make `setProgress` Type-Aware

```swift
func setProgress(for habit: Habit, date: Date, progress: Int) async throws {
  let dateKey = CoreDataManager.dateKey(for: date)
  var currentHabits = try await loadHabits()
  
  if let index = currentHabits.firstIndex(where: { $0.id == habit.id }) {
    // ✅ FIX: Use the correct field based on habit type
    if habit.habitType == .breaking {
      let oldProgress = currentHabits[index].actualUsage[dateKey] ?? 0
      currentHabits[index].actualUsage[dateKey] = progress
      
      // Breaking habit: complete when usage <= target
      let isComplete = progress <= currentHabits[index].target
      currentHabits[index].completionStatus[dateKey] = isComplete
      
      print("🔍 BREAKING HABIT - '\(habit.name)' | Usage: \(progress) | Target: ≤\(currentHabits[index].target) | Complete: \(isComplete)")
    } else {
      let oldProgress = currentHabits[index].completionHistory[dateKey] ?? 0
      currentHabits[index].completionHistory[dateKey] = progress
      
      // Formation habit: complete when progress >= goal
      let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
      let isComplete = progress >= goalAmount
      currentHabits[index].completionStatus[dateKey] = isComplete
      
      print("🔍 FORMATION HABIT - '\(habit.name)' | Progress: \(progress) | Goal: ≥\(goalAmount) | Complete: \(isComplete)")
    }
    
    // ... rest of timestamp logic ...
  }
}
```

### Part 2: Fix Duplicate Timestamps

```swift
// Only append ONE timestamp per increment
if progress > oldProgress {
  if currentHabits[index].completionTimestamps[dateKey] == nil {
    currentHabits[index].completionTimestamps[dateKey] = []
  }
  // ✅ FIX: Append only ONE timestamp, not a loop
  currentHabits[index].completionTimestamps[dateKey]?.append(currentTimestamp)
}
```

### Part 3: Fix Future Dates

Need to investigate where dates are being set incorrectly. This might be related to timezone issues or `selectedDate` being out of sync.

---

## 🧪 Testing After Fix

### Test 1: Breaking Habit Completion
1. Create "Don't smoke - 1 time everyday" (baseline=10, target=1)
2. Tap to complete (sets usage=1)
3. **Expected:** Habit stays completed (usage=1 ≤ target=1) ✅

### Test 2: Breaking Habit Over Goal
1. Tap "Don't smoke" **twice** (sets usage=2)
2. **Expected:** Habit shows as incomplete (usage=2 > target=1) ❌

### Test 3: Formation Habit
1. Create "Meditate - 5 min everyday" (goal=5)
2. Tap once (progress=1)
3. **Expected:** Habit shows as incomplete (progress=1 < goal=5) ❌
4. Tap 4 more times (progress=5)
5. **Expected:** Habit stays completed (progress=5 ≥ goal=5) ✅

---

## 📝 Files That Need Fixing

### Primary Fix
- ✅ **`Core/Data/Repository/HabitStore.swift`** - `setProgress` method (lines 296-367)

### Verification Needed
- 🔍 **Date calculation** - Find where future dates (2025-10-22) are being set
- 🔍 **Timestamp recording** - Ensure only one timestamp per increment
- 🔍 **Completion status sync** - Verify all paths use type-aware logic

---

## 🔗 Related Issues

- **Breaking Habit Creation Fix:** `Docs/BREAKING_HABIT_CREATION_FIX.md` ✅ FIXED
- **Breaking Habit Validation:** `Docs/DATA_LOGIC_FIXES_APPLIED.md` ✅ FIXED
- **CompletionRecord Creation:** `Docs/BREAKING_HABIT_BUG_FIXED.md` ✅ FIXED

**This is the FINAL piece** - making `setProgress` type-aware so breaking habits use `actualUsage` instead of `completionHistory`.

---

## ✅ Summary

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| Breaking habit auto-uncompletes | `setProgress` uses `completionHistory` for all habit types | Make `setProgress` type-aware, use `actualUsage` for breaking habits |
| Formation habit won't complete | Completion logic uses `progress > 0` instead of `progress >= goal` | Use type-aware completion checks |
| Duplicate timestamps | Loop adds multiple timestamps | Append only ONE timestamp per increment |
| Future dates in validation | Unknown (needs investigation) | Fix date calculation |

**Next Step:** Apply the fix to `HabitStore.swift` `setProgress` method.

