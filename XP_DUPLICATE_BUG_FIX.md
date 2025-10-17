# XP Duplicate Bug Fix

## Critical Bug Found

After implementing the historical XP recovery feature, a critical bug was discovered:

**Every time the user visited the home screen, XP was being awarded again for the same completed days, causing duplicate XP awards.**

## Root Cause

The bug had TWO causes:

### 1. Missing DailyAward Record Creation
When XP was awarded, the code was:
- ✅ Calling `DailyAwardService.awardDailyCompletionBonus()` to award XP
- ✅ Updating `XPManager` with the new XP
- ❌ **NOT creating a `DailyAward` record in SwiftData**

This meant that every time the check ran, it would:
1. Query for existing `DailyAward` records
2. Find none (because they were never created)
3. Award XP again (duplicate!)

### 2. Running Check on Every onAppear
The `checkAndAwardMissingXPForPreviousDays()` function was called in `onAppear`, which triggers:
- Every time the HomeTabView appears
- When switching tabs and coming back
- When the app comes to foreground
- When navigating between dates

## Solution Implemented

### Fix 1: Create DailyAward Records (CRITICAL)

Added `DailyAward` record creation in **THREE** places where XP is awarded:

#### Location 1: Historical XP Recovery (Lines 1055-1063)
```swift
// After awarding XP retroactively for past days
let dailyAward = DailyAward(
  userId: userId,
  dateKey: dateKey,
  xpGranted: xpGranted,
  allHabitsCompleted: true
)
modelContext.insert(dailyAward)
try modelContext.save()
```

#### Location 2: Current Date Check (Lines 1143-1152)
```swift
// After awarding XP for current date if missed
let dailyAward = DailyAward(
  userId: userId,
  dateKey: dateKey,
  xpGranted: xpGranted,
  allHabitsCompleted: true
)
modelContext.insert(dailyAward)
try modelContext.save()
```

#### Location 3: Interactive Completion Flow (Lines 1337-1346)
```swift
// After awarding XP when user completes last habit interactively
let dailyAward = DailyAward(
  userId: userId,
  dateKey: dateKey,
  xpGranted: xpGranted,
  allHabitsCompleted: true
)
modelContext.insert(dailyAward)
try modelContext.save()
```

### Fix 2: Session-Based Deduplication

Added a state variable to track if the historical check has already run:

```swift
/// ✅ FIX: Track if we've already checked for missing XP this session
@State private var hasCheckedMissingXP = false
```

Modified the `onAppear` handler:
```swift
// ✅ FIX: Check for missing XP awards (only once per session)
if !hasCheckedMissingXP {
  await checkAndAwardMissingXPForPreviousDays()
  hasCheckedMissingXP = true
}
```

## How It Works Now

### Complete XP Award Flow

```
User completes all habits OR app checks history
    ↓
Award XP via DailyAwardService
    ↓
Update XPManager for UI
    ↓
✅ NEW: Create DailyAward record in SwiftData
    ↓
Save to database
    ↓
Next check sees DailyAward exists → Skip (no duplicate)
```

### Duplicate Prevention Mechanisms

1. **Database Record:** `DailyAward` record in SwiftData acts as source of truth
2. **Unique Constraint:** `DailyAward` has unique constraint on `(userId, dateKey)`
3. **Session Flag:** Historical check only runs once per app session
4. **Query Before Award:** Always checks if `DailyAward` exists before awarding

## Testing Verification

### Test Case 1: Initial Load
1. Open app with completed habits (no XP awarded yet)
2. **Expected:** XP awarded once, DailyAward created
3. Navigate away and back to home
4. **Expected:** No duplicate XP, log shows "XP already awarded for [date] ✅"

### Test Case 2: Multiple Tab Switches
1. Complete all habits for today
2. Switch to Progress tab
3. Switch back to Home tab (triggers onAppear)
4. Repeat 10 times
5. **Expected:** XP only awarded once on first completion

### Test Case 3: App Background/Foreground
1. Complete all habits
2. Receive XP
3. Put app in background
4. Return to foreground
5. **Expected:** No duplicate XP awarded

### Test Case 4: Date Navigation
1. Complete habits for today
2. Navigate to tomorrow
3. Navigate back to today
4. **Expected:** No duplicate XP, existing award recognized

## Console Log Verification

When functioning correctly, you should see:

**First time (awards XP):**
```
🎯 checkAndAwardMissingXPForPreviousDays: No XP award found for 2024-10-17, awarding retroactively!
✅ Retroactive XP awarded for 2024-10-17! (+50 XP)
✅ DailyAward record created in SwiftData
```

**Subsequent times (prevents duplicate):**
```
🎯 checkAndTriggerCelebrationIfAllCompleted: XP already awarded for 2024-10-17 ✅
```

## Files Modified

- `Views/Tabs/HomeTabView.swift`
  - Added `hasCheckedMissingXP` state variable (line 175)
  - Modified `onAppear` to check flag (lines 71-74)
  - Added DailyAward creation in 3 locations (lines 1055-1063, 1143-1152, 1337-1346)

## Summary

The duplicate XP bug is now **completely fixed** with a two-layer defense:

1. **Persistent Check:** `DailyAward` records in SwiftData prevent duplicates across app sessions
2. **Session Check:** `hasCheckedMissingXP` flag prevents duplicates within same session

Users can now safely:
- Navigate between tabs
- Switch dates
- Put app in background/foreground
- Reopen the app

**Without receiving duplicate XP awards!** ✅

## Date of Fix

October 17, 2025 (Immediate fix for critical duplicate bug)

