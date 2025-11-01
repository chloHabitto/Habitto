# Event Sourcing Testing Guide

This guide will help you verify that the event sourcing system is working correctly.

## Prerequisites

- App is built and running
- You are signed in (authenticated user)
- You have at least one habit created

## Step 1: Run Automated Test Suite

### Option A: Using Debug Button (Recommended)

1. Open the app
2. Navigate to **More** tab
3. Scroll down to find **"Debug Tools"** section (only visible in DEBUG builds)
4. Tap **"Test Event Sourcing"** button
5. Check the console output for test results

### Option B: Using Console (Advanced)

If you have access to Xcode console, you can run:

```swift
Task {
    try? await MigrationTestHelper.shared.runAutomatedEventSourcingTest()
}
```

### Expected Output

You should see:
```
==========================================
🧪 AUTOMATED EVENT-SOURCING TEST
==========================================
📋 Test Setup:
  User ID: [your-user-id]
  Habits found: [number]

🧪 Test 1: Event Creation
  Updating progress for first habit...
  Current progress: [number]
  Setting progress to: [number]
  ✅ Event created successfully
     Event ID: [id]...
     Event Type: [type]
     Progress Delta: [delta]

🧪 Test 2: Event Replay
  Progress from events: [number]
  Legacy progress: [number]
  ✅ Event replay matches current progress

🧪 Test 3: XP Award System
  ✅ DailyAward exists for today
     XP Granted: 50
     All Habits Completed: true
  OR
  ℹ️ No DailyAward for today (habits may not all be complete)

==========================================
✅ Automated test complete
==========================================
```

## Step 2: Verify Migration Status

### Using Debug Button

1. In **More** tab → **Debug Tools** section
2. Tap **"Check Migration Status"** button
3. Review the console output

### Expected Output

You should see:
```
==========================================
📊 MIGRATION STATUS REPORT
==========================================
Current User ID: [your-user-id]

📋 SwiftData Analysis:
  Total Habits in SwiftData: [number]
  Total CompletionRecords: [number]

Migration State:
  Status: [status]
  Completed: ✅
  Records Migrated: [number]

Progress Events:
  Total Events: [number]
  Migration Events: [number]
  User-Generated Events: [number]

Events by Habit:
  [habit-id]: [count] events
```

## Step 3: Manual Testing Workflow

### Test Scenario: Complete/Uncomplete a Habit

1. **Open the app** (fresh state after rebuild)

2. **Complete a habit** by tapping the circle button

3. **Check console logs** for:
   - `📝 setProgress: habit='[name]', dateKey=[date]`
   - `📝 setProgress: Creating ProgressEvent (delta != 0)`
   - `✅ setProgress: Created ProgressEvent successfully`
   - `📝 setProgress: Calling checkDailyCompletionAndAwardXP`
   - `🎯 XP_CHECK: Checking daily completion for [date]`
   - `🎯 XP_CHECK: All completed: [true/false], Award exists: [true/false]`
   - Either `🎯 XP_CHECK: ✅ Creating DailyAward` or `🎯 XP_CHECK: ℹ️ No change needed`

4. **Uncomplete the same habit** by tapping again

5. **Check console logs** for:
   - `📝 setProgress: Creating ProgressEvent (delta != 0)` (with negative delta)
   - `✅ setProgress: Created ProgressEvent successfully`
   - `🎯 XP_CHECK: ❌ Removing DailyAward` (if award existed)

6. **Close and reopen the app**

7. **Verify** the habit shows correct completion status

### Expected Log Pattern

When completing a habit:
```
📝 setProgress: habit='[name]', dateKey=2025-11-01
   → oldProgress=0, newProgress=1, delta=1
   → goalAmount=1, eventType=manualSet
📝 setProgress: Creating ProgressEvent (delta != 0)
✅ setProgress: Created ProgressEvent successfully
   → Event ID: [id]...
   → Event Type: manualSet
   → Progress Delta: 1
   → Operation ID: [operation-id]...
📝 setProgress: Calling checkDailyCompletionAndAwardXP for dateKey=2025-11-01
🎯 XP_CHECK: Checking daily completion for 2025-11-01
🎯 XP_CHECK: Found [number] scheduled habits for 2025-11-01
🔍 calculateProgressFromEvents: habitId=[id]..., dateKey=2025-11-01
   → goalAmount=1, legacyProgress=1
🔍 calculateProgressFromEvents: Found [number] events
✅ calculateProgressFromEvents: Using event-sourced progress: 1 (from [number] events)
🎯 XP_CHECK: All completed: true, Award exists: false
🎯 XP_CHECK: ✅ Creating DailyAward for 2025-11-01
✅ setProgress: checkDailyCompletionAndAwardXP completed successfully
```

