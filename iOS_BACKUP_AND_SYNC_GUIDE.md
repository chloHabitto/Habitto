# iOS Backup & Sync Guide - Habitto

## Overview

This document explains how Habitto data is handled by iOS backups, what happens during app deletion/restoration, device replacement scenarios, and future cross-device sync options.

**Current Architecture:**
- ✅ **SwiftData** (local SQLite database) - Primary storage
- ✅ **iOS Automatic Backups** - Included in iCloud/iTunes backups
- ✅ **App-Level Backups** - BackupManager creates manual backups
- ❌ **CloudKit Sync** - Disabled (infrastructure ready but not active)
- ❌ **Cross-Device Sync** - Not available (local storage only)

---

## Part 1: Current iOS Backup Behavior

### Question 1: iOS Backups (iCloud/iTunes/Finder)

#### ✅ **Is SwiftData included in the backup automatically?**

**YES** - SwiftData databases are automatically included in iOS backups.

**How it works:**
1. **Storage Location**: SwiftData stores data in `Application Support` directory
   - Path: `~/Library/Application Support/default.store`
   - This directory is **automatically included** in iOS backups

2. **What gets backed up:**
   - ✅ All SwiftData database files (`.store` files)
   - ✅ All related database files (`.store-wal`, `.store-shm`)
   - ✅ Database metadata and indexes
   - ✅ All 13 model types (HabitData, CompletionRecord, etc.)

3. **Backup Methods:**
   - **iCloud Backup**: Automatically backs up when device is:
     - Connected to WiFi
     - Connected to power
     - Screen is locked
   - **iTunes/Finder Backup**: Backs up when you manually sync
   - **Both methods include SwiftData**

#### ✅ **When they restore to a new iPhone, does all Habitto data appear?**

**YES** - If they restore from a full backup, all Habitto data will be restored.

**Restore Process:**
1. User sets up new iPhone
2. Chooses "Restore from iCloud Backup" or "Restore from iTunes/Finder"
3. iOS restores all app data, including SwiftData database
4. When Habitto launches, it finds the existing database
5. **All habits, completions, streaks, and settings are restored**

**Important Notes:**
- ✅ Data is restored exactly as it was
- ✅ No data loss (assuming backup was recent)
- ✅ Migration system will handle any schema changes automatically
- ⚠️ If backup is old, data will be as old as the backup

#### ✅ **What about if they restore from backup on the same phone?**

**YES** - Restoring from backup on the same phone will restore Habitto data.

**Scenario:**
1. User backs up iPhone
2. User deletes Habitto app (or resets phone)
3. User restores from backup
4. Habitto data is restored along with the app

**Important Notes:**
- ✅ Works the same as restoring to a new device
- ✅ All data is restored
- ⚠️ If user deleted app before backing up, data won't be in backup

---

## Part 2: App Deletion Scenarios

### Question 2: App Deletion and Reinstallation

#### ❓ **If a user deletes Habitto and reinstalls it, is their data gone permanently?**

**It depends on when they deleted it relative to their last backup:**

#### Scenario A: User deletes app, then backs up
- ❌ **Data is GONE** - The backup doesn't include the app or its data
- ❌ **Cannot be recovered** - Data is permanently lost
- ⚠️ **This is the worst-case scenario**

#### Scenario B: User backs up, then deletes app
- ✅ **Data is SAFE** - The backup includes the app and its data
- ✅ **Can be recovered** - Restore from backup to get data back
- ✅ **Reinstalling from App Store won't restore data** - But restoring from backup will

#### Scenario C: User deletes app, then immediately reinstalls (no backup in between)
- ❌ **Data is GONE** - SwiftData files are deleted when app is deleted
- ❌ **Cannot be recovered** - Unless they have a backup from before deletion

#### ✅ **Can iOS restore it from backup?**

**YES, but only if:**
1. The backup was created **before** the app was deleted
2. The user restores from that backup (not just reinstalls the app)

**Important Distinction:**
- **Reinstalling from App Store** = Fresh install (no data)
- **Restoring from backup** = Full restore (includes data)

#### 📋 **Expected Behavior Summary:**

| Action | Backup Status | Data Status | Recovery Possible? |
|--------|--------------|-------------|-------------------|
| Delete app → Reinstall | No backup | ❌ Data lost | ❌ No |
| Delete app → Reinstall | Backup exists (before deletion) | ✅ Data in backup | ✅ Yes (restore from backup) |
| Delete app → Reinstall | Backup exists (after deletion) | ❌ Data lost | ❌ No |
| Delete app → Restore from backup | Backup exists (before deletion) | ✅ Data restored | ✅ Yes |

