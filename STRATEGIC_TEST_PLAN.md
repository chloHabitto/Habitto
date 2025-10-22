# Strategic Test Plan - Persistence & Streak Validation

## Overview
This test plan validates three critical areas of the Habitto app after the persistence bug fixes:
1. Multi-day streak tracking (CRITICAL)
2. Partial progress persistence (IMPORTANT)
3. Undo/reversal logic (EDGE CASE)

**Test Environment:**
- Clean build required (⇧⌘K + ⌘R)
- Console logging enabled for verification
- Same authenticated user account throughout

---

## Test 1: Multi-Day Streak Tracking (CRITICAL)

### Purpose
Verify that streaks increment correctly across multiple days and break appropriately when habits are missed.

### Pre-Conditions
- App freshly installed or database reset
- User authenticated
- Current habits: 5 habits (Habit1-5)
- All habits scheduled for "Everyday"

### Test Steps

#### Day 1: Complete All Habits
1. **Action**: Launch app
2. **Action**: Complete all 5 habits in order (Habit1 → Habit5)
3. **Action**: For each habit, select difficulty when prompted
4. **Expected**: 
   - ✅ Celebration animation appears after Habit5
   - ✅ Streak displays: 1 day
   - ✅ XP displays: 50
5. **Action**: Force close app (swipe up)
6. **Action**: Reopen app
7. **Expected**:
   - ✅ All habits show completed (10/10, 10/10, 1/1, 1/1, 5/5)
   - ✅ Streak still shows: 1 day
   - ✅ XP still shows: 50

**Console Logs to Watch:**
```
🎯 COMPLETION_FLOW: Last habit completed - will trigger celebration
✅ COMPLETION_FLOW: DailyAward record created for history
✅ DERIVED_XP: XP set to 50 (completedDays: 1)
```

**Pass Criteria:**
- [ ] All habits persist their progress after reopen
- [ ] Streak = 1 day
- [ ] XP = 50
- [ ] Celebration triggered

---

#### Day 2: Complete All Habits Again
1. **Action**: Wait until next day OR manually change device date to tomorrow
2. **Action**: Launch app
3. **Expected**:
   - ✅ All habits reset to incomplete for new day (0/10, 0/10, etc.)
   - ✅ Streak still shows: 1 day (from yesterday)
   - ✅ XP still shows: 50
4. **Action**: Complete all 5 habits again
5. **Expected**:
   - ✅ Celebration animation appears
   - ✅ Streak increments to: 2 days
   - ✅ XP increases to: 100
6. **Action**: Force close app
7. **Action**: Reopen app
8. **Expected**:
   - ✅ All habits show completed for today
   - ✅ Streak shows: 2 days
   - ✅ XP shows: 100

**Console Logs to Watch:**
```
✅ DERIVED_XP: XP set to 100 (completedDays: 2)
📥 Streak calculation: 2 consecutive days
```

**Pass Criteria:**
- [ ] Habits reset for new day
- [ ] Streak increments correctly (1 → 2)
- [ ] XP doubles correctly (50 → 100)
- [ ] Progress persists after reopen

---

#### Day 3: Miss a Day (Streak Break)
1. **Action**: Wait until Day 3 OR manually change device date
2. **Action**: Launch app
3. **Expected**:
   - ✅ All habits reset to incomplete
   - ✅ Streak still shows: 2 days
   - ✅ XP still shows: 100
