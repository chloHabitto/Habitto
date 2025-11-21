# Console Log Verification Guide

## 🔍 What Logs to Look For

### Priority 2: XP Integrity Check

**Search for these exact strings in your console:**

```
🔍 XP Integrity Check: Starting automatic integrity check on app launch...
🔍 XP Integrity Check: Current XP state - Total: X, Level: Y
✅ XP Integrity Check: Integrity verified - no repair needed
   Total XP: X, Level: Y
✅ XP Integrity Check: Completed
```

**OR if repair was needed:**
```
🔍 XP Integrity Check: Starting automatic integrity check on app launch...
🔍 XP Integrity Check: Current XP state - Total: X, Level: Y
✅ XP Integrity Check: Integrity repaired successfully
   Before: Total XP = X, Level = Y
   After:  Total XP = Z, Level = W
   Delta:  Z-X XP
✅ XP Integrity Check: Completed
```

**OR if there was an error:**
```
❌ XP Integrity Check: Failed to perform integrity check: {error}
```

---

### Priority 3: CompletionRecord Reconciliation

**Search for these exact strings in your console:**

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

**OR if repair was needed:**
```
🔧 CompletionRecord Reconciliation: Starting automatic reconciliation on app launch...
🔧 DailyAwardService: Starting CompletionRecord reconciliation...
🔧 DailyAwardService: Found X CompletionRecords to reconcile
🔧 DailyAwardService: Mismatch detected for habitId=abc12345..., dateKey=2025-01-15
   CompletionRecord.progress: 3
   Calculated from ProgressEvents: 5
   Delta: 2
✅ DailyAwardService: Updated CompletionRecord - progress: 5, isCompleted: true
✅ DailyAwardService: Saved X CompletionRecord updates
✅ CompletionRecord Reconciliation: Fixed X mismatches
✅ CompletionRecord Reconciliation: Completed
```

**OR if there was an error:**
```
❌ CompletionRecord Reconciliation: Failed to reconcile: {error}
```

---

## ⚠️ Important: OSLog Visibility

**The logs use `Logger` (OSLog), which may not appear in Xcode console by default!**

### How to See OSLog Messages in Xcode:

1. **Method 1: Use Console.app (macOS)**
   - Open Console.app (Applications > Utilities > Console)
   - Select your device/simulator from sidebar
   - Filter by: `subsystem:com.habitto.app`
   - You should see all logs with categories:
     - `XPIntegrityCheck`
     - `CompletionRecordReconciliation`
     - `DailyAwardService`

2. **Method 2: Enable OSLog in Xcode Console**
   - In Xcode, go to: **Product** → **Scheme** → **Edit Scheme**
   - Select **Run** → **Arguments**
   - Add Environment Variable:
     - Name: `OS_ACTIVITY_MODE`
     - Value: `disable`
   - This will show OSLog messages in Xcode console

3. **Method 3: Check Console.app on Device**
   - Connect device to Mac
   - Open Console.app
   - Select device from sidebar
   - Filter by your app name or subsystem

---

## 🔍 Quick Verification Steps

### Step 1: Check if Functions Are Being Called

**Look for these in your console (even if full logs don't appear):**

1. **App Launch Sequence:**
   ```
   🚀 AppDelegate: didFinishLaunchingWithOptions called
   ```

2. **Data Loading:**
   ```
   Loading habits from storage
   ```

3. **After ~500ms delay, you should see:**
   - Either the integrity check logs
   - OR nothing (which means logs might be hidden)

### Step 2: Test Manual Repair Button

1. **Go to:** More Tab → Data Management → **Repair Data**
2. **Tap the button**
3. **What should happen:**
   - Alert appears immediately: "Repairing data... Please wait."
   - After 2-5 seconds, alert updates with results
   - Console should show logs (even if launch logs don't appear)

### Step 3: Add Debug Print Statements (Temporary)

If you're not seeing logs, we can add `print()` statements temporarily to verify the code is running:

```swift
// In performXPIntegrityCheck():
print("🔍 DEBUG: XP Integrity Check STARTING")
logger.info("🔍 XP Integrity Check: Starting automatic integrity check...")
```

This will help us verify the code path is being executed.

---

## 🐛 Troubleshooting: If Logs Don't Appear

### Possible Issues:

1. **OSLog Not Visible in Xcode Console**
   - **Solution:** Use Console.app or enable OS_ACTIVITY_MODE (see above)
   - **Verify:** Check if other OSLog messages appear (they might be filtered)

2. **Code Not Being Called**
   - **Check:** Is `habitRepository.loadHabits()` completing?
   - **Check:** Is the Task.detached block executing?
   - **Verify:** Add a `print()` statement at the start of each function

3. **Timing Issue**
   - **Check:** Are you waiting long enough? (checks run 500ms after data loads)
   - **Check:** Is the app actually launching fresh, or resuming from background?

4. **Error Preventing Execution**
   - **Check:** Look for any error messages in console
   - **Check:** Verify the app builds without warnings

---

## 📋 What to Share

When you share your console logs, please include:

1. **Full console output** from app launch (first 30 seconds)
2. **Search results** for:
   - "XP Integrity Check"
   - "CompletionRecord Reconciliation"
   - "DailyAwardService"
3. **Any error messages** (lines starting with `❌`)
4. **Result of manual repair** (what alert shows)

---

## ✅ Expected Behavior

### On App Launch:
- **Timing:** Checks run ~500ms after `loadHabits()` completes
- **Frequency:** Every app launch (not just first launch)
- **Visibility:** Logs appear in Console.app or with OS_ACTIVITY_MODE enabled

### On Manual Repair:
- **Immediate:** Alert appears instantly
- **Duration:** 2-5 seconds for completion
- **Result:** Alert updates with repair results
- **Logs:** Should appear in Xcode console (even if launch logs don't)

---

## 🔧 Quick Test: Add Print Statements

If logs aren't appearing, let's add temporary `print()` statements to verify execution:

**Would you like me to:**
1. Add `print()` statements to verify the code is running?
2. Check if there's a timing issue?
3. Verify the Task.detached blocks are executing?

Let me know what you see in your console logs and I'll help troubleshoot!

