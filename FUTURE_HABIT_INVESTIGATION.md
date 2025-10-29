# 🔍 Future Habit Investigation

## Problem Report
User reports that "Future habit" (start date Oct 31st) is appearing on dates **before** Oct 31st (like Oct 27th, 28th, 29th, 30th).

## Investigation Steps

### 1. Check Exact Start Dates
From console:
```
[0] 'Future habit' - Start: 2025-10-30 23:00:00 +0000
[2] 'Habit future' - Start: 2025-10-30 23:00:00 +0000
```

**Key Finding**: `2025-10-30 23:00:00 UTC`
- User timezone: Europe/Amsterdam (CET = UTC+1 in late October)
- UTC time: Oct 30th 11:00 PM
- Amsterdam time: Oct 31st 12:00 AM (midnight)
- **This is correct!**

### 2. Date Filtering Logic
From `HomeTabView.swift`:
```swift
let selected = DateUtils.startOfDay(for: selectedDate)
let start = DateUtils.startOfDay(for: habit.startDate)
let end = habit.endDate.map { DateUtils.startOfDay(for: $0) } ?? Date.distantFuture

guard selected >= start, selected <= end else {
  print("EXCLUDED: outside date range")
  return false
}
```

**This logic looks correct.**

### 3. Possible Issues
1. **Two similar habits**: "Future habit" vs "Habit future" - are they both showing?
2. **Calendar timezone issue**: `Calendar.current` might not be using correct timezone
3. **Date picker issue**: When creating habit, date might be saved incorrectly
4. **Stale data**: UI might be showing old cached data

### 4. Debug Strategy
Need to add specific logging for "Future habit" to see:
- Exact start date being used in filter
- Exact selected date being compared
- Result of the comparison

## Next Steps
Add detailed diagnostic logging to identify why the filter is failing.

