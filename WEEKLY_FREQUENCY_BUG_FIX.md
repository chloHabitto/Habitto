# Weekly Frequency Schedule Bug Fix

## Issue Description

**Reported by user:** Habit "Habit4" with schedule "3 days a week" starting Oct 30, 2025:
- ❌ Only showed on Oct 30 and 31 (2 days)
- ❌ Disappeared after that
- ❌ Not planned for next week
- ✅ **Expected:** Should appear every day, user chooses which 3 days to complete

## Root Cause

The `shouldShowHabitWithFrequency` function in two locations had **incorrect logic** for frequency-based schedules (e.g., "X days a week"):

### Buggy Logic (BEFORE):
```swift
// ❌ WRONG: Only shows habit for first N consecutive days from today
let daysFromToday = DateUtils.daysBetween(todayStart, targetDate)
return daysFromToday >= 0 && daysFromToday < daysPerWeek
```

This caused "3 days a week" to only show on:
- Day 0 (today) 
- Day 1 (tomorrow)
- Day 2 (day after tomorrow)

After that, `daysFromToday` would be >= 3, so the function returned `false`.

### Why This Was Wrong

For **frequency-based schedules**, the habit should appear **EVERY day**, and the user decides which specific days to complete it. The completion tracking system should then hide it once it's been completed the required number of times that week.

This is the intended behavior for:
- "3 days a week" → Show every day, complete any 3 days
- "5 days a week" → Show every day, complete any 5 days
- "once a week" → Show every day, complete 1 day

## Correct Behavior

The correct logic (already implemented in `StreakDataCalculator.swift`) was:

```swift
// ✅ CORRECT: Show every day after start date
let calendar = Calendar.current
let targetDate = calendar.startOfDay(for: date)
let startDate = calendar.startOfDay(for: habit.startDate)
let isAfterStart = targetDate >= startDate
return isAfterStart
```

## Files Fixed

### 1. `/Views/Tabs/HomeTabView.swift` (line 845-868)

**BEFORE:**
```swift
private func shouldShowHabitWithFrequency(habit: Habit, date: Date) -> Bool {
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

**AFTER:**
```swift
private func shouldShowHabitWithFrequency(habit: Habit, date: Date) -> Bool {
  guard let daysPerWeek = extractDaysPerWeek(from: habit.schedule) else {
    return false
  }

  let calendar = Calendar.current
  let targetDate = calendar.startOfDay(for: date)
  let startDate = calendar.startOfDay(for: habit.startDate)

  // ✅ FIX: For frequency-based habits (e.g., "3 days a week"), the habit should appear EVERY day
  // after the start date. The user decides which days to complete it.
  // Completion tracking will hide it once completed the required number of times that week.
  let isAfterStart = targetDate >= startDate
  
  // Check if habit has ended
  if let endDate = habit.endDate {
    let endDateStart = calendar.startOfDay(for: endDate)
    if targetDate > endDateStart {
      return false
    }
  }
  
  return isAfterStart
}
```

### 2. `/Core/UI/Forms/HabitInstanceLogic.swift` (line 183-206)

Applied the **same fix** for consistency across all views that display habits.

### 3. `/Core/Data/StreakDataCalculator.swift` (line 943-952)

**Already had correct logic** - no changes needed. This was the reference implementation.

## Testing

- ✅ Code compiles successfully
- ✅ Build succeeded with no errors
- ✅ All views use consistent logic now

## User Action Required

**Please test the fix:**

1. Open the app
2. Navigate to the home view
3. Check if "Habit4" now appears:
   - ✅ On Oct 30 (Wed)
   - ✅ On Oct 31 (Thu)
   - ✅ On Nov 1 (Fri)
   - ✅ On Nov 2 (Sat)
   - ✅ And every day going forward
4. Complete the habit on any 3 days of the week
5. Verify it stops showing after you've completed it 3 times in that week

## Expected Behavior After Fix

For a habit with "3 days a week" schedule:
- **Shows:** Every single day of the week (7 days)
- **User completes:** On any 3 days they choose
- **Completion tracking:** Hides habit after 3 completions in the current week
- **Next week:** Resets and shows every day again

This gives users flexibility to choose which specific days they want to complete the habit, rather than forcing them to do it on the first 3 consecutive days.

## Related Files

- `Views/Tabs/HomeTabView.swift` - Main habit display view (FIXED)
- `Core/UI/Forms/HabitInstanceLogic.swift` - Habit instance logic (FIXED)
- `Core/Data/StreakDataCalculator.swift` - Streak calculations (Already correct)
- `Core/Models/New/HabitSchedule.swift` - New schedule enum (Correct logic in comments)

## Date: October 29, 2025

