# 🔐 Anonymous Cloud Backup Implementation

This document describes the implementation of anonymous Firebase authentication and automatic cloud backup for Habitto.

## Overview

The implementation enables **invisible cloud backup** that works automatically in the background:
- Users are automatically signed in anonymously on app launch
- All data changes are backed up to Firestore (non-blocking)
- Guest data is automatically migrated to anonymous user
- No UI changes - completely transparent to users

## Architecture

```
App Launch → Anonymous Auth → Guest Migration → Cloud Backup (on every save)
```

## Files Modified

### 1. `Core/Managers/AuthenticationManager.swift`

**Added:** `ensureAnonymousAuth()` method

- Automatically signs in anonymously if no user is authenticated
- Stores userId in Keychain for persistence across app reinstalls
- Falls back gracefully to guest mode if Firebase is unavailable
- Runs silently in the background

**Key Features:**
- Checks if user already authenticated (anonymous or otherwise)
- Attempts to restore from Keychain first
- Signs in anonymously if needed
- Stores userId securely in Keychain

### 2. `Core/Services/FirebaseBackupService.swift` (NEW)

**Purpose:** Non-blocking cloud backup service

**Methods:**
- `backupHabit(_:)` - Backs up habit to Firestore
- `backupCompletionRecord(...)` - Backs up completion record
- `backupDailyAward(...)` - Backs up daily XP award
- `deleteHabitBackup(habitId:)` - Deletes habit from Firestore

**Key Features:**
- All operations are non-blocking (use `Task.detached`)
- Fail silently - don't interrupt user experience
- Only backup if user is authenticated
- Organized Firestore structure for efficient queries

### 3. `App/HabittoApp.swift`

**Added:**
- Call to `ensureAnonymousAuth()` on app launch
- Guest data migration to anonymous user
- Backup of migrated data

**Migration Flow:**
1. After anonymous auth is established
2. Check if guest data exists (userId = "")
3. Migrate all guest data to anonymous userId
4. Backup migrated data to Firestore

### 4. `Core/Data/Repository/HabitStore.swift`

**Added backup calls after:**
- `saveHabits()` - Backs up all habits
- `setProgress()` - Backs up completion records
- `checkDailyCompletionAndAwardXP()` - Backs up daily awards
- `deleteHabit()` - Deletes habit from Firestore

**Key Features:**
- All backup calls are non-blocking
- Run on MainActor to access FirebaseBackupService
- Don't block local saves - backups happen in background

## Firestore Structure

```
/users/{anonymousUserId}/
  ├── habits/{habitId}/
  │   ├── All HabitData properties as JSON
  │   └── syncedAt: timestamp
  │
  ├── completions/{yearMonth}/records/{recordId}/
  │   ├── habitId: string
  │   ├── date: timestamp
  │   ├── dateKey: string
  │   ├── isCompleted: bool
  │   ├── progress: int
  │   └── syncedAt: timestamp
  │
  └── daily_awards/{dateKey}/
      ├── dateKey: string
      ├── xpGranted: int
      ├── allHabitsCompleted: bool
      ├── grantedAt: timestamp
      └── syncedAt: timestamp
```

## Guest Data Migration

**When:** After anonymous authentication is established

**What gets migrated:**
1. **HabitData** - All habits with userId = ""
2. **CompletionRecord** - All completion records with userId = ""
3. **DailyAward** - All daily awards with userId = ""
4. **UserProgressData** - User progress with userId = ""

**Process:**
1. Fetch all records with userId = ""
2. Update userId to anonymous user's UID
3. Update unique constraint keys (userIdHabitIdDateKey, userIdDateKey)
4. Save to SwiftData
5. Backup to Firestore

**Migration Flag:**
- Stored in UserDefaults: `guest_to_anonymous_migrated_{userId}`
- Prevents duplicate migrations

## Keychain Storage

**Key:** `UserID` (via `KeychainManager.storeUserID()`)

**Purpose:** Persist anonymous userId across app reinstalls

**Accessibility:** `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`

## Error Handling

**All backup operations:**
- Fail silently (log warnings only)
- Don't throw errors
- Don't interrupt user experience
- Continue working offline if Firebase unavailable

**Anonymous Auth:**
- Falls back to guest mode if Firebase unavailable
- App continues working normally
- No crashes or error dialogs

## Non-Blocking Design

**All backup operations use:**
```swift
Task.detached { [weak self] in
  await self?.performBackup(...)
}
```

**Benefits:**
- Local saves complete immediately
- Backups happen in background
- No UI lag or blocking
- User experience unchanged

## Testing Checklist

- [ ] App launches and signs in anonymously
- [ ] Guest data migrates to anonymous user
- [ ] Habits are backed up after creation
- [ ] Completions are backed up after progress updates
- [ ] Daily awards are backed up after XP is awarded
- [ ] Habits are deleted from Firestore when deleted locally
- [ ] App works offline (backups queue and retry)
- [ ] No UI changes visible to user
- [ ] Keychain persists userId across reinstalls

## Future Enhancements

When building iPad sync:

1. **Add READ operations** from Firestore
2. **Add sync UI** in Settings
3. **Add conflict resolution** for multi-device sync
4. **Add real-time listeners** for live updates
5. **Add device linking** features

## Security Notes

- Anonymous users can only access their own data (Firestore security rules required)
- userId stored securely in Keychain
- No PII stored in backups
- All operations are user-scoped

## Firestore Security Rules (Required)

Add these rules to `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /habits/{habitId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /completions/{yearMonth}/records/{recordId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /daily_awards/{dateKey} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

## Console Logs

**Look for these logs:**
- `✅ AuthenticationManager: Anonymous sign-in successful`
- `✅ AuthenticationManager: Stored anonymous userId in Keychain`
- `🔄 GuestMigration: Starting migration to anonymous user`
- `✅ FirebaseBackupService: Backed up habit '...' to Firestore`
- `✅ FirebaseBackupService: Backed up completion record...`
- `✅ FirebaseBackupService: Backed up daily award...`

## Questions Answered

1. **Should I modify AuthenticationManager or create a new AnonymousAuthManager?**
   - ✅ Modified AuthenticationManager (simpler, fits existing pattern)

2. **Where should the Firestore backup logic live?**
   - ✅ Created FirebaseBackupService (centralized, reusable)

3. **Do you want me to handle offline queuing now or add that later?**
   - ⚠️ Basic implementation done (fails silently offline)
   - 🔄 Full offline queue can be added later if needed

## Summary

✅ Anonymous authentication on app launch
✅ Automatic guest data migration
✅ Non-blocking cloud backup after every save
✅ No UI changes - completely invisible
✅ Ready for iPad sync implementation (just add READ operations)

---

**Implementation Date:** 2024
**Status:** ✅ Complete and ready for testing

