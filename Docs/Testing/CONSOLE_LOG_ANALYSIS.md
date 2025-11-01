# 📊 Console Log Analysis Guide

## 🎯 Purpose
This document helps verify that all migrations, sync operations, and core functionality are working correctly based on console log output.

## ✅ Expected Log Sequence on App Launch

### Phase 1: App Initialization
```
🚀 AppDelegate: INIT CALLED
🚀 AppDelegate: INIT CALLED (NSLog)
🚀 AppDelegate: didFinishLaunchingWithOptions called
🚀 AppDelegate: didFinishLaunchingWithOptions called (NSLog)
```

### Phase 2: Firebase Configuration
```
🔥 AppDelegate: Configuring Firebase...
✅ AppDelegate: Firebase configured
```
OR (if already configured):
```
✅ AppDelegate: Firebase already configured
```

### Phase 3: Authentication Setup
```
🚀 AppDelegate: Creating Task.detached for SyncEngine initialization...
🚀 AppDelegate: Task block started executing...
🚀 AppDelegate: Calling FirebaseConfiguration.configureAuth()...
✅ AppDelegate: FirebaseConfiguration.configureAuth() completed
🔍 SyncEngine: Starting authentication check...
✅ SyncEngine: User authenticated - uid: {userId}
```

### Phase 4: Guest Data Migration (if applicable)
```
🔄 Starting guest to auth migration...
   From: {guestUserId}
   To: {authUserId}
📦 Found X guest habits to migrate
✅ Guest to auth migration complete! Migrated X habits
```
OR (if already migrated):
```
✅ Guest data already migrated for user: {authUserId}
```

### Phase 5: Backfill Job (if Firestore sync enabled)
```
🔄 SyncEngine: Running backfill job...
✅ SyncEngine: Backfill job completed
```

### Phase 6: Completion Status Migration
```
🔄 MIGRATION: Starting completion status migration...
🔄 MIGRATION: Found X habits to migrate
🔄 MIGRATION: Migrating habit '{habitName}'
🔄 MIGRATION: Completion status migration completed successfully
```
OR (if already completed):
```
🔄 MIGRATION: Completion status migration already completed
```

### Phase 7: Completions to Events Migration
```
🔄 MIGRATION: Starting completion to event migration...
🔄 MIGRATION: Found X completion records to migrate
🔄 MIGRATION: Migrated X records... (every 100 records)
✅ MIGRATION: Successfully migrated X completion records to events
⏭️ MIGRATION: Skipped X records (already migrated)
```
OR (if already completed):
```
🔄 MIGRATION: Completion to Event migration already completed
```

### Phase 8: XP Data Migration
```
🔄 XPDataMigration: Starting XP data migration...
🔄 XPDataMigration: Found X records with old userId
🔄 XPDataMigration: Migrating X records to guest user
✅ XPDataMigration: Migration completed successfully
```
OR (if already completed):
```
🔄 XPDataMigration: Migration already completed, skipping
```

### Phase 9: Sync Engine Initialization (authenticated users only)
```
🔍 SyncEngine: Checking if user is guest - uid: {uid}, isGuest: NO
✅ SyncEngine: User is authenticated, accessing SyncEngine.shared...
🔍 SyncEngine: About to access SyncEngine.shared...
✅ SyncEngine: SyncEngine.shared accessed (initialization should have logged above)
✅ SyncEngine: Calling startPeriodicSync(userId: {uid})...
✅ SyncEngine: startPeriodicSync() call completed
```

### Phase 10: Event Compaction Scheduling
```
📅 EventCompactor: Initializing for authenticated user: {uid}
✅ EventCompactor: Scheduling completed
```

### Phase 11: Guest User Handling (if guest)
```
⏭️ SyncEngine: Skipping sync for guest user
```

## 🔍 Log Analysis Checklist

### ✅ Critical Success Indicators

- [ ] **Firebase Configured**: Should see `✅ AppDelegate: Firebase configured` or `✅ AppDelegate: Firebase already configured`
- [ ] **User Authenticated**: Should see `✅ SyncEngine: User authenticated - uid: {userId}`
- [ ] **Migrations Completed**: Should see completion messages for all migrations:
  - [ ] Guest to Auth migration (if applicable)
  - [ ] Completion Status migration
  - [ ] Completions to Events migration
  - [ ] XP Data migration
- [ ] **Sync Engine Started**: Should see `✅ SyncEngine: startPeriodicSync() call completed` (for authenticated users)
- [ ] **Event Compaction Scheduled**: Should see `✅ EventCompactor: Scheduling completed` (for authenticated users)

### ⚠️ Warning Indicators

