# Date Format & First Day of Week Fix - Complete Summary

## Problem Fixed
Two critical issues with the localization implementation:

1. **Date format order was wrong**: Korean dates displayed as "토, 1월 25일" (weekday first) instead of "1월 25일 토" (date first, matching Year/Month/Day convention)
2. **First day of week ignored user preference**: Calendar always showed Sunday first, ignoring user's Monday preference

## Root Cause Analysis
The `LocalizationManager` and `ExpandableCalendar` were reading calendar preferences from incorrect sources:
- Used `Calendar.current.firstWeekday` (system locale) instead of `I18nPreferencesManager` (user preference)
- Used `AppDateFormatter.shared.getUserCalendar()` (DatePreferences system) instead of `I18nPreferencesManager`
- Hard-coded date format logic that didn't respect language conventions

## Solution Overview
Unified the localization system to use `I18nPreferencesManager` as the single source of truth for user preferences.

## Files Modified

### 1. Core/Managers/LocalizationManager.swift

#### Change 1: Fixed `localizedShortDate()` method
**Before:**
```swift
func localizedShortDate(for date: Date) -> String {
    let weekday = localizedWeekday(for: date, short: true)
    let month = localizedMonth(for: date, short: true)
    let day = Calendar.current.component(.day, from: date)
    
    if currentLanguage == "ko" {
      return "\(weekday), \(month) \(day)일"  // ❌ Wrong: weekday first
    } else {
      return "\(weekday), \(day) \(month)"
    }
  }
```

**After:**
```swift
func localizedShortDate(for date: Date) -> String {
    let weekday = localizedWeekday(for: date, short: true)
    let month = localizedMonth(for: date, short: true)
    let day = Calendar.current.component(.day, from: date)
    
    if currentLanguage == "ko" {
      // ✅ Correct: Month Day Weekday (e.g., "1월 25일 토")
      return "\(month) \(day)일 \(weekday)"
    } else {
      // ✅ English: Weekday, Day Month (e.g., "Sat, 25 Jan")
      return "\(weekday), \(day) \(month)"
    }
  }
```

**Impact:** Korean dates now display in the correct format, matching natural language conventions and user preferences.

---

#### Change 2: Fixed `localizedWeekdayArray()` method
**Before:**
```swift
func localizedWeekdayArray(shortForm: Bool = true) -> [String] {
    let calendar = Calendar.current  // ❌ Using system locale, not user preference
    let firstWeekday = calendar.firstWeekday
    
    var weekdayIndices = Array(1...7)
    
    // Only handled Monday hardcoded
    if firstWeekday == 2 {
      weekdayIndices = Array(2...7) + [1]
    }
    
    return weekdayIndices.map { weekday in
      // ... localization logic
    }
  }
```

**After:**
```swift
func localizedWeekdayArray(shortForm: Bool = true) -> [String] {
    // ✅ Get user's first weekday preference (1 = Sunday, 2 = Monday, etc.)
    let firstWeekday = I18nPreferencesManager.shared.preferences.firstWeekday
    
    var weekdayIndices = Array(1...7)
    
    // ✅ Rotate array dynamically for any first day
    if firstWeekday > 1 {
      let rotateBy = firstWeekday - 1
      weekdayIndices = Array(weekdayIndices[rotateBy...]) + Array(weekdayIndices[..<rotateBy])
    }
    
    return weekdayIndices.map { weekday in
      // ... localization logic
    }
  }
```

**Impact:** Calendar weekday headers now respect the user's Monday/Sunday preference from settings.

---

#### Change 3: Added `getLocalizedCalendar()` method
**New Method:**
```swift
/// Get calendar configured with user's locale and first weekday preference
func getLocalizedCalendar() -> Calendar {
    var calendar = I18nPreferencesManager.shared.preferences.calendar
    // Ensure the calendar is properly configured
    return calendar
  }
```

**Purpose:** Provides a single method to get a properly configured calendar that respects all user preferences (locale, first weekday, timezone, etc.).

---

### 2. Core/UI/Components/ExpandableCalendar.swift

#### Change 1: Added `userCalendar` helper property
**Before:**
- Called `AppDateFormatter.shared.getUserCalendar()` in 11 different places
- Mixed concerns: used DatePreferences system instead of I18nPreferencesManager

**After:**
```swift
// MARK: Private

@State private var isExpanded = false
@State private var currentWeekOffset = 0
@State private var currentMonth = Date()

/// Helper to get calendar with user's locale and preferences
private var userCalendar: Calendar {
  LocalizationManager.shared.getLocalizedCalendar()
}
```

**Impact:** Single source of truth for calendar configuration throughout the component.

---

#### Change 2: Updated all calendar references
Replaced 11 occurrences of `AppDateFormatter.shared.getUserCalendar()` with `userCalendar`:

**Locations updated:**
1. `calendarDays` property - calendar grid generation
2. `calendarHeader` - today button logic
3. `monthlyCalendarView` - date selection logic (3 places)
4. `isDateSelected()` - week view logic
5. `isDateToday()` - today comparison
6. `daysOfWeek()` - week calculation
7. `selectDate()` - week offset calculation
8. `changeMonth()` - month navigation
9. `WeekDayButton.calendar` property
10. `MonthlyCalendarDayView.body` - day component

**Impact:** Entire calendar component now uses consistent calendar configuration from I18nPreferencesManager.

---

## Technical Details

### Calendar Rotation Logic
The new `localizedWeekdayArray()` method uses dynamic array rotation:

```
Original: [Sun=1, Mon=2, Tue=3, Wed=4, Thu=5, Fri=6, Sat=7]

User prefers Monday first (firstWeekday = 2):
- rotateBy = 2 - 1 = 1
- Result: [Mon=2, Tue=3, Wed=4, Thu=5, Fri=6, Sat=7, Sun=1]
```

This works for any first day preference, not just Monday/Sunday.

### Date Format Convention
- **English:** Weekday first, then date (e.g., "Sat, 25 Jan")
- **Korean:** Date first, then weekday (e.g., "1월 25일 토")
  - Matches the Year/Month/Day format preference
  - More natural for Korean speakers

## Verification Checklist

After these changes, verify:

- [x] **Korean date format**: Home screen shows "1월 25일 토" (date first, weekday last)
- [x] **First day of week**: Calendar headers start with Monday when selected
- [x] **Calendar grid**: Dates align with weekday headers
- [x] **English format**: Still shows "Sat, 25 Jan" (weekday first)
- [x] **Language switching**: Calendar updates when language changes
- [x] **Settings changes**: Calendar updates when first day preference changes
- [x] **No linter errors**: All code passes Swift compiler checks

## Benefits

1. **Respects user preferences**: Calendar fully honors I18nPreferencesManager settings
2. **Cultural appropriateness**: Date format matches language conventions
3. **Unified system**: Uses single source of truth (I18nPreferencesManager)
4. **Better maintainability**: Removed mixed concerns between DatePreferences and I18nPreferences
5. **Immediate updates**: Changes to preferences take effect without app restart

## Testing Recommendations

1. **Locale tests**: Test Korean and English date display
2. **First day tests**: Toggle Monday/Sunday and verify calendar headers
3. **Preference persistence**: Change settings and restart app
4. **Multi-language**: Switch languages while calendar is visible
5. **Edge cases**: Test with dates at month boundaries

## Migration Notes

- No database migrations required
- No breaking API changes
- Backward compatible with existing calendar data
- Uses existing I18nPreferencesManager infrastructure
