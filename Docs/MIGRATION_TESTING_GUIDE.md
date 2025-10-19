# 🧪 Migration Testing Guide

Complete guide for testing the migration system using the debug UI.

---

## 📱 Accessing the Migration Debug View

### Navigation Path:
```
App Launch
  → More Tab (bottom navigation)
  → Account
  → Developer Tools Section (DEBUG builds only)
  → Migration Debug
```

### Screenshot Reference:
```
┌─────────────────────────────────┐
│         More Tab                │
│  ┌───────────────────────────┐  │
│  │  [Profile Avatar]         │  │
│  │  User Name                │  │
│  │  XP: 1000 | Level 5       │  │
│  └───────────────────────────┘  │
│                                 │
│  Personal Information    >      │
│                                 │
│  ──────────────────────────     │
│  🐛 Developer Tools             │
│  ──────────────────────────     │
│  🐜 Debug User Statistics  >    │
│  🔄 Migration Debug        >    │ ← Click Here
│  ──────────────────────────     │
└─────────────────────────────────┘
```

---

## 🎯 Step-by-Step Testing

### Test 1: Quick Automated Test (Recommended First)

**Goal:** Verify migration system works end-to-end

**Steps:**
1. Open Migration Debug view
2. Tap **"Run Full Test"** (under Automated Testing section)
3. Wait for completion (~30 seconds)
4. Check Output Log for results

**Expected Output:**
```
═══════════════════════════════════════════════════════════
🧪 MIGRATION FULL TEST
═══════════════════════════════════════════════════════════

[14:23:45] 🔧 Setting up SwiftData container...
[14:23:45] ✅ SwiftData container ready
[14:23:45] 🧪 Generating sample test data...
[14:23:46] ✅ Generated 10 test habits
  - Morning Run (Formation)
    Goal: 5 times
    Schedule: Everyday
    Progress records: 7
  - Reduce Coffee (Breaking)
    Goal: 3 cups
    Schedule: Everyday
    Progress records: 7
  ...

[14:23:46] 📊 Old Data Status:
  - Habits: 10
  - Progress records: 150
  - XP: 3250

───────────────────────────────────────────────────────────
STEP 1: DRY RUN
───────────────────────────────────────────────────────────

[14:23:46] 🧪 Running migration DRY RUN...
[14:23:46] ⏳ Starting migration (10/100)
[14:23:46] ⏳ Validating old data (10/100)
[14:23:46] ✅ Found 10 old habits to migrate
[14:23:47] ⏳ Migrating habits (20/100)
[14:23:47] ✅ Migrated: Morning Run (7 progress records)
...
[14:23:48] ✅ Dry run PASSED

───────────────────────────────────────────────────────────
STEP 2: ACTUAL MIGRATION
───────────────────────────────────────────────────────────

[14:23:48] 💾 Running ACTUAL migration...
[14:23:49] ✅ Migration SUCCESSFUL

───────────────────────────────────────────────────────────
STEP 3: VALIDATION
───────────────────────────────────────────────────────────

[14:23:49] 🔍 Validating migrated data...
[14:23:49] ✅ Validation PASSED

═══════════════════════════════════════════════════════════
🎉 FULL TEST COMPLETE
═══════════════════════════════════════════════════════════

[14:23:49] ✅ ALL TESTS PASSED

Migration Summary:
  - Habits migrated: 10
  - Progress records: 150
  - XP migrated: 3250
  - Duration: 2.34s

[14:23:49] 🗑️ Cleaning up...
[14:23:50] ✅ Cleanup complete
```

**Success Criteria:**
- ✅ Status shows "✅ Success"
- ✅ All habits migrated (10)
- ✅ All progress records migrated (150)
- ✅ XP matches (3250)
- ✅ Validation PASSED

---

### Test 2: Manual Step-by-Step Test

**Goal:** Test each migration step individually

#### Step 2.1: Generate Test Data

