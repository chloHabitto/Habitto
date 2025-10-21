# 📁 All Files Related to Celebration/XP Award Issue

## 🔴 Core Files (Contains the Bugs)

### 1. `Core/Models/Habit.swift`
**Lines affected:** 346-406, 633-672
**Why it matters:**
- Contains `isCompletedInternal()` with **WRONG** breaking habit logic (line 643-653)
- Contains `markCompleted()` - may have wrong logic from previous fix (lines 346-373)
- Contains `markIncomplete()` - may have wrong logic from previous fix (lines 375-406)
- Contains `parseGoalAmount()` - helper to extract goal number from goal string (line 675-684)

**Current Bug:**
```swift
// Line 653 - WRONG
if habitType == .breaking {
  return usage > 0 && usage <= target  // ❌ Uses actualUsage/target
}
```

**Should Be:**
```swift
// CORRECT
if habitType == .breaking {
  let progress = completionHistory[dateKey] ?? 0
  let goalAmount = parseGoalAmount(from: goal)
  return progress >= goalAmount  // ✅ Uses progress/goal
}
```

---

### 2. `Views/Tabs/HomeTabView.swift`
**Lines affected:** 209-302, 1046-1059, 1244-1298, 1357-1427, 1429-1440
**Why it matters:**
- Main orchestrator for the entire flow
- Contains `baseHabitsForSelectedDate` - filters habits for today (lines 265-290)
- Contains `habitsForSelectedDate` - another filter with logging (lines 209-242)
- Contains `prefetchCompletionStatus()` - builds completion map (lines 1046-1059)
- Contains `onHabitCompleted()` - detects last habit, **DUPLICATES THE BUG** (lines 1244-1298)
- Contains `onLastHabitCompleted()` - sets flag (lines 1429-1440)
- Contains `onDifficultySheetDismissed()` - awards XP and triggers celebration (lines 1357-1427)
- Contains `countCompletedDays()` - calculates total XP (lines 1066-1153)

**Current Bug:**
```swift
// Lines 1264-1267 - WRONG (duplicates the bug from Habit.swift)
if habitData.habitType == .breaking {
  let usage = habitData.actualUsage[dateKey] ?? 0
  isComplete = usage > 0 && usage <= habitData.target  // ❌
}
```

**Should Be:**
```swift
// CORRECT
if habitData.habitType == .breaking {
  let progress = habitData.completionHistory[dateKey] ?? 0
  let goalAmount = StreakDataCalculator.parseGoalAmount(from: habitData.goal)
  isComplete = progress >= goalAmount  // ✅
}
```

---

### 3. `Core/Data/HabitRepository.swift`
**Lines affected:** 700-794
**Why it matters:**
- Contains `setProgress()` method that updates habit completion (lines 700-794)
- May also have the wrong breaking habit logic (need to check lines 721-740)
- Posts `habitProgressUpdated` notification that triggers UI updates

**Need to check:**
```swift
// Around line 730 (from previous fix)
if habits[index].habitType == .breaking {
  habits[index].completionStatus[dateKey] = progress <= habits[index].target  // ❌ May be wrong
}
```

**Should Be:**
```swift
if habits[index].habitType == .breaking {
  let goalAmount = StreakDataCalculator.parseGoalAmount(from: habits[index].goal)
  habits[index].completionStatus[dateKey] = progress >= goalAmount  // ✅
}
```

---

## 🟡 Supporting Files (Used in the Flow)

### 4. `Core/UI/Items/ScheduledHabitItem.swift`
**Lines affected:** 443-511, 515-553
**Why it matters:**
- User interaction point - where taps happen
- Contains `completeHabit()` - calls `onProgressChange?(habit, date, goalAmount)` (lines 443-511)
- Contains `toggleHabitCompletion()` - entry point for tap (lines 515-523)
- Triggers the entire flow when user taps the circle

**Flow:**
```swift
User taps circle
  → toggleHabitCompletion()
  → completeHabit()
  → onProgressChange?(habit, selectedDate, goalAmount)
  → Goes to HomeTabView callback
```

---

### 5. `Core/Data/StreakDataCalculator.swift` ✅ CORRECTED PATH
**Lines affected:** Line 635 (`parseGoalAmount()`)
**Why it matters:**
- Contains `static func parseGoalAmount(from: String) -> Int` helper function
- Used in multiple places to extract the numeric goal from goal strings
- Example: "5 times everyday" → returns 5

**Used by:**
- `HomeTabView.onHabitCompleted()` (line 1271)
- `HabitRepository.setProgress()` (line 739)
- Many other files (see duplicate implementations below)

