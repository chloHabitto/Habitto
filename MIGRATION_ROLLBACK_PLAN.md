# Migration Rollback Plan

## Overview

This document outlines procedures for detecting, handling, and recovering from failed migrations in the Habitto app. Use this guide if a migration fails in production.

## 🚨 Detecting Migration Failure

### Signs of Migration Failure

1. **App Crashes on Launch**
   - App crashes immediately after update
   - Error logs show migration-related errors
   - Database corruption detected

2. **Data Missing After Update**
   - Habits disappear
   - Completion history missing
   - XP/progress reset to zero

3. **Migration Errors in Logs**
   - "Migration failed" messages
   - "Schema version mismatch" errors
   - "Migration stage failed" errors

4. **User Reports**
   - Users report data loss after update
   - Users report app crashes
   - Users report missing habits/completions

### How to Check Logs

**Xcode Console (Development):**
```
🔧 SwiftData: Creating ModelContainer with migration plan...
❌ Migration failed: [error message]
```

**Device Logs (Production):**
- Settings → Privacy & Security → Analytics & Improvements → Analytics Data
- Look for entries with "SwiftData" or "Migration" in name
- Check timestamps around app update time

## 🔄 Rollback Procedures

### Option 1: Automatic Recovery (Recommended)

**What happens automatically:**
1. Migration failure detected
2. App uses UserDefaults fallback (if available)
3. Database reset on next launch
4. Data restored from fallback

**User action:** None required (automatic)

**When it works:**
- ✅ UserDefaults fallback has recent data
- ✅ Migration failed but database not corrupted
- ✅ App can still launch

### Option 2: Restore from Backup

**Steps:**
1. User opens Settings → Backup & Restore
2. Select latest backup (before update)
3. Tap "Restore"
4. Confirm restoration
5. App restarts with restored data

**When to use:**
- ✅ Backup exists from before update
- ✅ User reports data loss
- ✅ Automatic recovery didn't work

### Option 3: App Version Rollback

**Steps:**
1. **Immediate:** Pull update from App Store (if possible)
2. **Users:** Uninstall current version
3. **Users:** Reinstall previous version from App Store
4. **Users:** Restore from backup if needed

**When to use:**
- ✅ Critical migration failure
- ✅ Multiple users affected
- ✅ No other recovery option works

**Note:** App Store may not allow immediate rollback. Contact Apple Support if needed.

### Option 4: Hotfix Release

**Steps:**
1. **Identify issue:** Determine what caused migration failure
2. **Fix migration:** Update migration code in V2 schema
3. **Create V3:** New schema version with fixed migration
4. **Test thoroughly:** Test on affected database state
5. **Release hotfix:** Push update with fixed migration

**When to use:**
- ✅ Migration logic has bug
- ✅ Can be fixed quickly
- ✅ Users can wait for update

## 📋 Step-by-Step Rollback Process

### Phase 1: Assessment (5 minutes)

1. **Check error reports:**
   - Review Crashlytics/Firebase reports
   - Check user support tickets
   - Review analytics for crash spikes

2. **Verify scope:**
   - How many users affected?
   - What data is missing?
   - Is app still functional?

3. **Check logs:**
   - Migration error messages
   - Database corruption indicators
   - Backup availability

### Phase 2: Immediate Response (15 minutes)

1. **If critical (many users affected):**
   - [ ] Pull update from App Store (if possible)
   - [ ] Notify users via in-app message
   - [ ] Prepare rollback instructions

2. **If minor (few users affected):**
   - [ ] Verify backups exist
   - [ ] Test restore procedure
   - [ ] Prepare user instructions

3. **Document issue:**
   - [ ] Record error details
   - [ ] Note affected users
   - [ ] Document recovery steps taken

### Phase 3: Recovery (30 minutes)

1. **For affected users:**
   - [ ] Provide backup restore instructions
   - [ ] Provide app reinstall instructions (if needed)
   - [ ] Monitor recovery success

2. **For development:**
   - [ ] Reproduce issue locally
   - [ ] Identify root cause
   - [ ] Plan fix

### Phase 4: Fix & Release (Variable)

1. **Fix migration:**
   - [ ] Update migration code
   - [ ] Create new schema version
   - [ ] Test thoroughly

2. **Release fix:**
   - [ ] Submit to App Store
   - [ ] Monitor rollout
   - [ ] Verify fix works

## 🔍 Diagnostic Commands