1. Tap **"Generate Sample Data"**
2. Check that "Old Habits" shows: **10**
3. Check that "Old Progress" shows: **~150**
4. Check that "Old XP" shows: **3250**

#### Step 2.2: Run Dry Run

1. Tap **"Run Dry Run"**
2. Watch progress bar (should complete in ~3 seconds)
3. Check Migration Summary section:
   - Status: **✅ Success**
   - Mode: **🧪 Dry Run**
   - Habits: **10**
   - Progress: **150**

#### Step 2.3: Validate (Optional)

1. Tap **"Validate Data"**
2. Check Validation section:
   - Status: **✅ PASSED**

#### Step 2.4: Run Actual Migration

1. Tap **"Run Actual Migration"**
2. Watch progress bar
3. Check Migration Summary:
   - Status: **✅ Success**
   - Mode: **💾 Live**
   - Habits: **10**
   - Progress: **150**
   - XP: **3250**
   - Level: **3**

#### Step 2.5: Validate Again

1. Tap **"Validate Data"**
2. Check Validation section:
   - Status: **✅ PASSED**
   - No errors listed

#### Step 2.6: Cleanup

1. Tap **"Clear Sample Data"** (under Test Data section)
2. Tap **"Rollback Migration"** (under Migration section)
3. Verify data cleared

---

### Test 3: Testing with Your Real Data

⚠️ **WARNING:** Only do this if you understand the risks!

**Prerequisites:**
- Backup your current data first
- Test on a non-production device
- Be ready to rollback if needed

**Steps:**

1. **Backup Your Data**
   - Go to: More → Data & Privacy → Backup
   - Export your data to a safe location

2. **Run Dry Run (Safe)**
   - Open Migration Debug
   - Don't generate test data
   - Tap **"Run Dry Run"**
   - This reads your real habits but doesn't save anything
   - Check the summary and validation

3. **Verify Results**
   - Check "Old Habits" count matches your actual habit count
   - Check "Old Progress" count looks reasonable
   - Check "Old XP" matches your current XP
   - Review schedule parsing (all schedules should be recognized)

4. **If Dry Run Passes:**
   - Consider running actual migration
   - But keep backup handy!