**Recommendation for Users:**
- Always back up before deleting apps
- Use iCloud Backup (automatic) or iTunes/Finder (manual)
- Consider using Habitto's built-in backup feature (BackupManager) for extra safety

---

## Part 3: Device Replacement Scenarios

### Question 3: Device Replacement

#### ✅ **Option A: Restores from iCloud backup → Does Habitto data transfer?**

**YES** - Full data transfer.

**Process:**
1. User gets new iPhone
2. During setup, chooses "Restore from iCloud Backup"
3. Selects the most recent backup (which includes Habitto data)
4. iOS restores everything, including:
   - ✅ Habitto app
   - ✅ SwiftData database (all habits, completions, streaks)
   - ✅ App settings and preferences
5. When Habitto launches, everything is exactly as it was

**Timeline:**
- Initial restore: 30 minutes - 2 hours (depending on backup size)
- Habitto data: Included in the restore
- User experience: Seamless - no data loss

#### ❌ **Option B: Sets up as new iPhone and installs Habitto → Does data transfer?**

**NO** - No data transfer.

**Process:**
1. User gets new iPhone
2. During setup, chooses "Set up as new iPhone"
3. User manually installs Habitto from App Store
4. Habitto launches with **empty database** (fresh install)
5. **All previous data is lost** (unless they have a backup they can restore from)

**Why this happens:**
- Setting up as new iPhone = Fresh start
- No app data is transferred
- SwiftData database is created fresh
- User starts from scratch

**Recovery Options:**
- ❌ Cannot recover from this scenario (unless they restore from backup)
- ✅ Can use Habitto's built-in backup feature if they exported data before
- ✅ Can restore from iCloud/iTunes backup if they have one

---

## Part 4: Future iPad Scenario

### Question 4: iPad Version (Future)

#### ❓ **If a user has Habitto on iPhone, then installs on iPad, will they see separate data on each device?**

**YES** - With current architecture, each device will have separate data.

**Current Behavior (No Cloud Sync):**
- ✅ **iPhone**: Has its own SwiftData database (local storage)
- ✅ **iPad**: Has its own SwiftData database (local storage)
- ❌ **No connection** between the two
- ❌ **No automatic sync**

**What this means:**
- User creates habits on iPhone → Only visible on iPhone
- User creates habits on iPad → Only visible on iPad
- Completions on iPhone → Only tracked on iPhone
- Completions on iPad → Only tracked on iPad
- **Two completely separate instances**

#### ❌ **Is there any automatic sync between iPhone and iPad without implementing cloud sync?**

**NO** - There is no automatic sync without cloud infrastructure.

**Why:**
- SwiftData is local-only (stored on each device)
- No network communication between devices
- No shared storage or sync mechanism
- Each device operates independently

#### ✅ **Would they need to manually export/import data?**

**YES** - Manual export/import would be required.

**Current Options:**
1. **BackupManager Export/Import** (if implemented):
   - Export backup file from iPhone
   - Transfer to iPad (AirDrop, email, iCloud Drive)
   - Import backup on iPad
   - ⚠️ This would **replace** iPad data with iPhone data (not merge)

2. **Future Options** (if cloud sync is added):
   - Automatic sync via CloudKit
   - Automatic sync via Firebase
   - Real-time updates across devices

