# Habit System Issues - Current vs Expected Behavior

## Date: October 19, 2025

This document compares the **expected system behavior** (as defined by the user) with the **current implementation**, highlighting critical issues that need fixing.

---

## ❌ CRITICAL ISSUE #1: Habit Breaking Schedule Logic

### Expected Behavior:
- **Both Habit Building and Habit Breaking** should use the **"Goal" field** for scheduling
- For Habit Breaking:
  - **"Current" (baseline)**: Used ONLY for comparison/analysis
  - **"Goal" (target)**: Determines when the habit appears on the schedule

### Current Implementation:
```swift
// HabitFormLogic.swift:163-164
// For habit building, use goal frequency; for habit breaking, use target frequency
let scheduleFrequency = step1Data.4 == .formation ? goalFrequency : targetFrequency
let calendarSchedule = convertGoalFrequencyToSchedule(scheduleFrequency)
```

**✅ This is CORRECT** - The code uses `targetFrequency` (Goal) for habit breaking.

**However, the field naming is CONFUSING:**
- In UI forms, "baseline" = Current, "target" = Goal
- But the variable names suggest "target" is for scheduling, which is correct
- **Issue**: The separation between "Current" (baseline) and "Goal" (target) needs to be clearer

---

## ❌ CRITICAL ISSUE #2: Habit Breaking Progress Display

### Expected Behavior:
- Progress display: `[current]/[goal] [unit]`
- **For Habit Breaking**: Should show progress towards the Goal (target), NOT the baseline
- Example: If Goal is "3 times per day", display should show `0/3 times`, `1/3 times`, etc.

### Current Implementation:
```swift
// Habit.swift:466-482
func getProgress(for date: Date) -> Int {
    let dateKey = Self.dateKey(for: date)

    // For breaking habits, return actual usage instead of completion history
    if habitType == .breaking {
      let usage = actualUsage[dateKey] ?? 0
      return usage
    } else {
      // For formation habits, use completion history as before
      let progress = completionHistory[dateKey] ?? 0
      return progress
    }
}
```

**❌ MAJOR ISSUE**: For Habit Breaking, `getProgress()` returns `actualUsage`, but **it should return progress towards the Goal (target)**, not raw usage.

**Problem:**
- The system conflates "actual usage" with "progress"
- For Habit Breaking, progress should be measured against the Goal (target), not Current (baseline)
- Display should show: `[currentProgress]/[target] unit`, not `[actualUsage]/[baseline] unit`

---

## ❌ CRITICAL ISSUE #3: Completion Logic for Habit Breaking

### Expected Behavior:
- **Habit Building**: Complete when `current >= goal`
- **Habit Breaking**: Complete when progress towards Goal reaches the target
- Example: Goal is "Reduce to 3 times per day" → Complete when user does it 3 times or less

### Current Implementation:
```swift
// Habit.swift:354-358 (markCompleted)
if habitType == .breaking {
  // For breaking habits, completed when actual usage is at or below target
  let newProgress = completionHistory[dateKey] ?? 0
  completionStatus[dateKey] = newProgress <= target
}
```

**❌ CONFUSION**: The code checks `completionHistory <= target`, but:
1. What does `completionHistory` represent for Habit Breaking?
2. It should check if **Goal is met**, not if usage is below target
3. The logic is inconsistent with how `getProgress()` works

**Root Problem:**
- Habit Breaking uses `actualUsage` for tracking, but `completionHistory` for completion checks
- There's no clear separation between:
  - "Current" (baseline - for reference only)
  - "Actual daily usage" (what user is tracking)
  - "Goal/Target" (what user wants to achieve)

---

## ❌ CRITICAL ISSUE #4: Goal String Format Confusion

### Expected Behavior:
- **Habit Building**: `goal` field stores "[number] [unit] / [schedule]"
  - Example: "1 time / everyday"
- **Habit Breaking**:
  - `baseline` stores Current amount (for reference)
  - `target` stores Goal amount
  - `goal` string should represent the Goal, not Current

### Current Implementation:
```swift
// HabitFormLogic.swift:193-195
// Habit Breaking
let targetInt = Int(targetNumber) ?? 1
let targetPluralizedUnit = pluralizedUnit(targetInt, unit: targetUnit)
let goalString = formatGoalString(number: targetNumber, unit: targetPluralizedUnit, frequency: targetFrequency)
```