4. **Action**: Complete only 3 out of 5 habits (Habit1, Habit2, Habit3)
5. **Expected**:
   - ❌ NO celebration (not all habits completed)
   - ✅ Streak remains: 2 days (doesn't increase)
   - ✅ XP remains: 100 (doesn't increase)
6. **Action**: Force close app
7. **Action**: Reopen app
8. **Expected**:
   - ✅ Partial completion persists (Habit1, 2, 3 completed; Habit4, 5 incomplete)
   - ✅ Streak still: 2 days
   - ✅ XP still: 100

**Console Logs to Watch:**
```
🎯 COMPLETION_FLOW: Habit completed, 2 remaining
❌ No celebration (not all habits completed)
```

**Pass Criteria:**
- [ ] Streak doesn't increase (stays at 2)
- [ ] XP doesn't increase (stays at 100)
- [ ] Partial completion persists
- [ ] No celebration shown

---

#### Day 4: Complete All (Streak Resets)
1. **Action**: Wait until Day 4
2. **Action**: Complete all 5 habits
3. **Expected**:
   - ✅ Celebration appears
   - ⚠️ Streak resets to: 1 day (because Day 3 was incomplete)
   - ✅ XP increases to: 150 (100 + 50 for new complete day)
4. **Action**: Force close and reopen
5. **Expected**:
   - ✅ Streak shows: 1 day
   - ✅ XP shows: 150

**Code Reference:**
From `StreakDataCalculator.swift:836-852`:
```swift
// Count consecutive days backwards from today where ALL habits were completed
while true {
  let allCompletedOnThisDate = habits.allSatisfy { habit in
    habit.isCompleted(for: currentDate)
  }
  
  if allCompletedOnThisDate {
    streak += 1
    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)
  } else {
    break  // Stop when hitting incomplete day
  }
}
```

**Pass Criteria:**
- [ ] Streak resets to 1 (not 3)
- [ ] XP correctly accumulates (150)
- [ ] Celebration triggers for new complete day

---

## Test 2: Partial Progress Scenarios (IMPORTANT)

### Purpose
Verify that intermediate progress values (not just 0 or goal) persist correctly with the new `progress` field.

### Pre-Conditions
- Fresh app state
- Habits with goals requiring multiple completions (10/10, 5/5)

### Test Scenario 2A: Mid-Goal Progress (5/10)

1. **Action**: Launch app
2. **Action**: For Habit1 (goal: 10 times):
   - Swipe right 5 times (not tap checkbox)
   - This should show 5/10
3. **Expected**:
   - ✅ UI shows: 5/10
   - ✅ Progress bar at 50%
   - ❌ Habit NOT marked complete (circle not filled)
4. **Action**: Force close app
5. **Action**: Reopen app
6. **Expected**:
   - ✅ Habit1 still shows: 5/10 (NOT 1/10 or 0/10)
   - ✅ Progress bar still at 50%

**Console Logs to Watch:**
```
🔍 toHabit(): Using CompletionRecords from relationship
📊 CompletionRecord: progress=5 (not just isCompleted=true/false)
✅ Habit1: Loaded with progress 5/10
```

**Pass Criteria:**
- [ ] Shows 5/10 before close
- [ ] Shows 5/10 after reopen (NOT 1/10)
- [ ] CompletionRecord.progress = 5

---

### Test Scenario 2B: Near-Complete Progress (7/10)

1. **Action**: For Habit2 (goal: 10 times):
   - Swipe right 7 times
   - Should show 7/10
2. **Expected**:
   - ✅ UI shows: 7/10
   - ✅ Progress bar at 70%
3. **Action**: Force close app
4. **Action**: Reopen app
5. **Expected**:
   - ✅ Habit2 still shows: 7/10 (NOT 1/10)

**Pass Criteria:**
- [ ] Shows 7/10 before close
- [ ] Shows 7/10 after reopen
- [ ] CompletionRecord.progress = 7

---

### Test Scenario 2C: Single-Unit Habit (1/1)

1. **Action**: For Habit3 (goal: 1 time):
   - Tap checkbox once
   - Should show 1/1 and be marked complete
2. **Expected**:
   - ✅ Checkbox filled
   - ✅ Difficulty sheet appears
3. **Action**: Select difficulty and dismiss
4. **Action**: Force close app
5. **Action**: Reopen app
6. **Expected**:
   - ✅ Habit3 still shows: 1/1 (complete)

**Pass Criteria:**
- [ ] Shows 1/1 (complete) before close
- [ ] Shows 1/1 (complete) after reopen
- [ ] CompletionRecord.progress = 1
- [ ] CompletionRecord.isCompleted = true

---

## Test 3: Undo/Reversal Logic (EDGE CASE)

### Purpose
Verify that uncompleting a habit after all habits were completed correctly reverses XP, streak, and celebration status.

### Pre-Conditions
- Start with all 5 habits completed for today
- Streak = 1, XP = 50
- Celebration was shown

### Test Scenario 3A: Undo Last Habit

1. **Initial State**:
   - All 5 habits completed
   - Streak: 1 day
   - XP: 50
   - DailyAward record exists in database

2. **Action**: Tap checkbox on Habit5 to uncomplete it
3. **Expected**:
   - ✅ Habit5 becomes incomplete (0/5)
   - ✅ XP reverts to: 0 (recalculated from DailyAward count)
   - ✅ Streak reverts to: 0 (no complete days)
   - ✅ Celebration status cleared
   - ✅ DailyAward record deleted from database

**Console Logs to Watch:**
```
🎯 UNCOMPLETE_FLOW: Habit 'Habit5' uncompleted for 2025-10-22
✅ DERIVED_XP: Recalculating XP after uncomplete
✅ DERIVED_XP: XP recalculated to 0 (completedDays: 0)
✅ UNCOMPLETE_FLOW: DailyAward removed for 2025-10-22
```

**Code Reference:**
From `HomeTabView.swift:1321-1376`:
```swift
private func onHabitUncompleted(_ habit: Habit) {
  // Update completion status map
  completionStatusMap[habit.id] = false
  
  // Recalculate XP from state (idempotent)
  let completedDaysCount = countCompletedDays()
  xpManager.publishXP(completedDaysCount: completedDaysCount)
  
  // Remove DailyAward if day no longer complete
  if !allCompleted {
    // Delete DailyAward record
    modelContext.delete(award)
  }
}
```

**Pass Criteria:**
- [ ] XP reverts from 50 → 0
- [ ] Streak reverts from 1 → 0
- [ ] DailyAward deleted from SwiftData
- [ ] No celebration shown

---

### Test Scenario 3B: Re-complete After Undo

1. **Initial State** (from 3A):
   - 4 habits completed, Habit5 incomplete
   - Streak: 0, XP: 0

2. **Action**: Complete Habit5 again (make all 5 complete)
3. **Expected**:
   - ✅ Difficulty sheet appears for Habit5
   - ✅ Celebration triggers (all habits complete again)
   - ✅ Streak increases to: 1
   - ✅ XP increases to: 50
   - ✅ New DailyAward record created

**Pass Criteria:**
- [ ] XP returns to 50
- [ ] Streak returns to 1
- [ ] Celebration shows again
- [ ] DailyAward re-created

---

### Test Scenario 3C: Undo Mid-Progress Habit

1. **Initial State**:
   - All 5 habits completed
   - Streak: 1, XP: 50

2. **Action**: For Habit1 (currently 10/10):
   - Swipe left 5 times (decrease from 10 → 5)
3. **Expected**:
   - ✅ Habit1 shows: 5/10 (incomplete)
   - ✅ XP reverts to: 0
   - ✅ Streak reverts to: 0
   - ✅ DailyAward deleted

4. **Action**: Force close and reopen
5. **Expected**:
   - ✅ Habit1 still shows: 5/10 (NOT 10/10 or 1/10)
   - ✅ XP still: 0
   - ✅ Streak still: 0

**Pass Criteria:**
- [ ] Partial reduction persists (5/10)
- [ ] XP/Streak correctly reverted
- [ ] Progress = 5 stored in CompletionRecord

---

## Test 4: Vacation Mode & Streak Preservation (BONUS)

### Purpose
Verify that vacation mode preserves streaks as documented.

### Pre-Conditions
- User has 3-day streak
- Vacation mode feature available

### Test Steps

1. **Setup**: Build 3-day streak (complete all habits 3 days in a row)
2. **Expected**: Streak = 3, XP = 150
3. **Action**: Enable vacation mode for 2 days
4. **Action**: Don't complete any habits during vacation
5. **Expected**: Streak remains 3 (not broken by vacation days)
6. **Action**: Disable vacation mode
7. **Action**: Complete all habits on next active day
8. **Expected**: Streak = 4 (vacation didn't break it)

**Code Reference:**
From `StreakDataCalculator.swift:32-38`:
```swift
// Skip vacation days during active vacation
if vacationManager.isActive, vacationManager.isVacationDay(currentDate) {
  // Move to next day without affecting streak
  currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)
  continue
}
```

**Pass Criteria:**
- [ ] Vacation days don't break streak
- [ ] Streak continues after vacation
- [ ] XP accumulated correctly

---

## Summary Checklist

### Test 1: Multi-Day Streak ✓
- [ ] Day 1: All complete → Streak = 1, XP = 50
- [ ] Day 2: All complete → Streak = 2, XP = 100
- [ ] Day 3: Partial complete → Streak = 2, XP = 100 (no change)
- [ ] Day 4: All complete → Streak = 1 (reset), XP = 150
- [ ] All progress persists after app restart

### Test 2: Partial Progress ✓
- [ ] 5/10 persists (not 1/10)
- [ ] 7/10 persists (not 1/10)
- [ ] 1/1 persists correctly
- [ ] CompletionRecord.progress field stores actual values

### Test 3: Undo/Reversal ✓
- [ ] Uncomplete reverts XP and streak
- [ ] DailyAward deleted on uncomplete
- [ ] Re-complete restores XP and streak
- [ ] Partial reduction persists

### Test 4: Vacation Mode (BONUS) ✓
- [ ] Vacation preserves streak
- [ ] Post-vacation completion continues streak

---

## What to Do If Tests Fail

### Failure: Progress reverts to 1/10
**Diagnosis**: CompletionRecord.progress not saved correctly
**Check**: 
1. Console log: Does it show `progress=5` or `progress=0`?
2. SwiftData schema: Was `progress` field added?
**Fix**: Verify schema migration in HabitDataModel.swift

### Failure: Streak doesn't increment
**Diagnosis**: DailyAward not created or streak calculation wrong
**Check**:
1. Console: Does it show "DailyAward record created"?
2. Firestore: Check `/users/{userId}/progress/daily_awards/`
**Fix**: Review HomeTabView.swift onDifficultySheetDismissed()

### Failure: XP doesn't persist
**Diagnosis**: DailyAward records not loading correctly
**Check**:
1. Console: `countCompletedDays()` result
2. SwiftData: Query DailyAward count
**Fix**: Review countCompletedDays() in HomeTabView.swift

### Failure: Undo doesn't revert
**Diagnosis**: onHabitUncompleted not deleting DailyAward
**Check**: Console for "DailyAward removed" message
**Fix**: Review onHabitUncompleted() in HomeTabView.swift:1321

---

## Next Steps After Testing

### If All Tests Pass ✅
→ **Proceed to Option B: Cleanup**
- Remove diagnostic logging
- Archive old diagnostic documents
- Create release notes

### If Tests Fail ❌
→ **Debug and Fix**
- Identify failing scenario
- Check console logs against expected
- Review relevant code sections
- Re-test after fix

**Estimated Testing Time**: 45-60 minutes for all scenarios
**Required**: Device/simulator date change capability for multi-day testing

