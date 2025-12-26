# Completion Check Flow Analysis

This document lists all places where completion status is determined for streak/XP purposes, before implementing the "Streak Mode" feature.

## 1. `habit.isCompleted(for:)` Method Calls

The main completion check method is `Habit.isCompleted(for:)` which is defined in `Core/Models/Habit.swift` (lines 839-909). This method:
- For historical dates: Queries SwiftData CompletionRecords or uses `completionHistory` dictionary
- For today: Uses in-memory `completionHistory` dictionary
- **Completion logic**: `goalAmount > 0 ? (progress >= goalAmount) : (progress > 0)`

### All Places Where `isCompleted(for:)` is Called:

#### Core/Data/CalendarGridViews.swift
- **Line 616**: `return habit.isCompleted(for: today) ? 100.0 : 0.0`
- **Line 634**: `if habit.isCompleted(for: currentDate) {`
- **Line 657**: `if habit.isCompleted(for: currentDate) {`
- **Line 699**: `if habit.isCompleted(for: currentDate) {`
- **Line 936**: `return habit.isCompleted(for: today) ? 100.0 : 0.0`
- **Line 958**: `if habit.isCompleted(for: currentDate) {`
- **Line 986**: `if habit.isCompleted(for: currentDate) {`

#### Core/UI/Components/SimpleMonthlyCalendar.swift
- **Line 224**: `if habit.isCompleted(for: targetDate) {`

#### Views/Tabs/HomeTabView.swift
- **Line 867**: `return instanceDate == targetDateStart && !instance.isCompleted(for: habit)`
- **Line 988**: `statusMap[habit.id] = habit.isCompleted(for: selectedDate)`
- **Line 1100**: Uses `habitData.completionHistory` and `goalAmount` directly (see section 2)

#### Core/Managers/XPManager.swift
- **Line 707**: `if habit.isCompleted(for: date) {` - Used for XP calculation

#### Core/Models/Habit.swift
- **Line 724**: `let todayCompleted = isCompleted(for: today)`
- **Line 737**: `while (isCompleted(for: currentDate) ||`
- **Line 742**: `let isCompleted = isCompleted(for: currentDate)`

#### Core/Data/StreakDataCalculator.swift
- **Line 59**: `if habit.isCompleted(for: currentDate) {` - Streak calculation
- **Line 112**: `.isCompleted(for: today)` - Filter completed habits
- **Line 239**: `if habit.isCompleted(for: targetDate) {` - Heatmap data
- **Line 370**: `habits.filter { $0.isCompleted(for: targetDate) }.count` - Completion count
- **Line 788**: `habits.filter { $0.isCompleted(for: today) }.count` - Today's completion count
- **Line 843**: `habit.isCompleted(for: currentDate)` - Streak statistics
- **Line 874**: `habits.filter { $0.isCompleted(for: date) }.count` - Completion count

#### Core/Streaks/StreakCalculator.swift
- **Line 70**: `habit.isCompleted(for: checkDate)` - **CRITICAL**: Global streak calculation
- **Line 150**: `let isComplete = habit.isCompleted(for: checkDate)` - Longest streak calculation
- **Line 185**: `scheduledHabits.first(where: { $0.name == habitName })?.isCompleted(for: checkDate) ?? false` - Debug logging

#### Core/Debug/HabitInvestigator.swift
- **Line 171**: `let isCompleted = habit.isCompleted(for: currentDate)` - Debug verification

#### Core/Managers/NotificationManager.swift
- **Line 875**: `return !habit.isCompleted(for: date)` - Notification eligibility
- **Line 1955**: `if dateKey == today, habit.isCompleted(for: date) {` - Notification handling

#### Core/UI/Helpers/ProgressCalculationHelper.swift
- **Line 97**: `let isCompleted = habit.isCompleted(for: date)` - Progress calculation
- **Line 443**: `if habit.isCompleted(for: today) {` - Today's completion check