**✅ This is CORRECT** - The `goal` string is created from target (Goal), not baseline (Current).

**However:**
- The `baseline` field exists but is **only used for storage**, not for scheduling
- There's no UI display showing "Current: X, Goal: Y" comparison
- Users can't see how their "Current" baseline compares to their "Goal" target

---

## ❌ CRITICAL ISSUE #5: Progress Display Format

### Expected Behavior:
- Display format: `[current progress]/[goal number] [unit]`
- Examples:
  - `0/1 time` → `1/1 time` (complete)
  - `0/5 times` → `5/5 times` (complete)
  - `0/30 min` → `30/30 min` (complete)
- Unit is just a string label, only numbers matter for completion

### Current Implementation:
**No explicit code found for this display format.** 

The system calculates progress via:
- `habit.getProgress(for: date)` - returns current progress number
- `StreakDataCalculator.parseGoalAmount(from: habit.goal)` - extracts goal number

**❌ ISSUE**: 
- No centralized component that formats progress as `X/Y unit`
- Different views might display progress differently
- No guarantee that all views show the `current/goal` format consistently

---

## ❌ CRITICAL ISSUE #6: Daily Completion and Rewards Logic

### Expected Behavior:
1. ALL habits scheduled for a day must be complete for the day to be complete
2. Only when ALL habits are complete:
   - Show celebration animation
   - Award streak +1
   - Award XP
3. If ANY habit becomes incomplete (e.g., user decreases progress):
   - Remove celebration status
   - Revert streak -1
   - Remove awarded XP

### Current Implementation:

#### Celebration Trigger:
```swift
// HomeTabView.swift:91-99
case .dailyAwardGranted(let dateKey):
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        showCelebration = true
    }

case .dailyAwardRevoked(let dateKey):
    showCelebration = false
```

**✅ Celebration triggering logic exists**

#### XP Awarding:
```swift
// XPManager.swift:59
static let dailyCompletion = 50  // XP per fully completed day
```

```swift
// XPManager.swift:81-83
func recalculateXP(completedDaysCount: Int) -> Int {
    return completedDaysCount * XPRewards.dailyCompletion
}
```

**❌ MAJOR ISSUE - XP Calculation:**
1. XP is calculated as `completedDaysCount * 50`
2. This is **idempotent** (can be recalculated from scratch)
3. **BUT**: There's no clear "undo" mechanism when a day becomes incomplete

#### Streak Calculation:
```swift
// Habit.swift:518-554
func calculateTrueStreak() -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var calculatedStreak = 0
    var currentDate = today
    
    // Count consecutive completed days backwards from today
    while (isCompleted(for: currentDate) || 
           (vacationManager.isActive && vacationManager.isVacationDay(currentDate))) &&
          currentDate >= habitStartDate
    {
        if isCompleted(for: currentDate) {
            calculatedStreak += 1
        }
        currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
    }
    
    return calculatedStreak
}
```

**✅ Streak calculation is dynamic** - recalculated each time based on completion history

**❌ BUT**: Streak is per-habit, not global "all habits complete" streak

#### Daily Completion Check:
```swift
// StreakDataCalculator.swift:836-842
let allCompletedOnThisDate = habits.allSatisfy { habit in
    habit.isCompleted(for: currentDate)
}
```

**✅ Checks if ALL habits are complete**

**❌ MAJOR ISSUE - No Global Streak:**
- The system calculates streaks **per habit**, not **per day**
- Expected: Global streak that counts consecutive days where ALL habits were complete
- Current: Each habit has its own streak
- **Missing**: A "master streak" that represents "days where I completed everything"

---

## ❌ CRITICAL ISSUE #7: Reversal Logic (Undo Completion)

### Expected Behavior:
When user decreases progress on a completed habit:
1. The habit becomes incomplete
2. If the day was previously complete (all habits done):
   - Day becomes incomplete
   - Celebration is removed
   - Streak is decreased by 1
   - XP for that day is removed

### Current Implementation:

