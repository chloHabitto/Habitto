# 📋 Console Log Capture Instructions

## Step-by-Step Guide

### 1. Build and Run the App

1. Open Xcode
2. Select your target device/simulator
3. Build and run the app (⌘R)

### 2. Capture Console Logs

Once the app launches:

1. **Open Xcode Console** (if not already visible):
   - View → Debug Area → Activate Console (⇧⌘C)
   - Or click the console button at the bottom of Xcode

2. **Clear the console** (optional but recommended):
   - Right-click in console → Clear Console
   - Or press ⌘K

3. **Watch for 30 seconds** after app launch

4. **Copy all console output**:
   - Select all text in console (⌘A)
   - Copy (⌘C)
   - Paste into a text file or share directly

### 3. What to Look For

#### ✅ Expected Success Patterns (in order):

1. **App Initialization**
   ```
   🚀 AppDelegate: INIT CALLED
   🚀 AppDelegate: didFinishLaunchingWithOptions called
   ```

2. **Firebase Configuration**
   ```
   ✅ AppDelegate: Firebase configured
   OR
   ✅ AppDelegate: Firebase already configured
   ```

3. **User Authentication**
   ```
   ✅ SyncEngine: User authenticated - uid: {userId}
   ```

4. **Migrations (all 4 should complete)**
   ```
   ✅ Guest data already migrated for user: {userId}
   OR
   ✅ Guest to auth migration complete! Migrated X habits
   
   🔄 MIGRATION: Completion status migration already completed
   OR
   🔄 MIGRATION: Completion status migration completed successfully
   
   🔄 MIGRATION: Completion to Event migration already completed
   OR
   ✅ MIGRATION: Successfully migrated X completion records to events
   
   🔄 XPDataMigration: Migration already completed, skipping
   OR
   ✅ XP_MIGRATION_COMPLETE: All data migrated successfully
   ```

5. **Sync Engine Startup** (authenticated users only)
   ```
   ✅ SyncEngine: startPeriodicSync() call completed
   ```

6. **Event Compaction**
   ```
   ✅ EventCompactor: Scheduling completed
   ```

#### ⚠️ Error Patterns to Watch For:

- `❌ SyncEngine: Failed to authenticate user: {error}`
- `⚠️ Guest data migration failed: {error}`
- `❌ MIGRATION: Failed to...`
- `❌ SyncEngine: Failed to...`

### 4. Analyze Logs

**Option A: Use the analyzer script**
```bash
# Save logs to console_logs.txt first, then:
./Scripts/analyze_logs.sh console_logs.txt
```

**Option B: Manual check**
- Use the checklist in `Docs/Testing/QUICK_LOG_CHECKLIST.md`
- Verify all expected patterns are present
- Check for any error patterns

### 5. Check Debug UI

1. In the running app, navigate to:
   - **More tab** → **Debug Tools** → **"📋 Migration Status UI"**

2. Report what you see:
   - Migration completion status (all should show ✅)
   - Data counts:
     - ProgressEvents count
     - CompletionRecords count
     - DailyAwards count

### 6. Share Results

Once you have:
- ✅ Console logs (full output)
- ✅ Debug UI status (migration status + data counts)

Share them here for analysis and verification.

## Quick Test After Log Capture

After verifying logs, test the implementation:

1. **Complete a habit** → Check console for:
   - `📝 setProgress: Creating ProgressEvent`
   - `✅ setProgress: Created ProgressEvent successfully`

2. **Complete all habits for a day** → Check for:
   - `🎯 XP_CHECK: ✅ Awarding X XP`
   - DailyAward creation

3. **Trigger manual sync** → Check for:
   - `🔄 SyncEngine: Starting sync...`
   - `✅ SyncEngine: Sync completed successfully`

## Troubleshooting

### If logs are too verbose:
- Filter by searching for emoji patterns: `🚀`, `✅`, `❌`, `🔄`
- Use the analyzer script to extract key patterns

### If logs are truncated:
- Check Xcode console settings
- Increase console buffer size if needed
- Copy logs in smaller chunks if necessary

### If expected patterns are missing:
- Check that the app launched successfully
- Verify you're looking at the correct console (not build logs)
- Ensure you waited full 30 seconds after launch

