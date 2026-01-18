# Streak Bug Fix - Testing Checklist

## Quick Test (5 minutes)

### Test 1: First Habit Completion ⭐ CRITICAL
This is the primary bug being fixed.

**Setup:**
1. Delete app and reinstall (or reset all data)
2. Create one habit: "Test Habit" with goal 1
3. Open Console app, filter for "Habitto"

**Test:**
1. ✅ Complete the habit by tapping the circle button
2. ✅ Select difficulty rating
3. ✅ Dismiss the sheet

**Expected Results:**
- [ ] Streak displays as 1 (not 0)
- [ ] Day 1 milestone screen appears
- [ ] No celebration animation (milestone replaces it)

**Console Log Verification:**
Search for these patterns in order:

```
✅ GUARANTEED: Progress saved and persisted
⏳ WAIT_PERSISTENCE: Waiting for 1 operation(s)
✅ WAIT_PERSISTENCE: All persistence operations completed!
🔔 NOTIFICATION_RECEIVED #1
   newStreak: 1
   isUserInitiated: true
🎉 MILESTONE_CHECK: Streak 1 is a milestone!
```

**Pass Criteria:**
- [ ] Only ONE notification received
- [ ] `newStreak: 1` (NOT 0)
- [ ] `isUserInitiated: true`
- [ ] Milestone screen shows

