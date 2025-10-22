# Tests You Can Complete TODAY (No Date Changes Required)

## Current Status
✅ **Test 1 - Day 1**: PASSED
- Firestore sync-down working
- Habits loaded correctly
- Completion flow works

---

## Test 2: Partial Progress Persistence (CRITICAL - 15 min)

### Why This Matters
This verifies the main bug fix: `CompletionRecord.progress` field stores actual counts (not just 1/0).

### Setup
- Current state: All 5 habits completed (from Test 1)
- Streak: 1 day, XP: 50

### Step 1: Uncomplete All Habits
1. **Action**: Tap checkbox on each habit to uncomplete them
2. **Expected**:
   - All habits show 0/10, 0/10, 0/1, 0/1, 0/5
   - Streak: 0
   - XP: 0

---

### Scenario 2A: Test 5/10 Progress

1. **Action**: For **Habit1** (goal: 10 times):
   - **Swipe RIGHT 5 times** (don't tap checkbox)
   - Watch the progress bar fill
   
2. **Expected Visual**:
   ```
   Habit1  ●●●●●○○○○○  5/10 times
           [████████░░░░░░░░░░] 50%
   ```
   - Circle is **NOT filled** (not complete yet)
   - Progress bar at 50%
   - Counter shows 5/10

3. **Action**: Force close the app
   - Swipe up from home screen
   - Completely kill the app

4. **Action**: Reopen the app

5. **CRITICAL CHECK**: Does Habit1 show?
   - ✅ **PASS**: Shows 5/10 (progress persisted!)
   - ❌ **FAIL**: Shows 1/10 or 0/10 (progress lost - bug still exists)

**Console Log to Verify:**
```
🔍 toHabit(): Using CompletionRecords from relationship for habit 'Habit1'
📊 CompletionRecord for Habit1: progress=5
✅ Habit1: Loaded with completionHistory[2025-10-22] = 5
```

**Screenshot This**: Take a photo showing 5/10 after reopen for documentation

**Pass Criteria:**
- [ ] Before close: Shows 5/10
- [ ] After reopen: Shows 5/10 (NOT 1/10 or 0/10)
- [ ] Progress bar at 50%
- [ ] Circle NOT filled

---

### Scenario 2B: Test 7/10 Progress

1. **Action**: For **Habit2** (goal: 10 times):
   - **Swipe RIGHT 7 times**

2. **Expected Visual**:
   ```
   Habit2  ●●●●●●●○○○  7/10 times
           [██████████████░░░░░░] 70%
   ```

3. **Action**: Force close app

4. **Action**: Reopen app

5. **CRITICAL CHECK**: Does Habit2 show?
   - ✅ **PASS**: Shows 7/10
   - ❌ **FAIL**: Shows 1/10 or 0/10

**Pass Criteria:**
- [ ] Before close: Shows 7/10
- [ ] After reopen: Shows 7/10 (NOT 1/10)
- [ ] Progress bar at 70%

---

### Scenario 2C: Test Complete Then Partial (10→5)

1. **Action**: For **Habit1** (currently 5/10):
   - **Swipe RIGHT 5 more times** to reach 10/10
   - This will mark it complete

2. **Expected**:
   - ✅ Circle fills (checkmark appears)
   - ✅ Difficulty sheet appears
   - ✅ Progress shows 10/10

3. **Action**: Dismiss difficulty sheet

4. **Action**: **Swipe LEFT 5 times** on Habit1
   - This reduces from 10/10 → 5/10

5. **Expected**:
   - ✅ Circle empties (checkmark disappears)
   - ✅ Shows 5/10
   - ⚠️ XP may decrease (recalculated)

6. **Action**: Force close app

7. **Action**: Reopen app

8. **CRITICAL CHECK**: Does Habit1 show?
   - ✅ **PASS**: Shows 5/10 (reduction persisted!)
   - ❌ **FAIL**: Shows 10/10 or 1/10

**Pass Criteria:**
- [ ] Can increase from 5/10 to 10/10
- [ ] Can decrease from 10/10 to 5/10
- [ ] Reduced progress persists (5/10 after reopen)

---

### Scenario 2D: Test Over-Completion (15/10)

1. **Action**: For **Habit1** (currently at some value):
   - **Swipe RIGHT** until it shows **15/10**
   - The app allows over-completion

2. **Expected Visual**:
   ```
   Habit1  ●●●●●●●●●●  15/10 times
           [████████████████████████] 150%
   ```
   - Progress bar may overflow or show 100%+
   - Circle is filled (complete)

3. **Action**: Force close app

4. **Action**: Reopen app

5. **CRITICAL CHECK**: Does Habit1 show?
   - ✅ **PASS**: Shows 15/10 (over-completion persisted!)
   - ❌ **FAIL**: Shows 1/10 or 10/10

**Console Log to Verify:**
```
📊 CompletionRecord for Habit1: progress=15, isCompleted=true
```

**Pass Criteria:**
- [ ] Before close: Shows 15/10
- [ ] After reopen: Shows 15/10 (NOT capped at 10/10)
- [ ] CompletionRecord.progress = 15

---

## Test 3: Undo/Reversal Logic (IMPORTANT - 10 min)

### Setup
- Complete all 5 habits (if not already done)
- Verify: Streak = 1, XP = 50

---

### Scenario 3A: Uncomplete Last Habit

**Initial State Check:**
```
✅ All 5 habits complete
✅ Streak: 1 day
✅ XP: 50
✅ Celebration was shown
```

1. **Action**: Tap checkbox on **Habit5** to uncomplete it

2. **Expected Changes** (should happen immediately):
   - ✅ Habit5 becomes 0/5 (incomplete)
   - ✅ XP changes to: **0** (not 50!)
   - ✅ Streak changes to: **0** (not 1!)
   - ⚠️ Celebration status cleared (no confetti)

**Console Logs to Watch:**
```
🎯 UNCOMPLETE_FLOW: Habit 'Habit5' uncompleted for 2025-10-22
✅ DERIVED_XP: Recalculating XP after uncomplete
✅ DERIVED_XP: XP recalculated to 0 (completedDays: 0)
✅ UNCOMPLETE_FLOW: DailyAward removed for 2025-10-22
```

**Why This Happens:**
- The app deletes the `DailyAward` record for today
- XP is recalculated from remaining `DailyAward` count
- Since no complete days remain, XP = 0

**Pass Criteria:**
- [ ] XP reverts: 50 → 0
- [ ] Streak reverts: 1 → 0
- [ ] Console shows "DailyAward removed"
- [ ] Changes happen instantly (no delay)

---

### Scenario 3B: Re-Complete After Undo

**Current State:**
```
✅ Habits 1-4: Complete
❌ Habit5: Incomplete (0/5)
📊 Streak: 0, XP: 0
```

1. **Action**: Complete **Habit5** again
   - Swipe right 5 times to reach 5/5

2. **Expected** (when reaching 5/5):
   - ✅ Difficulty sheet appears
   - ✅ **Celebration triggers again!** (all habits complete)
   - ✅ XP increases to: 50
   - ✅ Streak increases to: 1

**Console Logs to Watch:**
```
🎯 COMPLETION_FLOW: Last habit completed - will trigger celebration
✅ COMPLETION_FLOW: DailyAward record created for history
✅ DERIVED_XP: XP set to 50 (completedDays: 1)
🎉 COMPLETION_FLOW: Celebration triggered!
```

3. **Action**: Force close app

4. **Action**: Reopen app

5. **Expected After Reopen**:
   - ✅ All habits still complete
   - ✅ XP: 50
   - ✅ Streak: 1

**Pass Criteria:**
- [ ] XP restored: 0 → 50
- [ ] Streak restored: 0 → 1
- [ ] Celebration shows again
- [ ] DailyAward recreated (check console)
- [ ] State persists after reopen

---

### Scenario 3C: Partial Undo (10→3 then reopen)

1. **Setup**: Complete **Habit1** fully (10/10)

2. **Action**: **Swipe LEFT** 7 times
   - Reduces from 10/10 → 3/10

3. **Expected**:
   - ✅ Shows 3/10
   - ✅ Circle empties (not complete)
   - ✅ XP decreases (day no longer complete)

4. **Action**: Force close app

5. **Action**: Reopen app

6. **CRITICAL CHECK**: Does Habit1 show?
   - ✅ **PASS**: Shows 3/10 (partial undo persisted!)
   - ❌ **FAIL**: Shows 10/10 or 1/10

**Pass Criteria:**
- [ ] Before close: Shows 3/10
- [ ] After reopen: Shows 3/10
- [ ] XP correctly recalculated
- [ ] CompletionRecord.progress = 3

---

## Quick Additional Tests (5 min each)

### Test: Swipe vs Tap Behavior

**Purpose**: Verify swipe increments by 1, tap completes fully

1. **Habit with goal 10**:
   - Tap checkbox → Should jump to 10/10 (complete)
   - Tap again → Should reset to 0/10 (toggle)

2. **Habit with goal 10**:
   - Swipe right → Increases by 1 each swipe
   - Swipe left → Decreases by 1 each swipe

**Pass Criteria:**
- [ ] Tap = toggle (0→full or full→0)
- [ ] Swipe = increment/decrement by 1

---

### Test: Difficulty Sheet Always Appears

**Purpose**: Verify Habit5 bug is fixed

1. **Action**: Complete habits in order: Habit1 → Habit2 → Habit3 → Habit4 → Habit5

2. **Expected**: Difficulty sheet appears for **ALL 5 habits**
   - Including Habit5 (this was the bug!)

**Pass Criteria:**
- [ ] Habit1: Difficulty sheet ✓
- [ ] Habit2: Difficulty sheet ✓
- [ ] Habit3: Difficulty sheet ✓
- [ ] Habit4: Difficulty sheet ✓
- [ ] Habit5: Difficulty sheet ✓ (was broken before!)
- [ ] Celebration after Habit5 ✓

---

## Summary Checklist for Today

### Test 2: Partial Progress ✓
- [ ] **2A**: 5/10 persists after reopen
- [ ] **2B**: 7/10 persists after reopen
- [ ] **2C**: 10→5 reduction persists
- [ ] **2D**: 15/10 over-completion persists

### Test 3: Undo/Reversal ✓
- [ ] **3A**: Uncomplete reverts XP and streak
- [ ] **3B**: Re-complete restores XP and streak
- [ ] **3C**: Partial undo (10→3) persists

### Bonus Tests ✓
- [ ] Swipe vs tap behavior correct
- [ ] Difficulty sheet appears for all habits (including Habit5)

---

## What This Proves

If all tests pass:
✅ `CompletionRecord.progress` field is working (storing 5, 7, 10, 15, etc.)
✅ Persistence bug is completely fixed
✅ Undo/reversal logic works correctly
✅ Firestore sync working
✅ Difficulty sheet bug fixed (Habit5)
✅ XP recalculation is idempotent

If any test fails:
❌ Document which scenario failed
❌ Copy console logs
❌ Take screenshots
❌ We'll debug together

---

## Time Estimate

- **Test 2**: 15 minutes (4 scenarios)
- **Test 3**: 10 minutes (3 scenarios)
- **Bonus**: 5 minutes (2 quick tests)

**Total**: ~30 minutes of focused testing

---

## Next Steps After Today's Tests

### If All Pass ✅
Tomorrow or when you can change dates:
- Complete **Test 1: Days 2-4** (multi-day streak)
- Verify streak breaking/continuing logic

Then:
- **Option B: Cleanup** (remove logs, polish code)
- Ship the fix!

### If Any Fail ❌
- Debug immediately
- Fix the issue
- Re-test

---

## Ready to Start?

**Suggested order:**
1. **Test 2A** (5/10) - Most critical
2. **Test 2B** (7/10) - Verification
3. **Test 3A** (Undo) - Important edge case
4. **Test 3B** (Re-complete) - Verify reversal works both ways
5. Rest of scenarios as time permits

**Start whenever you're ready!** 🚀

