# Guest Migration Test Guide

**Purpose**: Verify that the guest data migration fix (Issue #24, #25) works correctly and prevents data loss.

**Date**: October 30, 2025  
**Fixes Applied**:
- ✅ FIX #24: `HabitRepository.swift` line 956 - Show migration UI instead of auto-hiding
- ✅ FIX #25: `HabittoApp.swift` line 232 - Removed force-hide of migration UI
- ✅ Removed `clearStaleGuestData()` call that was deleting guest data

---

## **Quick Summary**

**What was broken:**
- Guest users who signed in had their data **automatically deleted** without warning
- Migration UI was never shown (forcibly hidden in 2 places)
- Users lost all their habit data when creating an account

**What's fixed:**
- Migration UI now appears when guest users sign in
- Guest data is **preserved** and never auto-deleted
- Users can choose: "Keep My Data" or "Start Fresh"
- Safety backups are created before migration

---

## **Test Scenarios**

### **Scenario 1: Guest User Signs In (Has Data) ✅**

**Objective**: Verify migration UI appears and data can be migrated.

**Steps**:
1. Launch app as guest (no sign-in)
2. Create 3-5 test habits with different data:
   - At least 1 habit with completion history (mark as completed for a few days)
   - At least 1 habit with a streak
   - At least 1 habit with reminders set
3. **Important**: Note down the habit names and completion dates
4. Tap "Profile" → "Sign In"
5. Sign in with Google/Apple/Email

**Expected Results**:
- ✅ Migration UI appears with title "Welcome to Your Account!"
- ✅ Shows habit count (should match what you created)
- ✅ Shows two buttons: "Keep My Data" and "Start Fresh"
- ✅ Warning banner appears about single-device limitation

**Test Case 1A: Choose "Keep My Data"**
1. Tap "Keep My Data"
2. Confirm the multi-device warning
3. Wait for migration to complete

**Expected Results**:
- ✅ Progress bar appears showing migration status
- ✅ All habits appear in the main habit list
- ✅ Completion history is preserved (check dates)
- ✅ Streaks are intact
- ✅ Reminders are preserved
- ✅ No data loss!

**Test Case 1B: Choose "Start Fresh"**
1. Tap "Start Fresh"
2. Confirm the action

**Expected Results**:
- ✅ Guest data is cleared
- ✅ User starts with empty habit list
- ✅ No migration occurs

---

### **Scenario 2: Guest User Signs In (No Data) ✅**

**Objective**: Verify no migration UI appears when there's no guest data.

**Steps**:
1. Launch app as guest (no sign-in)
2. **Do NOT create any habits** - leave it empty
3. Tap "Profile" → "Sign In"
4. Sign in with account

**Expected Results**:
- ✅ No migration UI appears
- ✅ User goes directly to main app
- ✅ Empty habit list

---

### **Scenario 3: User Already Migrated (Second Sign-In) ✅**

**Objective**: Verify migration doesn't trigger twice.

**Steps**:
1. Complete Scenario 1 (migrate guest data)
2. Sign out
3. Sign back in with the same account

**Expected Results**:
- ✅ No migration UI appears
- ✅ User's habits are loaded from cloud/SwiftData
- ✅ Data is preserved from previous session

---

### **Scenario 4: Migration Error Handling ⚠️**

**Objective**: Verify data is safe if migration fails.

**Steps**:
1. Create guest habits (2-3 habits)
2. Sign in
3. **Simulate network failure**: Turn on Airplane Mode before tapping "Keep My Data"
4. Tap "Keep My Data"

**Expected Results**:
- ✅ Migration fails gracefully
- ✅ Error alert appears with error message
- ✅ Pre-migration backup is created (check logs)
- ✅ Guest data is NOT deleted
- ✅ User can retry migration later

**Verification**:
- Check console logs for: "Pre-migration safety backup created at..."
- Guest data should still be in UserDefaults after failure

---

### **Scenario 5: Multi-Device Warning (Edge Case) ⚠️**

**Objective**: Verify warning about single-device limitation.

**Steps**:
1. Create habits on Device A as guest
2. Create **different** habits on Device B as guest (same app, different device)
3. Sign in with **the same account** on Device A first
4. Choose "Keep My Data" on Device A
5. Then sign in with the same account on Device B

**Expected Results**:
- ✅ Device A: Migrates Device A's guest habits
- ✅ Device B: Shows migration UI for Device B's guest habits
- ⚠️ **Only one device's data can be migrated** (expected limitation)
- ✅ Warning banner correctly explains this

**Note**: This is a known limitation - guest data is local-only and can't be merged.

---

## **How to Create Test Data**

### **Quick Test Habits Setup**

```
Habit 1: "Morning Run"
- Frequency: Daily
- Icon: 🏃
- Color: Blue
- Completion: Mark completed for today, yesterday, and 3 days ago

Habit 2: "Read 30min"
- Frequency: Daily
- Icon: 📚
- Color: Green
- Reminder: 8:00 PM
- Completion: Mark completed for today and yesterday

Habit 3: "Meditate"
- Frequency: 3x per week (Mon, Wed, Fri)
- Icon: 🧘
- Color: Purple
- Completion: Leave incomplete (test incomplete habits migrate too)

Habit 4: "Drink Water"
- Frequency: Daily
- Icon: 💧
- Color: Cyan
- Completion: Mark completed for last 7 days (test streak preservation)
```

---

## **Console Log Monitoring**

Watch for these key log messages during testing:

### **When Migration UI Should Appear**:
```
🔄 HabitRepository: User authenticated: <email>, checking for guest data migration...
🔄 HabitRepository: Guest data detected - showing migration UI...
✅ Guest data found, user can choose to migrate or start fresh
```

### **During Migration**:
```
🔄 GuestDataMigration: Migrating X guest habits to user <uid>
✅ GuestDataMigration: Pre-migration safety backup created at <path>
✅ GuestDataMigration: Successfully migrated guest data for user <uid>
```

### **If Migration Fails**:
```
❌ GuestDataMigration: Migration failed, but your data is safe!
   Pre-migration backup available at: <path>
   You can restore from this backup if needed
```

### **What You Should NEVER See**:
```
❌ clearStaleGuestData()  // This should NEVER appear - it deletes data!
```

---

## **Manual Verification Checklist**

After each test scenario, verify:

- [ ] All habits are present (count matches)
- [ ] Habit names are correct
- [ ] Icons and colors are preserved
- [ ] Completion history matches (check specific dates)
- [ ] Streaks are accurate
- [ ] Reminders are still scheduled
- [ ] XP points are correct (if applicable)
- [ ] No duplicate habits appear
- [ ] No console errors appear

---

## **Testing Tools**

### **Check UserDefaults for Guest Data**

Run this in Xcode console while debugging:

```swift
// Check if guest habits exist
po UserDefaults.standard.data(forKey: "guest_user_habits")

// Check migration status for current user
po UserDefaults.standard.bool(forKey: "guest_data_migrated_<USER_UID>")
```

### **Reset Test State (Between Tests)**

To reset and test again:

1. **Option A: Delete app and reinstall**
   - Fully deletes all local data
   - Clean slate for testing

2. **Option B: Clear UserDefaults (for guest data only)**
   ```swift
   // Run in Xcode console
   UserDefaults.standard.removeObject(forKey: "guest_user_habits")
   UserDefaults.standard.removeObject(forKey: "guest_data_migrated_<USER_UID>")
   ```

3. **Option C: Sign out and delete SwiftData container**
   - Sign out from the app
   - Delete app
   - Reinstall

---

## **Success Criteria**

✅ **All tests pass if**:
1. Migration UI appears when guest has data
2. User can choose "Keep My Data" or "Start Fresh"
3. All habits, completions, and streaks are preserved after migration
4. No data loss occurs
5. Migration can be retried if it fails
6. Safety backups are created before migration
7. No duplicate data appears
8. Multi-device warning is shown and accurate

❌ **Test FAILS if**:
1. Guest data is deleted automatically
2. Migration UI never appears
3. Data is lost after migration
4. Habits or completions are missing
5. Migration can't be retried after failure
6. Console shows "clearStaleGuestData()" being called

---

## **Known Limitations**

1. **Guest data is device-local only**: Each device's guest data must be migrated separately
2. **Can't merge multi-device guest data**: Only one device's guest data can be migrated per account
3. **Requires network for cloud sync**: Offline migration stores locally but won't sync until online

---

## **Reporting Issues**

If any test fails, please report:
1. Which test scenario failed
2. Expected vs actual behavior
3. Console logs (especially lines starting with 🔄, ✅, or ❌)
4. Screenshots of the migration UI (if visible)
5. Device details (iOS version, device model)

---

## **Next Steps After Testing**

Once all scenarios pass:
1. ✅ Mark guest migration fix as complete
2. ✅ Move to Phase 1, Step 3: Integration Tests
3. ✅ Update documentation with migration flow
4. Consider adding automated UI tests for regression testing

