# Widget Date Key Timezone Mismatch Investigation

## Summary

**CRITICAL ISSUE FOUND**: The widget uses **UTC timezone** to generate date keys, but the app uses **local timezone** (`TimeZone.current`). This causes off-by-one-day errors when the widget tries to look up completion data.

## How Date Keys Are Generated

### App (Main Habitto App)
- **Location**: `Core/Utils/DateUtils.swift`
- **Function**: `DateUtils.dateKey(for:)`
- **Timezone**: `TimeZone.current` (device's local timezone)
- **Code**:
```swift
private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current  // ✅ Uses LOCAL timezone
    return formatter
}()
```

### Widget (HabittoWidgetExtension)
- **Location**: `HabittoWidget/MonthlyProgressWidget.swift`
- **Function**: `formatDateKey(for:)` (appears twice: lines 331 and 745)
- **Timezone**: `TimeZone(secondsFromGMT: 0)` (UTC)
- **Code**:
```swift
private func formatDateKey(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)  // ❌ Uses UTC
    let key = formatter.string(from: date)
    return key
}
```

## Data Flow

1. **App saves completion data**:
   - Uses `Habit.dateKey(for: Date())` → calls `DateUtils.dateKey(for:)`
   - Generates key like `"2026-01-12"` using **local timezone**
   - Stores in `habit.completionStatus["2026-01-12"] = true`

2. **App syncs to widget**:
   - `WidgetDataSync.syncHabitsToWidget()` copies dictionaries directly:
   ```swift
   completionHistory: habit.completionHistory,  // Direct copy
   completionStatus: habit.completionStatus      // Direct copy
   ```
   - Date keys are preserved as-is (e.g., `"2026-01-12"`)

3. **Widget looks up completion data**:
   - Uses `formatDateKey(for: date)` with **UTC timezone**
   - Generates key like `"2026-01-11"` or `"2026-01-12"` depending on UTC time
   - Tries to find `habitData.completionStatus["2026-01-11"]` → **NOT FOUND** ❌

## Example Scenario

**User in Amsterdam (UTC+1) at 12:30 AM on Jan 13, 2026:**

| Component | Time | Date Key Generated | Stored/Looked Up |
|-----------|------|-------------------|------------------|
| **App** | 12:30 AM (local) = 11:30 PM UTC (Jan 12) | `"2026-01-13"` | ✅ Stored in `completionStatus["2026-01-13"]` |
| **Widget** | 12:30 AM (local) = 11:30 PM UTC (Jan 12) | `"2026-01-12"` | ❌ Looks for `completionStatus["2026-01-12"]` → **MISSING** |

**Result**: Widget shows incomplete day even though app marked it complete!

## What to Look For in Console Logs

### From Widget Extension Logs

Look for these log lines in Xcode Console (filter by "HabittoWidgetExtension"):

1. **Stored date keys** (from app):
```
🔍 WIDGET getWeeklyProgress: Received habitData:
   completionStatus keys: ["2026-01-11", "2026-01-12", "2026-01-13"]
   completionHistory keys: ["2026-01-11", "2026-01-12", "2026-01-13"]
```

2. **Generated date keys** (by widget):
```
   Mon (day 0): date=2026-01-13 00:00:00 +0000, normalized=2026-01-13 00:00:00 +0000, dateKey='2026-01-12'
      formatDateKey: date=2026-01-13 00:00:00 +0000 -> key='2026-01-12' (UTC timezone)
      statusExists=false, statusValue=false
      historyExists=false, historyValue=0
      isCompleted=false ❌
```

### Comparison Pattern

**If keys match**: ✅ Widget will find completion data
```
Stored:  ["2026-01-12"]
Generated: "2026-01-12"
Result: ✅ Found!
```

**If keys don't match**: ❌ Widget won't find completion data
```
Stored:  ["2026-01-13"]  (app saved in local timezone)
Generated: "2026-01-12"  (widget generated in UTC)
Result: ❌ Not found!
```

## How to Capture Logs

1. **Open Xcode Console**:
   - View → Debug Area → Activate Console (⇧⌘C)
   - Filter by "HabittoWidgetExtension"

2. **Trigger widget update**:
   - Add widget to home screen
   - Or wait for automatic refresh
   - Or manually refresh widget

3. **Look for these specific log lines**:
   - `completionStatus keys:` - Shows what keys are STORED (from app)
   - `formatDateKey: date=` - Shows what keys are GENERATED (by widget)
   - `dateKey='...'` - The actual key being looked up

4. **Compare**:
   - If stored keys are `["2026-01-13"]` but widget generates `"2026-01-12"` → **MISMATCH** ❌
   - If stored keys are `["2026-01-12"]` and widget generates `"2026-01-12"` → **MATCH** ✅

## Fix Required

The widget's `formatDateKey(for:)` function should use `TimeZone.current` instead of UTC:

```swift
// ❌ CURRENT (WRONG):
formatter.timeZone = TimeZone(secondsFromGMT: 0)

// ✅ SHOULD BE:
formatter.timeZone = TimeZone.current
```

This will ensure the widget generates date keys in the same timezone as the app, preventing off-by-one-day errors.

## Testing the Timezone Mismatch

### Automatic Test in Widget

A test function has been added to the widget that automatically runs when calculating weekly progress. It will log:

```
🔍 TIMEZONE MISMATCH TEST
   Testing date: 2026-01-12 18:30:00 +0000
   
   📱 APP (TimeZone.current):
      Timezone: Europe/Amsterdam
      Date Key: '2026-01-12'
   
   📦 WIDGET (UTC):
      Timezone: UTC
      Date Key: '2026-01-12'
   
   ⚠️  MISMATCH DETECTED! (if keys differ)
```

### Manual Test Script

Run the test script to see examples:
```bash
# Run the Swift test
swift Tests/WidgetTimezoneTest.swift

# Or analyze console logs
./Scripts/analyze_widget_timezone.sh <console_log.txt>
```

### What to Look For

When the widget runs, check the console logs for:
1. The "TIMEZONE MISMATCH TEST" section showing both date keys
2. Compare the keys - if they differ, that's the bug
3. Look at the actual stored keys vs generated keys in the weekly progress calculation

## Additional Notes

- The widget comments incorrectly state: "The app saves date keys in UTC" - this is **false**
- The app actually saves date keys using `TimeZone.current` (local timezone)
- This mismatch affects users in timezones far from UTC more severely
- Users near UTC (e.g., London in winter) may not notice the issue during certain hours
- The test function will automatically show the mismatch when the widget calculates weekly progress