#### Core/UI/Forms/HabitInstanceLogic.swift
- **Line 383**: `return instanceDate == targetDateStart && !instance.isCompleted(for: habit)` - Instance completion

#### Core/Models/HabitImprovements.swift
- **Line 410**: `if isCompleted(for: currentDate) {` - Improvement tracking

---

## 2. Direct `progress >= goal` Checks (Not Using `isCompleted(for:)`)

These places directly check `progress >= goalAmount` instead of using `isCompleted(for:)`. **These need to be updated to respect Streak Mode.**

### Core/Models/Habit.swift
- **Line 855**: `let isComplete = goalAmount > 0 ? (progress >= goalAmount) : (progress > 0)` - Historical date check
- **Line 870**: `let calculatedCompleted = goalAmount > 0 ? (progress >= goalAmount) : (progress > 0)` - Historical fallback
- **Line 897**: `let calculatedCompleted = goalAmount > 0 ? (progress >= goalAmount) : (progress > 0)` - Today's check
- **Line 570**: `let isComplete = newProgress >= goalAmount` - In `markCompleted(for:at:)` method

### Views/Tabs/HomeTabView.swift - **CELEBRATION TRIGGER**
- **Line 1105-1115**: **CRITICAL - Last Habit Completion Check**
```swift
let progress = habitData.completionHistory[dateKey] ?? 0
let goalAmount = habitData.goalAmount(for: selectedDate)

let isComplete: Bool
if goalAmount > 0 {
  isComplete = progress >= goalAmount
} else {
  isComplete = progress > 0
}
```
This is used in `onHabitCompleted(_:)` to determine if all habits are complete and trigger celebration.

### Core/Data/Repository/HabitStore.swift
- **Line 589**: `let isComplete = progress >= goalAmount` - Progress update
- **Line 1185**: `let isCompleted = recordedStatus ?? (progress >= goalAmount)` - Completion status

### Core/Data/SwiftData/SwiftDataStorage.swift
- **Line 184**: `let isCompleted = recordedStatus ?? (progress >= goalInt)` - Historical data loading
- **Line 719**: `let isCompleted = recordedStatus ?? (progress >= goalInt)` - Historical data loading

### Core/Data/HabitRepository.swift
- **Line 674**: `let isComplete = progress >= goalAmount` - Progress calculation
- **Line 1100**: `let isComplete = progress >= goalAmount` - Completion status update
- **Line 1722**: `return progress >= goalAmount` - XP eligibility check

### Core/Data/SwiftData/HabitDataModel.swift
- **Line 244**: `let isCompleted = recordedStatus ?? (progress >= goalAmount)` - Historical data parsing

### Core/Services/ProgressEventService.swift
- **Line 177**: `let isCompleted = progress >= goalAmount` - Event replay calculation
- **Line 257**: `return (progress, progress >= goalAmount)` - Fallback calculation
- **Line 264**: `return (progress, progress >= goalAmount)` - Error fallback

### Views/Tabs/ProgressTabView.swift
- **Line 2200**: `return progress >= goalAmount ? 1 : 0` - Progress calculation
- **Line 2208**: `return progress >= goalAmount` - Completion check
- **Line 2304**: `if progress >= goalAmount {` - Chart data
- **Line 2465**: `if progress >= goalAmount {` - Chart data
- **Line 2571**: `if progress >= goalAmount {` - Chart data
- **Line 3070**: `if progress >= goalAmount {` - Chart data
- **Line 3271**: `return progress >= goalAmount` - Completion check
- **Line 3384**: `if progress >= goalAmount {` - Chart data
- **Line 3833**: `if progress >= goalAmount {` - Chart data

### Core/UI/Helpers/ProgressCalculationHelper.swift
- **Line 483**: `if progress >= goalAmount {` - Progress calculation
- **Line 523**: `if progress >= goalAmount {` - Progress calculation