#### Mark Incomplete:
```swift
// Habit.swift:403-438
mutating func markIncomplete(for date: Date) {
    let dateKey = Self.dateKey(for: date)
    
    let currentProgress = completionHistory[dateKey] ?? 0
    completionHistory[dateKey] = max(0, currentProgress - 1)
    
    // Update completion status based on whether GOAL is still met
    if habitType == .breaking {
        let newProgress = completionHistory[dateKey] ?? 0
        completionStatus[dateKey] = newProgress <= target
    } else {
        let newProgress = completionHistory[dateKey] ?? 0
        if let goalAmount = parseGoalAmount(from: goal) {
            let isComplete = newProgress >= goalAmount
            completionStatus[dateKey] = isComplete
        } else {
            completionStatus[dateKey] = newProgress > 0
        }
    }
    
    // Remove the most recent timestamp
    if completionTimestamps[dateKey]?.isEmpty == false {
        completionTimestamps[dateKey]?.removeLast()
    }
}
```

**✅ Habit can be marked incomplete**

**❌ NO AUTOMATIC REWARD REVERSAL:**
- When a habit is marked incomplete, **nothing automatically checks** if the day was previously complete
- **No automatic streak decrease**
- **No automatic XP removal**
- The `dailyAwardRevoked` event might not be triggered

**Expected Flow:**
1. User decreases habit progress
2. System checks: "Was today complete before?"
3. If yes: "Is today still complete after the change?"
4. If no: Trigger `dailyAwardRevoked` event → Remove celebration, decrease streak, remove XP

**Current Reality:**
- Only the individual habit's completion status changes
- Global day completion might not be re-evaluated immediately
- Rewards might remain even though the day is no longer complete

---

## ❌ CRITICAL ISSUE #8: Frequency-Based Scheduling Issues

### Expected Behavior:
**Frequency-based schedules** should work as:
- **Weekly Frequency**: "3 days a week" → User can complete on ANY 3 days of the week
- **Monthly Frequency**: "10 days a month" → User can complete on ANY 10 days of the month

**Key Point**: Flexible scheduling - user chooses which days to complete the habit

### Current Implementation:
```swift
// HabitInstanceLogic.swift:183-200
static func shouldShowHabitWithFrequency(habit: Habit, date: Date) -> Bool {
    guard let daysPerWeek = extractDaysPerWeek(from: habit.schedule) else {
        return false
    }
    
    let today = Date()
    let targetDate = DateUtils.startOfDay(for: date)
    let todayStart = DateUtils.startOfDay(for: today)
    
    // If the target date is in the past, don't show the habit
    if targetDate < todayStart {
        return false
    }
    
    // For frequency-based habits, show the habit on the first N days starting from today
    let daysFromToday = DateUtils.daysBetween(todayStart, targetDate)
    return daysFromToday >= 0 && daysFromToday < daysPerWeek
}
```

**❌ COMPLETELY WRONG:**
- The code shows the habit on the **first N consecutive days** starting from today
- Example: "3 days a week" → Shows Monday, Tuesday, Wednesday only
- **Expected**: Should show on ALL 7 days, user can complete ANY 3 days
- **Current**: Forces completion on specific consecutive days

**This fundamentally breaks frequency-based scheduling!**

---

## ❌ CRITICAL ISSUE #9: No "Current" Field UI for Habit Breaking

### Expected Behavior:
When creating a Habit Breaking habit, the form should show:
1. **Current**: `[number] [unit] / [schedule]` - Baseline usage for comparison
2. **Goal**: `[number] [unit] / [schedule]` - Target reduction goal

Both fields are editable, but only **Goal** affects scheduling.

### Current Implementation:
```swift
// HabitFormComponents.swift:314-325
UnifiedInputElement(
    title: "Current",
    description: "How much do you currently do?",
    numberText: $baselineNumber,
    unitText: pluralizedBaselineUnit,
    frequencyText: baselineFrequency,
    ...
)

// Goal
UnifiedInputElement(
    title: "Goal",
    ...
)
```

**✅ The form DOES show both "Current" and "Goal" fields for Habit Breaking**

**❌ BUT**: The "Current" (baseline) data is **stored but never displayed again** after habit creation
- No comparison view showing "Current: 10 times/day → Goal: 3 times/day"
- No progress tracking showing "You've reduced from 10 to 5!"
- The baseline field is essentially wasted data

---