**⚠️ NOTE:** There are **10 duplicate implementations** of `parseGoalAmount()` across the codebase:
1. `Core/Data/StreakDataCalculator.swift` (line 635) - Main implementation
2. `Core/Models/Habit.swift` (line 675) - Private method
3. `Views/Tabs/ProgressTabView.swift` (line 2339) - Private method
4. `Core/UI/Forms/ValidationBusinessRulesLogic.swift` (line 11) - Wrapper
5. `Core/UI/Helpers/ProgressCalculationHelper.swift` (line 6) - Wrapper
6. `Core/UI/Helpers/HabitPatternAnalyzer.swift` (line 819) - Private static
7. `Core/Data/SwiftData/SimpleHabitData.swift` (line 139) - Private method
8. `Core/Data/CloudKit/CloudKitConflictResolver.swift` (line 307) - Private method
9. `Core/Data/CalendarGridViews.swift` (lines 666, 968) - Two private methods

These should all use the same logic!

---

### 6. `Core/Managers/XPManager.swift`
**Lines affected:** Full file
**Why it matters:**
- Manages XP state across the app
- Contains `totalXP` property
- Contains `publishXP(completedDaysCount:)` method
- Used by `HomeTabView` to update XP after celebration

**Called from:**
```swift
// HomeTabView.swift line 1393
let completedDaysCount = countCompletedDays()
xpManager.publishXP(completedDaysCount: completedDaysCount)
```

---

### 7. `Core/Services/DailyAwardService.swift`
**Lines affected:** Full file
**Why it matters:**
- Service for managing daily awards
- May have been used in older versions of the flow
- Currently the flow uses direct SwiftData insertion in `HomeTabView`

**Current Usage:**
```swift
// HomeTabView.swift lines 1401-1408
let dailyAward = DailyAward(
  userId: userId,
  dateKey: dateKey,
  xpGranted: 50,
  allHabitsCompleted: true
)
modelContext.insert(dailyAward)
```

---

### 8. `Core/Data/SwiftData/DailyAward.swift`
**Lines affected:** Full file
**Why it matters:**
- SwiftData model for tracking daily award history
- Stores: `userId`, `dateKey`, `xpGranted`, `allHabitsCompleted`
- Used to prevent duplicate awards
- Used in `countCompletedDays()` to calculate total XP

---

### 9. `Core/Data/SwiftData/CompletionRecord.swift`
**Lines affected:** Full file
**Why it matters:**
- SwiftData model for tracking individual habit completions
- Stores: `habitId`, `userId`, `dateKey`, `isCompleted`
- Used by `countCompletedDays()` to check historical completions (lines 1096-1139)
- May have duplicate logic issues

**Used in:**
```swift
// HomeTabView.swift lines 1100-1128
let descriptor = FetchDescriptor<CompletionRecord>()
let allRecords = try modelContext.fetch(descriptor)
let completedRecords = allRecords.filter { 
  $0.dateKey == dateKey && $0.userId == userId && $0.isCompleted 
}
```

---

### 10. `Core/EventBus/EventBus.swift`
**Lines affected:** Full file
**Why it matters:**
- Event bus for decoupled communication
- Contains `.dailyAwardGranted(dateKey)` event
- Contains `.dailyAwardRevoked(dateKey)` event
- Triggers celebration animation after award

**Flow:**
```swift
// After DailyAward is granted, somewhere this should fire:
eventBus.send(.dailyAwardGranted(dateKey))

// HomeTabView listens (lines 87-107):
eventBus.publisher()
  .sink { event in
    case .dailyAwardGranted(let dateKey):
      showCelebration = true  // Show animation
  }
```

---

### 11. `Views/Screens/HomeView.swift`
**Lines affected:** Full file
**Why it matters:**
- Parent container that holds `HomeTabView`
- Passes callbacks like `onSetProgress` down to `HomeTabView`
- Contains `HomeViewState` class that manages app-wide habit state

**Callback Flow:**
```swift
HomeView
  → HomeTabView (gets onSetProgress callback)
  → ScheduledHabitItem (gets onProgressChange callback)
  → User taps → callback fires
  → Goes back up to HomeView/HomeTabView
  → HabitRepository.setProgress()
```

---

### 12. `Views/Components/CelebrationView.swift`
**Lines affected:** Full file
**Why it matters:**
- The actual celebration animation UI
- Shown when `showCelebration = true` in `HomeTabView`
- Displays confetti, success message, XP earned

