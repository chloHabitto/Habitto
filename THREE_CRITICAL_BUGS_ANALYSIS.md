# 🐛 Three Critical Bugs - Analysis & Fix

## Summary

After testing the universal completion logic fix, 3 critical bugs were discovered. All three stem from **incorrect understanding of the design**.

---

## 🐛 Bug #1: Celebration Triggers at 2/10 Instead of 10/10

### Test Case:
- Habit1 (Formation): Goal "5 times/everyday" 
- Habit2 (Breaking): Goal "10 times/everyday"
- User completes Habit1: 5/5 ✅
- User increments Habit2 to 2/10
- **Result:** Celebration triggers! ❌

### Root Cause:
The circle button's `completeHabit()` function sets progress **directly to the goal** instead of incrementing by 1.

**File:** `Core/UI/Items/ScheduledHabitItem.swift` (lines 450-517)

**Current Code (WRONG):**
```swift
private func completeHabit() {
  let goalAmount = extractNumericGoalAmount(from: habit.goal)
  
  if isCompleted {
    onProgressChange?(habit, selectedDate, 0)  // Reset to 0
  } else {
    currentProgress = goalAmount  // ❌ Sets to GOAL (10)!
    onProgressChange?(habit, selectedDate, goalAmount)  // ❌ Saves GOAL amount!
  }
}
```

**What Happens:**
1. User clicks circle on Habit2 (Breaking, goal 10)
2. `completeHabit()` sets progress to 10 immediately
3. Habit2 shows as 10/10 complete ✅
4. System checks: All habits complete!
5. Celebration triggers (but user only wanted to increment by 1!)

### The Fix:
The circle button should **increment by 1**, not jump to goal!

```swift
private func completeHabit() {
  let goalAmount = extractNumericGoalAmount(from: habit.goal)
  
  if isCompleted {
    // Decrement by 1
    let newProgress = max(0, currentProgress - 1)
    currentProgress = newProgress
    onProgressChange?(habit, selectedDate, newProgress)
  } else {
    // Increment by 1
    let newProgress = currentProgress + 1
    currentProgress = newProgress
    onProgressChange?(habit, selectedDate, newProgress)
    
    // Show completion sheet if we just reached the goal
    if newProgress >= goalAmount {
      showingCompletionSheet = true
    }
  }
}
```

---

## 🐛 Bug #2: Progress Data Loss on Tab Switch

### Test Case:
- Habit2 at 2/10
- User switches to another tab
- User switches back to home tab
- **Result:** Habit2 resets to 0/10 ❌

### Root Cause (Suspected):
Two possibilities:

**A) Data isn't being saved:**
- `HabitRepository.setProgress()` might not be persisting to SwiftData
- Or it's persisting but not awaiting completion

**B) Data is being reloaded incorrectly:**
- Tab switch triggers `loadHabits(force: true)`
- Old data from Firestore overwrites local changes
- `completionHistory` gets cleared

### Need to Check:

**File:** `Core/Data/HabitRepository.swift` (line 771-793)

```swift
// Persist data in background
Task {
  do {
    print("🎯 DEBUG: Calling habitStore.setProgress now...")
    try await habitStore.setProgress(for: habit, date: date, progress: progress)
    print("✅ HabitRepository: Successfully persisted progress")
  } catch {
    print("❌ HabitRepository: Failed to persist progress: \(error)")
    // Revert UI change if persistence failed
    DispatchQueue.main.async {
      // ⚠️ Does this revert cause the data loss?
      if let index = self.habits.firstIndex(where: { $0.id == habit.id }) {
        self.habits[index].completionHistory[dateKey] = habit.completionHistory[dateKey] ?? 0
        self.objectWillChange.send()
      }
    }
  }
}
```

**Questions:**
1. Is the `Task` completing before tab switch?
2. Is there error handling that reverts the progress?
3. Is `loadHabits()` being called on tab switch, overwriting local changes?

---

## 🐛 Bug #3: Circle Button Doesn't Work

### Test Case:
- Reset both habits to 0/5 and 0/10
- Tap circle button on right side of habit card
- **Expected:** Progress increments by 1
- **Actual:** Nothing happens ❌

### Root Cause:
Likely the same as Bug #1 - the `completeHabit()` function logic is broken.

**Current Logic:**
```swift
if isCompleted {
  // If already completed, reset to 0
} else {
  // If not completed, jump to goal amount
}
```

**Problem:**
- For a habit at 0/10, `isCompleted()` returns FALSE (0 >= 10 = false)
- So it goes to the `else` branch
- Which sets progress to 10 (the goal)
- But the UI might not update?

**Possible Issues:**
1. The onProgressChange callback isn't wired up correctly
2. The progress update is being ignored
3. There's a race condition in the state update

---

## 🎯 The Real Design Intent

Looking at the design document and user behavior:

### For Circle Button (Quick Complete):
1. **If habit is NOT complete:** Increment by 1
2. **If habit IS complete:** Decrement by 1 (or reset to 0)
3. **Never jump directly to goal**