## ❌ CRITICAL ISSUE #10: Mixed Completion Status Systems

### Expected Behavior:
One clear completion system:
- `completionStatus[dateKey]` = Boolean (complete/incomplete)
- Based solely on: `current progress >= goal number`

### Current Implementation:
The codebase has **TWO overlapping systems**:

#### System 1: Count-based (Legacy)
```swift
var completionHistory: [String: Int] = [:]  // "yyyy-MM-dd" -> Int
```

#### System 2: Boolean-based (Current)
```swift
var completionStatus: [String: Bool] = [:]  // "yyyy-MM-dd" -> Bool
```

**❌ CONFUSION:**
- Both systems are maintained in parallel
- `markCompleted()` updates BOTH systems
- Code comments say System 1 is "DEPRECATED" but it's still actively used
- For Habit Breaking, `actualUsage` is ALSO tracked separately

**Three different progress tracking dictionaries:**
1. `completionHistory` - counts
2. `completionStatus` - booleans
3. `actualUsage` - for habit breaking

**This is unnecessarily complex and error-prone!**

---

## Summary of Critical Issues

| # | Issue | Severity | Impact |
|---|-------|----------|--------|
| 1 | Habit Breaking Schedule Logic | Medium | Scheduling works but field naming is confusing |
| 2 | Habit Breaking Progress Display | **CRITICAL** | Users don't see correct progress for habit breaking |
| 3 | Habit Breaking Completion Logic | **CRITICAL** | Completion check logic is unclear and potentially wrong |
| 4 | Goal String Format Confusion | Medium | Works but lacks UI for showing Current vs Goal comparison |
| 5 | Progress Display Format | **CRITICAL** | No consistent `X/Y unit` display format across views |
| 6 | Daily Completion and Rewards | **CRITICAL** | No global "all habits complete" streak system |
| 7 | Reversal Logic (Undo) | **CRITICAL** | Rewards not automatically removed when day becomes incomplete |
| 8 | Frequency-Based Scheduling | **CRITICAL** | Completely wrong - shows consecutive days instead of flexible schedule |
| 9 | No "Current" Field UI | Medium | Baseline data stored but never displayed or used |
| 10 | Mixed Completion Systems | High | Three overlapping progress tracking systems cause confusion |

---

## Recommendations

### Immediate Fixes (Critical):
1. **Fix Frequency-Based Scheduling** (Issue #8) - This is completely broken
2. **Implement Undo/Reversal Logic** (Issue #7) - Rewards must be removed when day becomes incomplete
3. **Fix Habit Breaking Progress Display** (Issue #2) - Show correct `current/goal` format
4. **Add Global Streak System** (Issue #6) - Track "days where all habits were complete"
5. **Standardize Progress Display** (Issue #5) - Create consistent `X/Y unit` component

### Secondary Improvements:
6. **Unify Completion Systems** (Issue #10) - Choose one system, remove the others
7. **Fix Habit Breaking Completion Logic** (Issue #3) - Clarify what "complete" means for habit breaking
8. **Add Current vs Goal Comparison UI** (Issue #9) - Show progress over time for habit breaking
9. **Improve Field Naming** (Issue #1) - Make "Current" vs "Goal" distinction clearer in code

---

## Architecture Suggestion

### Proposed Clear Model:

```swift
struct Habit {
    // Basic info
    let name: String
    let type: HabitType  // Building or Breaking
    
    // Goal definition (determines scheduling)
    let goal: Goal  // Number, unit, schedule
    
    // For Habit Breaking only
    let baseline: Goal?  // Current usage (for comparison only)
    
    // Progress tracking (single source of truth)
    var dailyProgress: [String: Progress]  // "yyyy-MM-dd" -> Progress
}

struct Progress {
    let currentValue: Int      // Current progress amount
    let goalValue: Int         // Target goal amount
    var isComplete: Bool {     // Computed property
        currentValue >= goalValue
    }
}

struct Goal {
    let number: Int
    let unit: String
    let schedule: Schedule
}

enum Schedule {
    case interval(IntervalType)    // Daily, Weekly specific days, Every N days
    case frequency(FrequencyType)  // N days per week, N days per month
}
```

This would eliminate the confusion between baseline/target, current/goal, and the multiple tracking systems.