5. **If Any Issues:**
   - Don't run actual migration
   - Note the errors in Output Log
   - Report issues for fixing
   - Your data is still safe (dry run doesn't modify anything)

---

## 📊 Understanding the Migration Summary

### Key Metrics

| Metric | Meaning | Expected Value |
|--------|---------|----------------|
| **Status** | Success or failure | ✅ Success |
| **Mode** | Dry run or live | 🧪 Dry Run or 💾 Live |
| **Habits** | Number of habits migrated | = Old habits count |
| **Progress** | Number of progress records | = Old progress count |
| **XP** | Total XP migrated | = Old XP |
| **Level** | Calculated level | = Old level |
| **Current Streak** | Days of current streak | ≥ 0 |
| **Longest Streak** | Max consecutive days | ≥ Current streak |
| **Duration** | Time taken | < 5 seconds |

### Schedule Parsing

Shows how each schedule string was interpreted:

```
Schedule Parsing:
  • Daily: 7 habits             ← "Everyday" schedules
  • 3 days a week: 1 habits     ← "3 days a week"
  • 5 days a month: 1 habits    ← "5 days a month"
  • Every 3 days: 1 habits      ← "Every 3 days"
  • Specific weekdays (3 days): 1 habits  ← "Mon, Wed, Fri"
```

**What to Check:**
- ✅ All schedule types recognized
- ❌ "Failed to parse" means unrecognized format

---

## ✅ Validation Checks Explained

### Data Count Validation

```
Old habits: 10
New habits: 10 ✅     ← Should match
Old progress: 150
New progress: 150 ✅  ← Should match
Old XP: 3250
New XP: 3250 ✅       ← Should match
```

### Streak Validation

```
Current: 0 days
Longest: 0 days
Total complete: 50 days
Valid: ✅            ← Current ≤ Longest ≤ Total
```

### Integrity Checks

- ✅ **Habit count** - All habits migrated
- ✅ **Progress count** - All completion records migrated
- ✅ **XP total** - XP preserved
- ✅ **Current ≤ Longest streak** - Streak logic valid
- ✅ **Longest ≤ Total days** - Streak logic valid
- ✅ **No orphaned records** - All progress has parent habit
- ✅ **Valid dates** - No impossible dates
- ✅ **Valid schedules** - All schedules parsed

---

## 🚨 Common Issues & Solutions

### Issue 1: "Could not parse goal"

**Log Shows:**
```
⚠️ Could not parse goal: 'invalid format' - defaulting to (1, 'time')
```

**Cause:** Goal string format not recognized

**Solution:**
- Check what the actual goal string is
- If it's a common format, we'll add support
- Migration will still work (defaults to 1 time)

---

### Issue 2: "Habit count mismatch"

**Validation Shows:**
```
❌ Habit count mismatch: old=10, new=8
```

**Cause:** Some habits failed to migrate

**Solution:**
- Check Output Log for specific errors
- Look for parsing warnings
- Report the issue with log details

---

### Issue 3: "Progress count mismatch"

**Validation Shows:**
```
❌ Progress count mismatch: old=150, new=148
```

**Cause:** Some progress records had invalid dates

**Solution:**
- Check Output Log for "Invalid date string" warnings
- Non-critical: Most data still migrated
- Report if many records failed

---

### Issue 4: "Orphaned progress records"

**Validation Shows:**
```
❌ 5 orphaned progress records (no parent habit)
```

**Cause:** Progress records created but relationship not set

**Solution:**
- This is a critical error
- Rollback migration
- Report the issue immediately

---

### Issue 5: Dry Run Passes, Actual Migration Fails

**Scenario:**
- Dry run: ✅ Success
- Actual migration: ❌ Failed

**Cause:** Database write error

**Solution:**
- Check error message in Output Log
- Rollback is automatic
- Try again
- If persists, report issue

---

## 🧹 Cleanup After Testing

### Always Cleanup Test Data

After running tests with sample data:

1. **Clear Sample Data**
   - Tap "Clear Sample Data"
   - Removes old test habits from UserDefaults

2. **Rollback Migration**
   - Tap "Rollback Migration"
   - Removes new test data from SwiftData

3. **Verify Cleanup**
   - "Old Habits" should show: **0**
   - "Old Progress" should show: **0**
   - "Old XP" should show: **0**

---

## 📝 Reporting Issues

If you encounter any issues, provide:

1. **Full Output Log**
   - Copy from Output Log section
   - Include everything from start to error

2. **Migration Summary**
   - Screenshot or copy text
   - Include all metrics

3. **Validation Results**
   - What checks failed
   - Error messages

4. **Environment**
   - iOS version
   - Device model
   - App version

5. **Data Details**
   - How many habits you have
   - Any unusual schedule strings
   - Any unusual goal formats

---

## ✨ Success Checklist

Before proceeding to Phase 2B (Service Layer):

- [ ] Full automated test passes
- [ ] Manual step-by-step test passes
- [ ] All validation checks pass
- [ ] Schedule parsing recognizes all formats
- [ ] Goal parsing works for all units
- [ ] Streak calculation is reasonable
- [ ] XP totals match
- [ ] No orphaned records
- [ ] Cleanup works correctly

**Once all checks pass:** Ready for Phase 2B! ✅

---

## 🎯 Next Steps

After successful testing:

1. ✅ Verify all tests pass
2. ⏭️ Proceed to **Phase 2B: Service Layer**
   - Build ProgressService
   - Build StreakService
   - Build XPService
3. ⏭️ Then: UI Integration
4. ⏭️ Finally: Production rollout

---

**Last Updated:** Phase 2A Complete  
**Status:** Ready for Testing