### Core/UI/Forms/ProgressCalculationLogic.swift
- **Line 116**: `if progress >= goalAmount {` - Progress calculation
- **Line 201**: Uses `habit.isCompleted(for: date)` - Good!
- **Line 224**: Uses `habit.isCompleted(for: today)` - Good!

### Core/Data/CloudKit/CloudKitConflictResolver.swift
- **Line 296**: `if progress >= goalAmount {` - Conflict resolution

### Core/UI/Helpers/HabitPatternAnalyzer.swift
- **Line 589**: `habitRecords.filter { $0.progress >= Double(goalAmount) }.count` - Pattern analysis

---

## 3. Celebration Trigger in HomeTabView

The celebration is triggered when the **last habit** is completed for the day. Here's the flow:

### Entry Point: `onHabitCompleted(_:)` (Line 1081)
```swift
private func onHabitCompleted(_ habit: Habit) {
  // ... 
  // Check remaining habits using direct progress >= goal check (lines 1105-1115)
  let remainingHabits = baseHabitsForSelectedDate.filter { h in
    // Direct check: progress >= goalAmount
    let isComplete: Bool
    if goalAmount > 0 {
      isComplete = progress >= goalAmount
    } else {
      isComplete = progress > 0
    }
    return !isComplete
  }
  
  if remainingHabits.isEmpty {
    // Last habit completed - trigger celebration
    onLastHabitCompleted()
  }
}
```

### Celebration Trigger: `onLastHabitCompleted()` (Line 1316)
```swift
private func onLastHabitCompleted() {
  lastHabitJustCompleted = true
  // Celebration will be shown after difficulty sheet is dismissed
}
```

### Celebration Display: `onCompletionDismiss()` (Line 1216-1229)
```swift
if lastHabitJustCompleted {
  // Trigger celebration
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
    showCelebration = true
  }
  // Award XP via DailyAwardService
}
```

### Event Bus Listener (Lines 88-97)
The celebration can also be triggered via event bus:
```swift
case .dailyAwardGranted(let dateKey):
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
    showCelebration = true
  }
```

---

## 4. Summary of Critical Locations

### Most Critical (Affect Streak/XP):
1. **`Core/Streaks/StreakCalculator.swift`** (Line 70) - Global streak calculation
2. **`Core/Models/Habit.swift`** (Lines 855, 870, 897) - `isCompleted(for:)` implementation
3. **`Views/Tabs/HomeTabView.swift`** (Lines 1105-1115) - Last habit completion check for celebration
4. **`Core/Managers/XPManager.swift`** (Line 707) - XP calculation
5. **`Core/Data/StreakDataCalculator.swift`** (Line 59) - Individual habit streak

### Secondary (UI/Display):
- Calendar views
- Progress tab views
- Notification checks
- Debug tools

### Data Layer (Storage/Persistence):
- `HabitStore.swift` - Progress updates
- `HabitRepository.swift` - XP eligibility
- `ProgressEventService.swift` - Event replay
- `HabitDataModel.swift` - Historical data

---

## 5. Current Completion Logic Pattern

The current pattern used throughout the codebase is:
```swift
let isComplete: Bool
if goalAmount > 0 {
  isComplete = progress >= goalAmount  // Full Completion Mode
} else {
  isComplete = progress > 0           // Fallback for zero goals
}
```

This needs to be changed to respect the "Streak Mode" setting:
- **Full Completion Mode**: `progress >= goalAmount` (current behavior)
- **Any Progress Mode**: `progress > 0`

---

## Next Steps for Implementation

1. Add a `streakMode` property to the Habit model or UserSettings
2. Update `Habit.isCompleted(for:)` to respect streak mode
3. Update all direct `progress >= goal` checks to use `isCompleted(for:)` or a helper method
4. Ensure celebration logic in HomeTabView uses the updated completion check
5. Test streak calculations with both modes
6. Test XP awards with both modes
7. Test celebration triggers with both modes