When uncompleting a habit:
```
📝 setProgress: habit='[name]', dateKey=2025-11-01
   → oldProgress=1, newProgress=0, delta=-1
📝 setProgress: Creating ProgressEvent (delta != 0)
✅ setProgress: Created ProgressEvent successfully
   → Progress Delta: -1
🎯 XP_CHECK: All completed: false, Award exists: true
🎯 XP_CHECK: ❌ Removing DailyAward for 2025-11-01 (habits uncompleted)
```

## Step 4: Verify Firestore Sync

### Check Firestore Console

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Navigate to **Firestore Database**
3. Go to: `/users/{yourUserId}/events/{currentYearMonth}/`
   - Example: `/users/mMl83AlWhhfT7NpyHCTY1SZuTq93/events/2025-11/`

### What to Look For

✅ **ProgressEvent documents exist**
- Each document should have:
  - `habitId`: UUID string
  - `dateKey`: "yyyy-MM-dd" format
  - `progressDelta`: integer (can be positive or negative)
  - `eventType`: string (e.g., "manualSet", "increment", "decrement")
  - `operationId`: unique string for idempotency
  - `synced`: boolean (should be `true` after sync)

✅ **No duplicate operationIds**
- Each `operationId` should be unique
- Check if any documents share the same `operationId`

✅ **DailyAward documents**
- Check: `/users/{yourUserId}/daily_awards/{dateKey}`
- Should exist for dates when all habits were completed
- Should have `xpGranted: 50` and `allHabitsCompleted: true`

### Check SyncEngine Logs

Search console for:
- `📤 SYNC_START: Background task running`
- `📤 SYNCING: '[habit-name]' to Firestore...`
- `✅ SYNC_COMPLETE: synced=[number], skipped=0, failed=0`

If sync isn't working, you'll see:
- `❌ SYNC_ERROR: [error message]`
- `⚠️ SyncEngine: [warning message]`

## Step 5: Verify Event Replay

### Test: Restart App and Verify Progress

1. Complete a habit (creates ProgressEvent)
2. Close the app completely
3. Reopen the app
4. Check if the habit still shows as completed

### Expected Behavior

- Habit should show correct completion status
- Progress should be calculated from ProgressEvents, not completionHistory
- Logs should show: `✅ calculateProgressFromEvents: Using event-sourced progress`

## Troubleshooting

### Issue: No events are being created

**Check:**
- `📝 setProgress: Skipping event creation (delta == 0, no change)` - This is normal if progress didn't change
- `❌ setProgress: Failed to create ProgressEvent` - Error occurred, check error message

**Solution:**
- Verify SwiftData is working correctly
- Check if `ProgressEventService` is initialized
- Look for database corruption errors

### Issue: Progress not calculated from events

**Check logs for:**
- `⚠️ calculateProgressFromEvents: No events found, falling back to legacy progress`
- This means no events exist for this habit+date combination

**Solution:**
- Run migration if habits have legacy completionHistory
- Verify events were created (check Step 1)

### Issue: XP awards not working

**Check logs for:**
- `🎯 XP_CHECK: Checking daily completion` - Should appear
- `🎯 XP_CHECK: All completed: [value]` - Should show correct value
- `🎯 XP_CHECK: ✅ Creating DailyAward` - Should appear when all complete

**Solution:**
- Verify all habits scheduled for the date are actually complete
- Check if `DailyAward` creation is failing (look for errors)

### Issue: Events not syncing to Firestore

**Check:**
- Network connectivity
- Firebase configuration
- SyncEngine logs for errors

**Solution:**
- Verify Firebase is configured correctly
- Check if user is authenticated
- Look for Firestore permission errors

## Success Criteria

✅ **All tests pass** if:
- Events are created when progress changes
- Progress is calculated from events (not completionHistory)
- XP awards are created/deleted correctly
- Events sync to Firestore (if enabled)
- Progress persists after app restart

## Next Steps

After verifying everything works:
1. ✅ Event sourcing is fully functional
2. ⏭️ Proceed to remove deprecated `completionHistory` direct updates
3. ⏭️ Test edge cases (multiple devices, offline sync, etc.)
4. ⏭️ Performance testing with large event counts