**Triggered by:**
```swift
// HomeTabView.swift lines 383-392
if showCelebration {
  CelebrationView(
    isPresented: $showCelebration,
    onDismiss: { }
  )
}
```

---

### 13. `Core/Data/Repository/HabitStore.swift`
**Lines affected:** `setProgress()` method
**Why it matters:**
- Actor-based storage layer
- May have additional completion logic
- Used by `HabitRepository` for persistence

---

### 14. `Core/Utils/DateUtils.swift`
**Lines affected:** Various date helpers
**Why it matters:**
- Contains `today()`, `startOfDay()`, `daysBetween()` helpers
- Used throughout the flow for date comparisons
- Critical for `countCompletedDays()` calculation

---

## 📊 File Dependency Graph

```
User Action
    ↓
ScheduledHabitItem.swift
    ↓
HomeView.swift (callback)
    ↓
HomeTabView.swift (onSetProgress)
    ↓
HabitRepository.swift (setProgress)
    ↓
Habit.swift (markCompleted, isCompleted) ← 🐛 BUG HERE
    ↓
HabitStore.swift (persistence)
    ↓
HomeTabView.swift (onHabitCompleted) ← 🐛 BUG DUPLICATED HERE
    ↓
    ├─ Checks remaining habits (WRONG)
    ├─ If empty → onLastHabitCompleted()
    ├─ Sets lastHabitJustCompleted = true
    ↓
Difficulty Sheet Shown
    ↓
HomeTabView.swift (onDifficultySheetDismissed)
    ↓
    ├─ Check lastHabitJustCompleted? ← ❌ FALSE (because of bug)
    ├─ countCompletedDays() using CompletionRecord.swift
    ├─ XPManager.publishXP()
    ├─ Create DailyAward (DailyAward.swift)
    ├─ EventBus.send(.dailyAwardGranted)
    ↓
EventBus.swift
    ↓
HomeTabView.swift (listener)
    ↓
    └─ showCelebration = true
        ↓
    CelebrationView.swift (shows animation)
```

---

## 🎯 Priority Fix Order

### 1. **CRITICAL** (Must fix first)
- ✅ `Core/Models/Habit.swift` - `isCompletedInternal()` (line 643-653)
- ✅ `Views/Tabs/HomeTabView.swift` - `onHabitCompleted()` (lines 1264-1279)

### 2. **HIGH** (Check and fix if wrong)
- ⚠️ `Core/Models/Habit.swift` - `markCompleted()` (lines 346-373)
- ⚠️ `Core/Models/Habit.swift` - `markIncomplete()` (lines 375-406)
- ⚠️ `Core/Data/HabitRepository.swift` - `setProgress()` (lines 721-740)

### 3. **MEDIUM** (Verify correct behavior)
- 🔍 `Core/UI/Items/ScheduledHabitItem.swift` - completion logic
- 🔍 `Core/Data/Repository/HabitStore.swift` - persistence logic

### 4. **LOW** (Supporting files, likely OK)
- ✓ `Core/Managers/XPManager.swift`
- ✓ `Core/Services/DailyAwardService.swift`
- ✓ `Core/EventBus/EventBus.swift`
- ✓ `Views/Components/CelebrationView.swift`

---

## 🔧 What Needs to Change

### Universal Rule for ALL Files:
**Both habit types MUST use identical completion logic:**

```swift
// ✅ CORRECT for BOTH Formation and Breaking habits:
let progress = completionHistory[dateKey] ?? 0
let goalAmount = parseGoalAmount(from: goal)  // or StreakDataCalculator.parseGoalAmount()
let isComplete = progress >= goalAmount
```

### Files to Update:
1. `Habit.swift` - `isCompletedInternal()` 
2. `Habit.swift` - `markCompleted()` (revert previous wrong fix)
3. `Habit.swift` - `markIncomplete()` (revert previous wrong fix)
4. `HomeTabView.swift` - `onHabitCompleted()`
5. `HabitRepository.swift` - `setProgress()` (revert previous wrong fix)

### What to IGNORE:
- `target` field - **display only**, not for completion checks
- `baseline` field - **display only**, not for completion checks
- `actualUsage` dictionary - **NOT used for completion**, only for display

---

## 📝 Summary

**Total Files Involved:** 14 files
**Files with Bugs:** 2-3 files (Habit.swift, HomeTabView.swift, possibly HabitRepository.swift)
**Files to Update:** 5 locations across 3 files
**Supporting Files:** 11 files (work correctly, no changes needed)

The bug is localized to **completion checking logic** in 2-3 files, but the flow touches 14 files total.

