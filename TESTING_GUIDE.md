# Testing Guide - Data Integrity Features

## Current App State: Guest-Only Mode

**Important:** Sign-in is currently **DISABLED** in the app. All users operate as guests with `userId = ""`.

---

## Priority Status

### ✅ Priority 1: ProgressEvent Migration (DORMANT - Ready for Future)
- **Status:** Code is complete and correct, but **NOT TESTABLE** in current guest-only mode
- **Why:** Migration only runs when a user signs in (userId changes from `""` to authenticated UID)
- **Verification:** 
  - Migration code is only called from commented-out code in `AppDelegate.swift` (lines 98-100)
  - Function requires `authUserId` parameter - won't run for guest users
  - Code correctly handles guest users but only executes when migrating TO authenticated user
- **When to Test:** When sign-in functionality is enabled in the future
- **Code Location:** `Core/Data/Migration/GuestToAuthMigration.swift`

### ✅ Priority 2: XP Integrity Check (ACTIVE - Testable Now)
- **Status:** Active and running on every app launch
- **Runs:** Automatically on app launch (background task)
- **Testable:** Yes - works for guest users

### ✅ Priority 3: CompletionRecord Reconciliation (ACTIVE - Testable Now)
- **Status:** Active and running on every app launch
- **Runs:** Automatically on app launch (background task)
- **Testable:** Yes - works for guest users

---

## Testing Instructions

### Test 1: XP Integrity Check (Priority 2)

#### Automatic Check on App Launch

1. **Launch the app**
   - Open the app (fresh launch or from background)
   - Wait 1-2 seconds for data to load

2. **Check Console Logs**
   - Look for these messages in Xcode console:
   ```
   🔍 XP Integrity Check: Starting automatic integrity check on app launch...
   🔍 XP Integrity Check: Current XP state - Total: X, Level: Y
   ✅ XP Integrity Check: Integrity verified - no repair needed
      Total XP: X, Level: Y
   ✅ XP Integrity Check: Completed
   ```