**❌ FAIL if you see:**
- `newStreak: 0` with `isUserInitiated: true`
- Multiple notifications (#1, #2, #3...)
- `⚠️ MILESTONE_CHECK: Aborted - milestoneStreakCount is 0`

---

### Test 2: Streak Continuation
**Setup:**
1. After Test 1, wait until next day (or change system date)
2. OR complete another habit to continue streak

**Test:**
1. ✅ Complete the habit again
2. ✅ Dismiss sheet

**Expected Results:**
- [ ] Streak updates to 2
- [ ] Celebration animation plays (no milestone for streak 2)

---

### Test 3: Rapid Taps (Race Condition Test)
**Setup:**
1. Uncomplete the habit (tap circle when completed)
2. Console open

**Test:**
1. ✅ Tap circle button rapidly 5 times in a row
2. ✅ Watch for duplicate operations

**Expected Results:**
- [ ] No crashes
- [ ] Only one XP award
- [ ] Streak updates correctly
- [ ] Console shows proper waiting pattern

**Console Should Show:**
```
⏳ WAIT_PERSISTENCE: Waiting for 1 operation(s)
(not Waiting for 2, 3, 4, etc.)
```

---

## Detailed Test (15 minutes)

### Test 4: Multiple Habits
**Setup:**
1. Create 3 habits: "Water", "Exercise", "Read"
2. All with goal 1

**Test:**
1. ✅ Complete Water
2. ✅ Complete Exercise  
3. ✅ Complete Read (this should trigger streak update)

**Expected Results:**
- [ ] Streak updates to 1 after completing ALL habits
- [ ] Day 1 milestone appears after last habit
- [ ] Console shows: `⏳ WAIT_PERSISTENCE: Waiting for 1 operation(s)`

---

### Test 5: Uncomplete and Re-Complete
**Setup:**
1. After Test 1 (streak at 1)

**Test:**
1. ✅ Uncomplete the habit (tap completed circle)
2. ✅ Wait 2 seconds
3. ✅ Re-complete the habit
4. ✅ Dismiss sheet

**Expected Results:**
- [ ] Streak goes to 0 after uncomplete
- [ ] Streak goes back to 1 after re-complete
- [ ] Milestone can be shown again
- [ ] No duplicate XP awards

---

### Test 6: Persistence Timing Verification
**Setup:**
1. Fresh habit completion
2. Console open with timing visible

**Test:**
1. ✅ Complete habit
2. ✅ Watch console timestamps

**Verify Timing:**
```
[14:30:45] ⏳ WAIT_PERSISTENCE: Waiting for 1 operation(s)
[14:30:45] ✅ GUARANTEED: Progress saved and persisted in 0.423s
[14:30:45] ⏳ STREAK_QUEUE: Resuming 1 waiting continuation(s)
[14:30:45] ✅ WAIT_PERSISTENCE: All persistence operations completed!
[14:30:45] 🔔 NOTIFICATION_RECEIVED #1
```

**Pass Criteria:**
- [ ] Persistence completes BEFORE notification
- [ ] Duration is 0.2-0.7 seconds (reasonable)
- [ ] Only 1 continuation resumed

---

## Console Log Checklist

Open Console.app → Filter: "Habitto" → Look for these patterns:

### ✅ GOOD Patterns (Should See):
```
⏳ COMPLETION_FLOW: Waiting for persistence to complete...
✅ WAIT_PERSISTENCE: All persistence operations completed!
🔔 NOTIFICATION_RECEIVED #1
   newStreak: 1
   isUserInitiated: true
🔍 meetsStreakCriteria: habit=Test, date=2026-01-18, progress=1, goal=1
```

### ❌ BAD Patterns (Should NOT See):
```
❌ newStreak: 0 (when just completed)
❌ NOTIFICATION_RECEIVED #2 (multiple notifications)
❌ ⚠️ MILESTONE_CHECK: Aborted - milestoneStreakCount is 0
❌ Guard failed - milestoneStreakCount=0
```

---

## Bug Reproduction (Original Bug - Should NOT Reproduce Now)

If you want to verify the fix worked, try to reproduce the ORIGINAL bug:

**Original Bug Steps:**
1. Fresh install
2. Create habit
3. Complete habit
4. BUG: Streak stayed at 0, no milestone

**After Fix:**
1. Same steps
2. ✅ Streak updates to 1
3. ✅ Milestone shows
4. ✅ Console shows proper synchronization

---

## Performance Check

### Timing Expectations:
- Persistence wait: 0.2-0.7 seconds (acceptable)
- Total completion flow: 1-2 seconds
- User shouldn't notice delay (already waiting for sheet)

### If Performance Issues:
Check console for:
- `⏳ WAIT_PERSISTENCE: Waiting for 10 operation(s)` ← Too many!
- Duration > 1 second ← Too slow!

---

## Quick Debug Commands

### Force Reset for Testing:
```swift
// In Xcode console:
po UserDefaults.standard.removeObject(forKey: "lastShownMilestoneStreak")
po UserDefaults.standard.removeObject(forKey: "lastShownMilestoneDateTimestamp")
```

### Check Current Streak:
```swift
// In Xcode console:
po UserDefaults(suiteName: "group.com.habitto.widget")?.integer(forKey: "widgetCurrentStreak")
```

---

## Sign-Off

After completing all tests:

**Critical Test (Test 1):**
- [ ] PASS - Streak updates to 1
- [ ] PASS - Milestone shows
- [ ] PASS - Console logs correct

**Other Tests:**
- [ ] Test 2: Streak continuation - PASS
- [ ] Test 3: Rapid taps - PASS
- [ ] Test 4: Multiple habits - PASS
- [ ] Test 5: Uncomplete/re-complete - PASS
- [ ] Test 6: Timing verification - PASS

**Ready for deployment:** YES / NO

**Tester:** _________________  
**Date:** _________________  
**Notes:** _________________

---

## Troubleshooting

### If Test 1 Fails:

1. Check Console for `NOTIFICATION_RECEIVED` lines
2. If `newStreak: 0` appears:
   - Check: Did persistence complete first?
   - Look for: `✅ WAIT_PERSISTENCE: All persistence operations completed!`
   - If missing: The wait mechanism isn't working

3. If multiple notifications appear:
   - This indicates the old race condition
   - Check: Is `onWaitForPersistence` callback wired correctly?

4. If milestone doesn't show:
   - Check: `milestoneStreakCount` value in console
   - Look for: Which guard failed? (date check, count check, etc.)

### Common Issues:

**Issue:** "Waiting forever, app hangs"
- **Cause:** Persistence operation never called `endPersistenceOperation()`
- **Fix:** Check for exceptions in `setHabitProgress()`

**Issue:** "Still seeing newStreak: 0"
- **Cause:** SwiftData fetch still returning stale data
- **Fix:** Check `includePendingChanges = true` in fetch descriptor

**Issue:** "Milestone shows but streak still 0 in UI"
- **Cause:** Different issue - UI not updating from notification
- **Fix:** Check `currentStreak` @Published property updates