- [ ] **Guest Data Migration Failed**: Look for `⚠️ Guest data migration failed: {error}`
- [ ] **Migration Errors**: Look for `❌ MIGRATION: Failed to...`
- [ ] **Sync Errors**: Look for `❌ SyncEngine: Failed to...`
- [ ] **Authentication Errors**: Look for `❌ SyncEngine: Failed to authenticate user: {error}`

### 🔄 Expected Behavior Patterns

1. **First Launch (Fresh Install)**:
   - All migrations should run and complete
   - Guest user created (if not signed in)
   - No sync for guest users

2. **Subsequent Launches**:
   - Migrations should skip with "already completed" messages
   - Sync should start automatically for authenticated users
   - Event compaction should be scheduled

3. **Guest User**:
   - Migrations may run, but sync will be skipped
   - Should see `⏭️ SyncEngine: Skipping sync for guest user`

## 📋 Migration Status Verification

### Using Debug UI
1. Open app → More tab → Debug Tools → "📋 Migration Status UI"
2. Check migration completion status
3. Review data counts (ProgressEvents, CompletionRecords, DailyAwards)

### Using Console Logs
Look for these specific log patterns:

**Completion Status Migration:**
- Key: `completion_status_migration_completed`
- Log: `🔄 MIGRATION: Completion status migration already completed`

**Completions to Events Migration:**
- Key: `completions_to_events_migration_completed`
- Log: `🔄 MIGRATION: Completion to Event migration already completed`

**XP Data Migration:**
- Key: `XPDataMigration_Completed`
- Log: `🔄 XPDataMigration: Migration already completed, skipping`

**Guest to Auth Migration:**
- Key: `GuestToAuthMigration_{userId}`
- Log: `✅ Guest data already migrated for user: {userId}`

## 🐛 Common Issues & Solutions

### Issue: Migrations Not Running
**Symptoms:**
- No migration logs appear
- Data counts remain zero

**Possible Causes:**
1. Feature flags disabled
2. User is guest (some migrations skip)
3. Migrations already completed (check for "already completed" messages)

**Solution:**
- Check `FeatureFlags.enableFirestoreSync`
- Verify user authentication status
- Use debug UI to check migration status

### Issue: Sync Not Starting
**Symptoms:**
- No `startPeriodicSync` logs
- No sync success/error toasts

**Possible Causes:**
1. User is guest (sync skipped for guests)
2. Feature flag disabled
3. Authentication error

**Solution:**
- Verify user is authenticated (not guest)
- Check authentication logs
- Verify feature flags

### Issue: Migration Errors
**Symptoms:**
- `❌ MIGRATION: Failed to...` logs
- Migration status shows "failed" in debug UI

**Possible Causes:**
1. SwiftData context errors
2. Invalid data format
3. Concurrent access issues

**Solution:**
- Check full error message in logs
- Verify SwiftData model context is accessible
- Check for data corruption

## 📊 Data Count Verification

After migrations complete, verify data counts:

### Expected Counts (First Launch)
- **ProgressEvents**: Should match number of migrated CompletionRecords + any new events
- **CompletionRecords**: Should remain unchanged (migration creates events, doesn't delete records)
- **DailyAwards**: Should match existing awards (XP migration may update userIds)

### Expected Counts (Subsequent Launches)
- **ProgressEvents**: Should increase with each habit completion
- **CompletionRecords**: Should increase with each habit completion
- **DailyAwards**: Should increase when all habits completed for a day

## 🎯 Next Steps After Log Review

1. **If All Logs Are Green** ✅:
   - Proceed with manual testing (complete habits, verify events)
   - Test sync operations
   - Verify XP awards

2. **If Errors Present** ❌:
   - Document specific error messages
   - Check error causes using checklist above
   - Fix issues before proceeding

3. **If Migrations Incomplete** ⚠️:
   - Use debug UI to check status
   - Verify UserDefaults keys
   - Check for partial migration errors

## 📝 Log Patterns Reference

### Migration Patterns
- `🔄 MIGRATION: Starting...` - Migration beginning
- `✅ MIGRATION: Successfully...` - Migration completed
- `🔄 MIGRATION: ...already completed` - Migration skipped (already done)
- `❌ MIGRATION: Failed to...` - Migration error

### Sync Patterns
- `🔄 SyncEngine: Starting...` - Sync beginning
- `✅ SyncEngine: ...completed` - Sync successful
- `❌ SyncEngine: Failed to...` - Sync error
- `📤 Found X unsynced events` - Events ready to sync

### XP Patterns
- `🎯 XP_CHECK: ✅ Awarding...` - XP awarded
- `🎯 XP_CHECK: ❌ Removing...` - XP reversed
- `🎯 XP_CHECK: ✅ Reversed X XP` - XP reversal successful

---

**Last Updated**: After successful build with debug UI
**Status**: Ready for log analysis and testing

