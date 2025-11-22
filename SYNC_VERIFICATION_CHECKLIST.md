# Sync Verification Checklist

## Phase 1: Anonymous Auth & Firestore Sync - Verification Steps

### Step 1: Build and Launch App

1. ✅ Build the app (should succeed without errors)
2. ✅ Launch the app in Xcode Simulator or device
3. ✅ Wait at least 30 seconds after launch to allow sync cycle to execute

### Step 2: Console Log Verification

Look for these logs in Xcode Console (in order):

#### A. App Launch Sequence
```
🚀 AppDelegate: Task block started executing...
🔐 AppDelegate: Ensuring user authentication...
✅ AppDelegate: User authenticated - uid: [Firebase UID]
🔄 AppDelegate: Starting guest data migration...
✅ AppDelegate: Guest data migration completed
🔄 AppDelegate: Starting periodic sync for user: [Firebase UID]
✅ AppDelegate: Periodic sync started
```

#### B. Sync Initialization (should appear within 1-2 seconds)
```
🚀 SYNC_START: startPeriodicSync called - userId: [Firebase UID], forceRestart: NO
🔄 SYNC_START: Starting periodic sync (every 300s)
🚀 SYNC_TASK: Task block started executing
🔍 SYNC_TASK: FeatureFlags.enableFirestoreSync = NO
🔍 SYNC_DEBUG: Periodic sync check - userId: '[UID]...', isEmpty: NO, isGuestId: NO
🔄 SyncEngine: Starting periodic sync for authenticated user: [UID]
🔄 SyncEngine: Performing initial sync cycle...
```

#### C. Sync Cycle Execution (should appear within 5-10 seconds)
```
🚀 SYNC_CYCLE: performFullSyncCycle called - userId: '[UID]...'
🔄 SYNC_CYCLE: Starting full sync cycle for user: [UID]
🔄 SYNC_CYCLE: Step 1 - Starting pullRemoteChanges for userId: [UID]
✅ SyncEngine: Pull remote changes completed: [summary]
🔄 SYNC_CYCLE: Step 2 - Starting syncEvents
🔍 SYNC_DEBUG: Event sync check - userId: '[UID]...', isEmpty: NO, isGuestId: NO
🔄 Starting event sync for user: [UID]
✅ SYNC_CYCLE: syncEvents completed successfully
🔄 SYNC_CYCLE: Step 3 - Starting syncCompletions
✅ SYNC_CYCLE: syncCompletions completed successfully
🔄 SYNC_CYCLE: Step 4 - Starting syncAwards
✅ SYNC_CYCLE: syncAwards completed successfully
✅ SYNC_CYCLE: Full sync cycle completed
✅ SyncEngine: Initial sync cycle completed
```

#### D. Test Habit Creation (after creating a habit)
```
🔄 SYNC_CYCLE: Step 2 - Starting syncEvents
🔍 SYNC_DEBUG: Event sync check - userId: '[UID]...', isEmpty: NO, isGuestId: NO
🔄 Starting event sync for user: [UID]
[Event sync details...]
✅ SYNC_CYCLE: syncEvents completed successfully
```

### Step 3: Firebase Console Verification

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Firestore Database**
4. Check for the following structure:

```
users/
  └── [Firebase UID]/
      ├── events/
      │   └── [yearMonth]/
      │       └── events/
      │           └── [eventId]/
      │               ├── id: [eventId]
      │               ├── userId: [Firebase UID]
      │               ├── habitId: [habitId]
      │               ├── dateKey: [date]
      │               └── ... (other event fields)
      ├── completions/
      │   └── [completionId]/
      │       ├── completionId: [completionId]
      │       ├── habitId: [habitId]
      │       ├── dateKey: [date]
      │       └── ... (other completion fields)
      └── daily_awards/
          └── [userIdDateKey]/
              ├── userIdDateKey: [userIdDateKey]
              ├── dateKey: [date]
              ├── xpGranted: [number]
              └── ... (other award fields)
```

### Step 4: Troubleshooting

#### If you DON'T see `🚀 SYNC_TASK` logs:
- **Problem**: Task block is not executing
- **Possible causes**:
  - Task is being cancelled before execution
  - App is crashing before sync starts
  - Logs are being filtered out

#### If you see `⏭️ SYNC_DEBUG: Periodic sync BLOCKED`:
- **Problem**: User is being treated as guest
- **Check**:
  - `userId` value in the log
  - `isGuestId` value (should be `NO`)
  - Firebase Auth state (should show `exists: YES`)

#### If you see sync cycle logs but no Firebase data:
- **Problem**: Firestore writes are failing silently
- **Check**:
  - Firebase project configuration
  - Firestore security rules
  - Network connectivity
  - Error logs in console

#### If `FeatureFlags.enableFirestoreSync = NO`:
- **Note**: This flag only affects the backfill job, NOT the sync operations
- Sync should still work even if this flag is `NO`

### Step 5: Expected Results

✅ **Success Criteria:**
1. All initialization logs appear in order
2. `🚀 SYNC_TASK` and `🚀 SYNC_CYCLE` logs appear
3. No "BLOCKED" or "Skipping sync" messages (except for legitimate guest users)
4. Firebase Console shows data in `users/{userId}/` collections
5. Creating a habit triggers sync and data appears in Firestore

❌ **Failure Indicators:**
1. Missing `🚀 SYNC_TASK` or `🚀 SYNC_CYCLE` logs
2. "BLOCKED" messages for authenticated anonymous users
3. No data in Firebase Console after 30+ seconds
4. Error messages in console

### Step 6: Data Verification Commands

If you have Firebase CLI installed, you can verify data programmatically:

```bash
# List all users
firebase firestore:get users --project [your-project-id]

# Get specific user's data
firebase firestore:get users/[userId] --project [your-project-id]

# Get events for a user
firebase firestore:get users/[userId]/events --project [your-project-id]
```

### Notes

- **Sync Interval**: Periodic sync runs every 5 minutes (300 seconds)
- **Initial Sync**: First sync happens immediately after `startPeriodicSync()` is called
- **Anonymous Users**: Should have Firebase UID (not empty string)
- **Guest Users**: Only users with `userId = ""` should skip sync