**Limitations of Manual Export/Import:**
- ❌ One-way transfer (export → import)
- ❌ Replaces destination data (doesn't merge)
- ❌ Not real-time (requires manual action)
- ❌ No conflict resolution
- ❌ User must remember to sync regularly

---

## Part 5: Future Cross-Device Sync Options

### Question 5: Cross-Device Sync (Future Consideration)

#### 🔧 **What would need to be implemented?**

**Option 1: CloudKit Sync (Recommended for iOS)**

**What it is:**
- Apple's native cloud sync service
- Built into iOS/macOS
- Private database per user
- Automatic conflict resolution

**What needs to be implemented:**

1. **Enable CloudKit in SwiftData:**
   ```swift
   // In SwiftDataContainer.swift
   let modelConfiguration = ModelConfiguration(
     schema: schema,
     cloudKitDatabase: .automatic)  // Change from .none to .automatic
   ```

2. **CloudKit Entitlements:**
   - Add CloudKit capability in Xcode
   - Configure CloudKit container
   - Set up CloudKit schema

3. **Conflict Resolution:**
   - Implement conflict resolution strategy
   - Handle day-level conflicts (completions)
   - Merge strategies for concurrent edits

4. **User Authentication:**
   - CloudKit uses iCloud account (automatic)
   - No additional sign-in required
   - Uses Apple ID

**Complexity:** Medium
- ✅ Infrastructure already exists (CloudKitManager.swift)
- ✅ SwiftData has built-in CloudKit support
- ⚠️ Need to enable and configure
- ⚠️ Need conflict resolution logic
- ⚠️ Need testing across devices

**Timeline:** 2-4 weeks (depending on conflict resolution complexity)

---

**Option 2: Firebase/Firestore Sync**

**What it is:**
- Google's cloud database service
- Real-time synchronization
- Cross-platform support

**What needs to be implemented:**

1. **Firestore Schema:**
   - Design Firestore collections to match SwiftData models
   - Set up indexes and security rules
   - Implement data transformation layer

2. **Sync Engine:**
   - Background sync service (SyncEngine.swift exists)
   - Push local changes to Firestore
   - Pull remote changes to local
   - Handle offline queue

3. **Conflict Resolution:**
   - Last-write-wins (simple)
   - Day-level conflict resolution (complex)
   - Merge strategies

4. **User Authentication:**
   - Firebase Auth (already integrated)
   - Anonymous auth (possible)
   - Email/password, Google, Apple sign-in

**Complexity:** High
- ✅ Firebase Auth already integrated
- ✅ SyncEngine.swift exists (for ProgressEvent sync)
- ⚠️ Need to extend to all models
- ⚠️ Need bidirectional sync
- ⚠️ Need conflict resolution
- ⚠️ Need offline queue management

**Timeline:** 4-8 weeks (depending on scope)

---

**Option 3: Custom CloudKit Implementation**

**What it is:**
- Use CloudKit directly (not through SwiftData)
- Full control over sync logic
- Custom conflict resolution

**What needs to be implemented:**

1. **CloudKit Models:**
   - Define CKRecord schemas
   - Map SwiftData models to CKRecords
   - Handle relationships

2. **Sync Service:**
   - Push/pull logic
   - Change detection
   - Conflict resolution
   - Background sync

3. **Data Transformation:**
   - SwiftData → CloudKit
   - CloudKit → SwiftData
   - Handle type conversions

**Complexity:** Very High
- ⚠️ More control but more work
- ⚠️ Need to implement everything manually
- ⚠️ More testing required

**Timeline:** 6-12 weeks

---

#### ✅ **Can this be done WITHOUT requiring user sign-in? (Anonymous auth?)**

**YES** - Multiple options:

**Option 1: CloudKit (No Sign-In Required)**
- ✅ Uses iCloud account (automatic)
- ✅ User doesn't need to "sign in" to Habitto
- ✅ Works if user has iCloud enabled
- ❌ Requires iCloud account (most users have this)

**Option 2: Firebase Anonymous Auth**
- ✅ No email/password required
- ✅ Automatic anonymous account creation
- ✅ Works immediately
- ⚠️ User can "upgrade" to real account later
- ⚠️ Data tied to anonymous account (can be lost if app deleted)

**Option 3: Device-Based Sync (No Cloud)**
- ✅ No sign-in required
- ✅ Uses local network (AirDrop, Bluetooth)
- ❌ Limited range (devices must be nearby)
- ❌ Not automatic (requires user action)

**Recommendation:**
- **CloudKit** is best for iOS (no sign-in, automatic, privacy-focused)
- **Firebase Anonymous Auth** is good for cross-platform (no sign-in, but less seamless)

---

#### 📊 **How complex would this be to add later?**

**Complexity Assessment:**

| Option | Complexity | Timeline | User Experience | Privacy |
|--------|-----------|----------|-----------------|---------|
| **CloudKit (SwiftData)** | Medium | 2-4 weeks | ⭐⭐⭐⭐⭐ Seamless | ⭐⭐⭐⭐⭐ Apple |
| **Firebase Anonymous** | High | 4-8 weeks | ⭐⭐⭐⭐ Good | ⭐⭐⭐ Google |
| **Firebase Full** | High | 4-8 weeks | ⭐⭐⭐⭐ Good | ⭐⭐⭐ Google |
| **Custom CloudKit** | Very High | 6-12 weeks | ⭐⭐⭐⭐⭐ Seamless | ⭐⭐⭐⭐⭐ Apple |

**Recommendation: CloudKit (SwiftData)**

**Why:**
- ✅ Lowest complexity (SwiftData has built-in support)
- ✅ Best user experience (automatic, no sign-in)
- ✅ Best privacy (Apple ecosystem)
- ✅ Infrastructure already exists (just needs enabling)
- ✅ Fastest to implement

**Migration Path:**
1. Enable CloudKit in SwiftDataContainer
2. Test on development devices
3. Implement conflict resolution
4. Beta test with users
5. Roll out gradually

**Estimated Effort:**
- **Phase 1** (Enable CloudKit): 1 week
- **Phase 2** (Conflict Resolution): 1-2 weeks
- **Phase 3** (Testing & Polish): 1 week
- **Total: 3-4 weeks**

---

## Part 6: Recommendations

### For Current Users

**Data Safety:**
1. ✅ Enable iCloud Backup (automatic)
2. ✅ Use Habitto's built-in backup feature (BackupManager)
3. ✅ Back up before major iOS updates
4. ✅ Back up before deleting the app

**Best Practices:**
- Keep iCloud Backup enabled
- Check backup status regularly (Settings → iCloud → iCloud Backup)
- Use Habitto's export feature before major changes
- Don't delete app without backing up first

### For Future iPad Version

**Without Cloud Sync:**
- ⚠️ Users will have separate data on each device
- ⚠️ Manual export/import required
- ⚠️ No real-time sync
- ✅ Simple architecture (no cloud complexity)

**With Cloud Sync (Recommended):**
- ✅ Automatic sync across devices
- ✅ Real-time updates
- ✅ No manual intervention
- ✅ Better user experience

**Recommendation:**
- **Short-term**: Release iPad version with separate data (acceptable for MVP)
- **Long-term**: Add CloudKit sync for seamless experience

### For Cross-Device Sync Implementation

**Recommended Approach: CloudKit (SwiftData)**

**Why:**
1. **Easiest to implement** - SwiftData has built-in support
2. **Best user experience** - Automatic, no sign-in
3. **Best privacy** - Apple ecosystem, end-to-end encrypted
4. **Infrastructure ready** - CloudKitManager exists, just needs enabling

**Implementation Steps:**
1. Enable CloudKit in SwiftDataContainer (change `.none` to `.automatic`)
2. Add CloudKit capability in Xcode
3. Implement conflict resolution (day-level for completions)
4. Test on multiple devices
5. Beta test with users
6. Roll out gradually

**Timeline:** 3-4 weeks

---

## Part 7: Technical Details

### SwiftData Storage Location

```swift
// Current storage location
let databaseURL = URL.applicationSupportDirectory.appending(path: "default.store")
// Path: ~/Library/Application Support/default.store
```

**Backup Inclusion:**
- ✅ `Application Support` directory is included in iOS backups
- ✅ All `.store`, `.store-wal`, `.store-shm` files are backed up
- ✅ Database is restored with app data during restore

### Current CloudKit Status

```swift
// In SwiftDataContainer.swift (line 224)
let modelConfiguration = ModelConfiguration(
  schema: schema,
  cloudKitDatabase: .none)  // ❌ Currently disabled
```

**To Enable:**
```swift
let modelConfiguration = ModelConfiguration(
  schema: schema,
  cloudKitDatabase: .automatic)  // ✅ Enable CloudKit
```

### BackupManager Status

**Current Features:**
- ✅ Manual backup creation
- ✅ Backup restoration
- ✅ iCloud Drive integration
- ✅ Google Drive integration (if configured)
- ✅ Local storage backup

**Backup Frequency:**
- Manual only (user-initiated)
- Automatic scheduling available but not enabled by default

---

## Summary

### Current Behavior

| Scenario | Data Status | Recovery |
|----------|-------------|----------|
| **iOS Backup** | ✅ Included automatically | ✅ Restores with backup |
| **App Deletion** | ❌ Lost (unless backed up) | ✅ If backup exists |
| **New Device (Restore)** | ✅ Transfers with backup | ✅ Automatic |
| **New Device (Fresh)** | ❌ No data | ❌ No recovery |
| **iPad (No Sync)** | ❌ Separate data | ❌ Manual export/import |

### Future Options

| Option | Complexity | Timeline | User Experience |
|--------|-----------|----------|-----------------|
| **CloudKit** | Medium | 3-4 weeks | ⭐⭐⭐⭐⭐ Best |
| **Firebase** | High | 4-8 weeks | ⭐⭐⭐⭐ Good |
| **Custom** | Very High | 6-12 weeks | ⭐⭐⭐⭐⭐ Best |

### Recommendations

1. **Current Users**: Enable iCloud Backup, use Habitto's backup feature
2. **iPad Version**: Start without sync, add CloudKit later
3. **Cross-Device Sync**: Implement CloudKit (easiest, best UX, best privacy)

---

**Questions?** Check the architecture docs or contact the development team.

