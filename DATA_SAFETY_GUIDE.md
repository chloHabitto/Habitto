# Data Safety Guide

## Overview

This document explains the data protection measures in place for Habitto users. It's written for developers to understand how user data is protected through app updates and what happens behind the scenes.

## 🛡️ Data Protection Layers

### 1. **SwiftData Migration System** (NEW)

**What it does:**
- Safely handles database structure changes when the app updates
- Automatically migrates user data to new schema versions
- Prevents data loss during app updates

**How it works:**
- Current schema is documented as "Version 1" (baseline)
- Future schema changes create Version 2, 3, etc.
- Each version includes migration logic to safely transform data
- SwiftData handles the migration automatically when users update

**What users experience:**
- ✅ No data loss when updating the app
- ✅ Seamless transition to new data structures
- ✅ All existing habits, completions, and progress preserved

### 2. **Backup System**

**What it does:**
- Creates automatic backups every 24 hours
- Stores backups locally on device
- Keeps last 10 backups (rotating)
- Supports manual backup creation

**Backup contents:**
- All habits and their data
- Completion history
- XP and achievements
- User settings
- Migration history

**How to use:**
- Backups are automatic (no user action needed)
- Manual backups can be created from Settings
- Backups can be restored if needed

### 3. **Corruption Detection & Recovery**

**What it does:**
- Monitors database health on every app launch
- Detects corrupted or missing database files
- Automatically recovers using UserDefaults fallback
- Recreates healthy database on next launch

**What users experience:**
- ✅ App continues working even if database has issues
- ✅ Data is preserved in fallback storage
- ✅ Automatic recovery without user intervention

### 4. **UserDefaults Fallback**

**What it does:**
- Stores habit data in UserDefaults as emergency backup
- Used automatically if SwiftData fails
- Ensures data is never lost even if database fails

**When it activates:**
- Database corruption detected
- SwiftData save operations fail
- Database file missing or inaccessible

## 🔄 What Happens During App Updates

### Scenario 1: Simple Update (No Schema Changes)

**What happens:**
1. App launches normally
2. Database loads existing data
3. No migration needed (still on Version 1)
4. User sees all their data as before

**User experience:** No change, everything works as expected

### Scenario 2: Update with Schema Changes (Future)

**What happens:**
1. App detects new schema version
2. SwiftData migration system activates
3. Data is automatically transformed to new structure
4. Migration completes (usually instant)
5. User sees all their data in new format

**User experience:** 
- Brief moment during first launch after update
- All data preserved and migrated
- No user action required

### Scenario 3: Update with Breaking Changes

**What happens:**
1. Migration system detects breaking change
2. Custom migration logic runs
3. Data is carefully transformed
4. Backup is created before migration
5. If migration fails, rollback to previous version

**User experience:**
- May take a few seconds on first launch
- Progress indicator shown if needed
- All data preserved

## 📦 Backup & Recovery

### Automatic Backups

**When they happen:**
- Every 24 hours automatically
- Before major migrations
- When app goes to background (if enabled)

**What's backed up:**
- All habits
- All completion records
- XP and achievements
- User settings
- Migration history

**Storage:**
- Local device storage
- Compressed format
- Encrypted (if device encryption enabled)

### Manual Backups

**How to create:**
1. Go to Settings
2. Tap "Backup & Restore"
3. Tap "Create Backup Now"

**When to use:**
- Before major app updates (optional - automatic backups cover this)
- Before device replacement
- Before account deletion

### Restoring from Backup

**How to restore:**
1. Go to Settings → Backup & Restore
2. Select a backup from the list
3. Tap "Restore"
4. Confirm restoration

**What gets restored:**
- All habits and data
- Completion history
- XP and achievements
- Settings (if included in backup)

## ⚠️ What to Do If Something Goes Wrong

### Issue: Data Missing After Update

**Steps:**
1. Check if backup exists (Settings → Backup & Restore)
2. If backup exists, restore from backup
3. If no backup, check UserDefaults fallback (automatic)
4. Contact support if issue persists

**Likelihood:** Very low (multiple safety layers)

### Issue: App Crashes on Launch

**Steps:**
1. App will automatically detect corruption
2. Database will be reset (data preserved in fallback)
3. On next launch, fresh database created
4. Data restored from UserDefaults fallback

**Likelihood:** Very low (corruption detection active)

### Issue: Migration Takes Too Long

**Steps:**
1. Wait for migration to complete (don't force quit)
2. Migration progress shown if available
3. If stuck, restart app (migration will resume)
4. Contact support if migration fails repeatedly

**Likelihood:** Low (migrations are usually instant)

## 🔍 Monitoring & Logging

### What Gets Logged

- Database initialization
- Migration execution
- Backup creation
- Corruption detection
- Error recovery

### Where to Find Logs

- Xcode Console (development)
- Device logs (Settings → Privacy → Analytics)
- Crash reports (if enabled)

## 📊 Data Volume & Limits

### Expected Data Sizes

- **Habits:** ~1-2KB per habit
- **Completions:** ~100 bytes per completion record
- **Total per user:** Typically < 10MB even with years of data

### No Hard Limits

- No limit on number of habits
- No limit on completion history
- No automatic cleanup (data preserved indefinitely)

### Performance

- All operations optimized for large datasets
- Indexing on frequently queried fields
- Background processing for heavy operations

## ✅ Safety Guarantees

### What We Guarantee

1. ✅ **No data loss** during app updates
2. ✅ **Automatic recovery** from corruption
3. ✅ **Backup system** for additional safety
4. ✅ **Fallback storage** if database fails
5. ✅ **Migration testing** before release

### What We Don't Guarantee

- ⚠️ Data loss if device is factory reset (backups are local)
- ⚠️ Data loss if app is uninstalled (backups are local)
- ⚠️ Cross-device sync (not yet implemented)

## 🚀 Future Improvements

### Planned Features

- Cloud backup (iCloud/Google Drive)
- Cross-device sync
- Export to JSON/CSV
- Data retention policies (optional)

### Current Limitations

- Backups are local only
- No cloud sync yet
- No export feature yet

## 📝 Summary

**Bottom line:** User data is protected by multiple layers:
1. SwiftData migration system (handles schema changes)
2. Automatic backups (every 24 hours)
3. Corruption detection (automatic recovery)
4. UserDefaults fallback (emergency backup)

**For users:** Their data is safe. Updates won't cause data loss. If something goes wrong, automatic recovery kicks in.

**For developers:** All safety systems are active. Monitor logs for any issues. Test migrations thoroughly before release.