3. **Expected Behavior:**
   - Check runs automatically (no user action needed)
   - Runs in background (doesn't block app startup)
   - Logs appear within 1-2 seconds of app launch
   - If integrity is valid: "No repair needed" message
   - If mismatch found: "Integrity repaired successfully" with before/after values

#### Manual Repair Test

1. **Open More Tab**
   - Navigate to: **More Tab** (this is the settings view itself)

2. **Find Data Management Section**
   - Scroll down to find the **"Data Management"** section
   - You should see:
     - "Data & Privacy"
     - **"Repair Data"** ← This is the button
     - "Sync Status"

3. **Trigger Manual Repair**
   - Tap **"Repair Data"** button
   - Alert dialog will appear showing "Repairing data... Please wait."

4. **Check Results**
   - After a few seconds, alert will update with results:
   ```
   ✅ XP Integrity: No issues found
   
   ✅ Completion Records: All X records are consistent
   ```

5. **Verify Console Logs**
   - Check Xcode console for detailed logs:
   ```
   🔍 XP Integrity Check: Starting automatic integrity check...
   ✅ XP Integrity Check: Integrity verified - no repair needed
   ```

#### Creating a Test Mismatch (Advanced)

**Note:** This requires database access or code modification. For most users, just verify the check runs.

If you want to test repair functionality:
1. Manually modify `UserProgressData.totalXP` in database (if you have access)
2. Or wait for a natural mismatch to occur (rare)
3. Launch app and check logs for repair:
   ```
   ✅ XP Integrity Check: Integrity repaired successfully
      Before: Total XP = X, Level = Y
      After:  Total XP = Z, Level = W
      Delta:  Z-X XP
   ```

---

### Test 2: CompletionRecord Reconciliation (Priority 3)

#### Automatic Check on App Launch

1. **Launch the app**
   - Open the app (fresh launch or from background)
   - Wait 1-2 seconds for data to load

2. **Check Console Logs**
   - Look for these messages in Xcode console:
   ```
   🔧 CompletionRecord Reconciliation: Starting automatic reconciliation on app launch...
   🔧 DailyAwardService: Starting CompletionRecord reconciliation...
   🔧 DailyAwardService: Found X CompletionRecords to reconcile
   ✅ DailyAwardService: Reconciliation complete
      Total records checked: X
      Mismatches found: 0
      Mismatches fixed: 0
      Errors: 0
   ✅ CompletionRecord Reconciliation: All records are consistent (no repairs needed)
   ✅ CompletionRecord Reconciliation: Completed
   ```

3. **Expected Behavior:**
   - Check runs automatically (no user action needed)
   - Runs in background (doesn't block app startup)
   - Logs appear within 1-2 seconds of app launch
   - If all records are consistent: "No repairs needed" message
   - If mismatches found: "Fixed X mismatches" message

#### Manual Repair Test

1. **Open More Tab**
   - Navigate to: **More Tab** (this is the settings view itself)

2. **Find Data Management Section**
   - Scroll down to find the **"Data Management"** section
   - You should see:
     - "Data & Privacy"
     - **"Repair Data"** ← This is the button
     - "Sync Status"

3. **Trigger Manual Repair**
   - Tap **"Repair Data"** button
   - Alert dialog will appear showing "Repairing data... Please wait."

4. **Check Results**
   - After a few seconds, alert will update with results:
   ```
   ✅ XP Integrity: No issues found
   
   ✅ Completion Records: All X records are consistent
   ```

5. **Verify Console Logs**
   - Check Xcode console for detailed logs:
   ```
   🔧 DailyAwardService: Starting CompletionRecord reconciliation...
   🔧 DailyAwardService: Found X CompletionRecords to reconcile
   ✅ DailyAwardService: Reconciliation complete
      Total records checked: X
      Mismatches found: 0
      Mismatches fixed: 0
      Errors: 0
   ```

#### Creating a Test Mismatch (Advanced)

**Note:** This requires database access or code modification. For most users, just verify the check runs.

If you want to test repair functionality:
1. Manually modify a `CompletionRecord.progress` value in database (if you have access)
2. Run manual repair from Settings
3. Check logs for repair:
   ```
   🔧 DailyAwardService: Mismatch detected for habitId=abc12345..., dateKey=2025-01-15
      CompletionRecord.progress: 3
      Calculated from ProgressEvents: 5
      Delta: 2
   ✅ DailyAwardService: Updated CompletionRecord - progress: 5, isCompleted: true
   ✅ DailyAwardService: Saved 1 CompletionRecord updates
   ```

---

## Expected Console Logs (Full Sequence)

### On App Launch (Normal Operation)

```
🔍 XP Integrity Check: Starting automatic integrity check on app launch...
🔍 XP Integrity Check: Current XP state - Total: 150, Level: 2
✅ XP Integrity Check: Integrity verified - no repair needed
   Total XP: 150, Level: 2
✅ XP Integrity Check: Completed

🔧 CompletionRecord Reconciliation: Starting automatic reconciliation on app launch...
🔧 DailyAwardService: Starting CompletionRecord reconciliation...
🔧 DailyAwardService: Found 150 CompletionRecords to reconcile
✅ DailyAwardService: Reconciliation complete
   Total records checked: 150
   Mismatches found: 0
   Mismatches fixed: 0
   Errors: 0
✅ CompletionRecord Reconciliation: All records are consistent (no repairs needed)
✅ CompletionRecord Reconciliation: Completed
```

### On Manual Repair (More Tab > Data Management > Repair Data)

```
🔍 XP Integrity Check: Starting automatic integrity check...
🔍 XP Integrity Check: Current XP state - Total: 150, Level: 2
✅ XP Integrity Check: Integrity verified - no repair needed
   Total XP: 150, Level: 2
✅ XP Integrity Check: Completed

🔧 DailyAwardService: Starting CompletionRecord reconciliation...
🔧 DailyAwardService: Found 150 CompletionRecords to reconcile
✅ DailyAwardService: Reconciliation complete
   Total records checked: 150
   Mismatches found: 0
   Mismatches fixed: 0
   Errors: 0
✅ CompletionRecord Reconciliation: All records are consistent (no repairs needed)
✅ CompletionRecord Reconciliation: Completed
```

---

## Verification Checklist

### Priority 2: XP Integrity Check
- [ ] Check runs automatically on app launch
- [ ] Console logs appear within 1-2 seconds
- [ ] No errors in console
- [ ] Manual repair button works in Settings
- [ ] Alert shows results after manual repair

### Priority 3: CompletionRecord Reconciliation
- [ ] Check runs automatically on app launch
- [ ] Console logs appear within 1-2 seconds
- [ ] Shows number of records checked
- [ ] No errors in console
- [ ] Manual repair button works in Settings
- [ ] Alert shows results after manual repair

### Priority 1: ProgressEvent Migration
- [ ] Code is present in `GuestToAuthMigration.swift`
- [ ] Migration function exists: `migrateProgressEvents()`
- [ ] Code is called from migration flow (commented out in AppDelegate)
- [ ] **Note:** Cannot test until sign-in is enabled

---

## Troubleshooting

### No Logs Appearing
- **Check:** Make sure you're looking at the correct console (Xcode console, not device logs)
- **Check:** Wait 1-2 seconds after app launch (checks run in background)
- **Check:** Verify app is actually launching (not just resuming from background)

### Errors in Console
- **Check:** Look for error messages starting with `❌`
- **Check:** Verify SwiftData database is accessible
- **Check:** Check for any missing dependencies or imports

### Manual Repair Not Working
- **Check:** Make sure you're in the **More Tab** (not a separate Settings screen)
- **Check:** Scroll down to find the **"Data Management"** section
- **Check:** Look for **"Repair Data"** button (it's directly in the More tab, not in a submenu)
- **Check:** Wait for alert to update (repair takes a few seconds)
- **Check:** Check console logs for error messages

---

## Future Testing (When Sign-In is Enabled)

### Priority 1: ProgressEvent Migration Test Plan

1. **Create Guest Data**
   - Use app as guest (userId = "")
   - Create habits and mark completions
   - Verify ProgressEvents are created with userId = ""

2. **Sign In**
   - Enable sign-in functionality
   - Sign in with account
   - Migration should trigger automatically

3. **Verify Migration**
   - Check console logs for migration messages
   - Verify all ProgressEvents have userId = {authUserId}
   - Verify no events remain with userId = ""

4. **Expected Logs:**
   ```
   🔄 Starting guest to auth migration...
      From: guest (empty)
      To: {authUserId}
   📦 Migrating X ProgressEvents...
   ✅ Migrated X ProgressEvents
   ✅ VERIFIED: All ProgressEvents successfully migrated
   ```

---

## Summary

- **Priority 1:** Dormant but ready - will activate when sign-in is enabled
- **Priority 2:** Active and testable - runs on every app launch
- **Priority 3:** Active and testable - runs on every app launch
- **Manual Repair:** Available in More Tab > Data Management > "Repair Data"

All implementations are complete and ready for testing (where applicable).