### For Swipe Gestures:
- **Swipe right:** +1 increment
- **Swipe left:** -1 decrement
- These already work correctly!

### For Completion:
- When progress reaches goal → show difficulty sheet
- After rating → check if all habits complete → celebration

---

## 📊 Fix Plan

### Priority 1: Fix Circle Button Logic (Bug #3 & #1)

**File:** `Core/UI/Items/ScheduledHabitItem.swift`
**Method:** `completeHabit()` (lines 450-517)

**Change from:**
```swift
if isCompleted {
  onProgressChange?(habit, selectedDate, 0)
} else {
  currentProgress = goalAmount
  onProgressChange?(habit, selectedDate, goalAmount)
  showingCompletionSheet = true
}
```

**Change to:**
```swift
let newProgress: Int
if currentProgress >= goalAmount {
  // Already at or above goal - decrement by 1
  newProgress = max(0, currentProgress - 1)
} else {
  // Below goal - increment by 1
  newProgress = currentProgress + 1
}

// Update local state
isLocalUpdateInProgress = true
withAnimation(.easeInOut(duration: 0.2)) {
  currentProgress = newProgress
}

// Save to repository
onProgressChange?(habit, selectedDate, newProgress)

// Record timestamp
lastUserUpdateTimestamp = Date()

// Release lock after persistence
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
  isLocalUpdateInProgress = false
}

// Show completion sheet if we just reached the goal
if newProgress >= goalAmount && newProgress > 0 {
  let completionManager = CompletionStateManager.shared
  guard !completionManager.isShowingCompletionSheet(for: habit.id) else { return }
  completionManager.startCompletionFlow(for: habit.id)
  isCompletingHabit = true
  showingCompletionSheet = true
}

// Haptic feedback
let impactFeedback = UIImpactFeedbackGenerator(style: newProgress > currentProgress ? .medium : .light)
impactFeedback.impactOccurred()
```

### Priority 2: Fix Data Persistence (Bug #2)

**Investigation needed:**
1. Add more debug logs to `HabitRepository.setProgress()` persistence
2. Check if `loadHabits()` is called on tab switch
3. Verify Firestore/SwiftData sync timing

**File:** `Core/Data/HabitRepository.swift`
**Method:** `setProgress()` (lines 700-794)

**Add logging:**
```swift
Task {
  do {
    print("🎯 PERSIST: Starting persistence for \(habit.name) progress \(progress)")
    try await habitStore.setProgress(for: habit, date: date, progress: progress)
    print("✅ PERSIST: Completed successfully for \(habit.name)")
  } catch {
    print("❌ PERSIST: FAILED for \(habit.name): \(error)")
    print("❌ PERSIST: Error type: \(type(of: error))")
  }
}
```

### Priority 3: Prevent Tab Switch Data Loss

**File:** `Views/Screens/HomeView.swift` or wherever tab switching happens

**Check for:**
- `loadHabits(force: true)` calls on tab changes
- If found, change to `loadHabits(force: false)` to use cached data
- Or add a flag to prevent reload if there are unsaved changes

---

## 🧪 Testing After Fix

### Test 1: Circle Button Increments by 1
1. Create Habit (Formation or Breaking): "10 times/everyday"
2. Click circle button once
3. **Expected:** Progress = 1/10 ✅
4. Click 9 more times
5. **Expected:** Progress = 10/10, difficulty sheet appears ✅

### Test 2: No Premature Celebration
1. Habit1 (Formation): "5 times/everyday"
2. Habit2 (Breaking): "10 times/everyday"
3. Complete Habit1: 5/5 ✅
4. Click Habit2 circle 2 times
5. **Expected:** Progress = 2/10, NO celebration ❌
6. Click 8 more times
7. **Expected:** Progress = 10/10, difficulty sheet
8. After rating: **CELEBRATION + XP!** ✅

### Test 3: Progress Persists on Tab Switch
1. Habit2 at 5/10
2. Switch to Progress tab
3. Switch back to Home tab
4. **Expected:** Habit2 still at 5/10 ✅
5. Complete it to 10/10
6. Switch tabs and back
7. **Expected:** Still at 10/10 ✅

---

## 📝 Summary

| Bug | Root Cause | File | Lines | Fix |
|-----|------------|------|-------|-----|
| #1 | Circle button jumps to goal | ScheduledHabitItem.swift | 450-517 | Change to increment by 1 |
| #2 | Progress lost on tab switch | HabitRepository.swift? | TBD | Add persistence logs, fix reload |
| #3 | Circle button broken | ScheduledHabitItem.swift | 450-517 | Same as Bug #1 |

**Bugs #1 and #3 are the same issue** - the circle button logic is fundamentally wrong.

**Bug #2 needs investigation** - likely a persistence or reload timing issue.

---

## Next Steps

1. ✅ Fix `completeHabit()` to increment by 1
2. ✅ Add proper completion sheet logic when goal reached
3. ⚠️ Add debug logs to track persistence
4. ⚠️ Test tab switching with logs
5. ⚠️ Fix reload if needed

The main issue is that I implemented "quick complete" to mean "complete the entire goal" when it should mean "increment progress by 1".