### Check Migration Status

```swift
// In Xcode debugger or test code
let container = SwiftDataContainer.shared
let context = container.modelContext

// Check current schema version
let headerDescriptor = FetchDescriptor<StorageHeader>()
let headers = try context.fetch(headerDescriptor)
print("Current schema version: \(headers.first?.schemaVersion ?? 0)")

// Check migration records
let migrationDescriptor = FetchDescriptor<MigrationRecord>()
let migrations = try context.fetch(migrationDescriptor)
print("Migration history: \(migrations.count) records")
```

### Check Database Health

```swift
// Test database accessibility
let healthCheck = container.checkDatabaseHealth()
print("Database health: \(healthCheck)")

// Check for corruption
let integrity = container.validateDataIntegrity()
print("Data integrity: \(integrity)")
```

### Check Backup Availability

```swift
let backupManager = BackupManager.shared
let backups = backupManager.availableBackups
print("Available backups: \(backups.count)")
for backup in backups {
    print("  - \(backup.createdAt): \(backup.habitCount) habits")
}
```

## 🛠️ Manual Recovery Steps

### If UserDefaults Fallback Exists

1. **Check fallback data:**
   ```swift
   let defaults = UserDefaults.standard
   if let data = defaults.data(forKey: "SavedHabits") {
       // Fallback data exists
       // App should auto-restore on next launch
   }
   ```

2. **Force restore:**
   - Delete corrupted database
   - Restart app
   - App will restore from UserDefaults

### If Backup Exists

1. **Locate backup:**
   - Settings → Backup & Restore
   - Select backup from list
   - Verify backup date (should be before update)

2. **Restore backup:**
   - Tap "Restore" on selected backup
   - Confirm restoration
   - Wait for restore to complete

3. **Verify restoration:**
   - Check habits are restored
   - Check completion history
   - Check XP/progress

### If No Backup Available

1. **Check database directly:**
   - Database location: `~/Library/Application Support/Habitto/default.store`
   - May be recoverable with SQLite tools
   - **Warning:** Only attempt if you know what you're doing

2. **Contact support:**
   - Provide error logs
   - Provide database file (if possible)
   - Request manual recovery assistance

## 📊 Prevention Checklist

Before releasing a migration:

- [ ] **Test on development database** with real data
- [ ] **Test on fresh install** (no migration)
- [ ] **Test on existing database** (with migration)
- [ ] **Test rollback** (can we revert if needed?)
- [ ] **Verify backups** are being created
- [ ] **Monitor logs** during testing
- [ ] **Document migration** in release notes
- [ ] **Have rollback plan** ready

## 🚨 Emergency Contacts

### Internal

- **Development Team:** Review migration code
- **QA Team:** Test rollback procedures
- **Support Team:** Handle user reports

### External

- **Apple Developer Support:** For App Store rollback
- **Firebase Support:** For crash reporting issues
- **User Support:** For affected users

## 📝 Post-Incident Review

After resolving a migration failure:

1. **Document what happened:**
   - Root cause analysis
   - Affected users count
   - Recovery time
   - Data loss (if any)

2. **Update procedures:**
   - Improve migration testing
   - Update rollback plan
   - Add prevention measures

3. **Communicate:**
   - Update team on lessons learned
   - Update documentation
   - Update user communication templates

## ✅ Recovery Success Criteria

Migration recovery is successful when:

- ✅ All user data restored
- ✅ App functions normally
- ✅ No data loss confirmed
- ✅ Users can continue using app
- ✅ No recurring issues

## 📚 Related Documentation

- **Migration Guide:** `Core/Data/SwiftData/Migrations/MIGRATION_GUIDE.md`
- **Schema Guidelines:** `SCHEMA_CHANGE_GUIDELINES.md`
- **Data Safety:** `DATA_SAFETY_GUIDE.md`
- **Backup System:** `Core/Data/Backup/BackupManager.swift`

## 🎯 Quick Reference

| Situation | Action |
|-----------|--------|
| Migration fails on launch | Check logs → Restore from backup |
| Data missing after update | Check backups → Restore → Verify |
| App crashes after update | Check migration errors → Rollback version |
| Multiple users affected | Pull update → Notify users → Release fix |
| Single user affected | Provide restore instructions → Monitor |

---

**Remember:** Most migration failures can be recovered automatically. The backup system and UserDefaults fallback provide multiple safety nets. Only in extreme cases is manual intervention needed.

