# 🧪 Firebase Activation Test Plan

**Date:** October 17, 2025  
**Goal:** Safely activate and test Firebase Firestore dual-write functionality

---

## 📋 Pre-Activation Checklist

### ✅ Verified Components:

1. **Firebase Configuration**
   - ✅ GoogleService-Info.plist exists with valid credentials
   - ✅ Project ID: habittoios
   - ✅ Bundle ID: com.chloe-lee.Habitto
   - ✅ Firebase configured in AppDelegate

2. **Remote Config Setup**
   - ✅ RemoteConfigService exists and loads local config
   - ✅ Local fallback file: `Config/remote_config.json`
   - ✅ Current defaults: `enableFirestoreSync = false`

3. **Storage Architecture**
   - ✅ StorageFactory checks `FeatureFlags.enableFirestoreSync`
   - ✅ If true → returns `.hybrid` (DualWriteStorage)
   - ✅ If false → returns `.userDefaults` (current behavior)

4. **Firebase Services**
   - ✅ FirestoreService with CRUD operations
   - ✅ Anonymous Auth configured
   - ✅ Offline persistence enabled
   - ✅ BackfillJob ready for data migration

---

## 🚀 Testing Strategy: Local First, Then Remote

### Phase 1: Local Testing (This Session)

Test Firebase functionality locally before touching Remote Config.

#### Test 1.1: Verify Firebase Auth Works

**Goal:** Confirm anonymous authentication is working

**Steps:**
1. Run app in simulator/device
2. Check console logs for:
   ```
   ✅ Firebase Core configured
   ✅ User authenticated with uid: [uid]
   ```
3. Verify user persists across app restarts

**Expected Result:**
- Anonymous user created automatically
- User ID persists in Firebase Auth
- No errors in console

---

#### Test 1.2: Enable Firestore Sync Locally

**Goal:** Test dual-write without Remote Config (local override)

**Method 1: Modify local remote_config.json**
```json
{
  "enableFirestoreSync": true,  // Change from false
  "enableBackfill": false,
  "enableLegacyReadFallback": true
}
```

**Method 2: Add local override in AppDelegate**
```swift
// In AppDelegate.didFinishLaunchingWithOptions
RemoteConfigService.shared.enableFirestoreSync = true
print("🧪 TEST MODE: Firestore sync enabled locally")
```

**Steps:**
1. Modify config (choose method 1 or 2)
2. Clean build and run
3. Create a new habit
4. Check console logs for:
   ```
   📝 FirestoreService: Creating habit 'Test Habit'
   ✅ FirestoreService: Habit created with ID: [uuid]
   ✅ UserDefaultsStorage: Saved 1 habits
   ```
5. Open Firebase Console → Firestore → Data
6. Navigate to: `users/{uid}/habits/{habitId}`
7. Verify habit data is present

**Expected Result:**
- Habit saved to BOTH UserDefaults AND Firestore
- No errors
- Data visible in Firebase Console
- App still reads from UserDefaults (no disruption)

---

#### Test 1.3: Test CRUD Operations with Dual-Write

**Goal:** Verify all operations work with dual-write

**Test Cases:**

| Operation | Steps | Expected Behavior |
|-----------|-------|-------------------|
| **Create** | Create new habit "Morning Run" | Saves to UserDefaults + Firestore |
| **Update** | Edit habit name to "Morning Jog" | Updates in both stores |
| **Complete** | Mark habit complete for today | Completion saved to both |
| **Delete** | Delete habit | Removed from both stores |

**Verification:**
- After each operation, check Firestore Console
- Verify data matches what's in the app
- Check telemetry counters: `FirestoreService.logTelemetry()`

---

#### Test 1.4: Test Offline Behavior

**Goal:** Verify offline persistence works

**Steps:**
1. Enable Firestore sync locally
2. Turn off WiFi/cellular on device
3. Create new habit "Offline Test"
4. Turn network back on
5. Wait ~5 seconds
6. Check Firestore Console

**Expected Result:**
- Habit created while offline saves to UserDefaults
- Firestore queues write for later (offline persistence)
- When online, Firestore syncs automatically
- Data appears in Firestore Console

---

### Phase 2: Remote Config Testing (After Local Success)

Once local testing passes, activate via Firebase Remote Config.

#### Test 2.1: Set Up Remote Config Parameters

**Firebase Console Steps:**
1. Go to: https://console.firebase.google.com/project/habittoios/config
2. Click "Add parameter" for each:

| Parameter | Type | Value | Description |
|-----------|------|-------|-------------|
| `enableFirestoreSync` | Boolean | `false` → `true` | Enable dual-write to Firestore |
| `enableBackfill` | Boolean | `false` (keep off) | Backfill migration (test later) |
| `enableLegacyReadFallback` | Boolean | `true` (keep on) | Fallback to UserDefaults |

3. Click "Publish changes"

---

#### Test 2.2: Fetch Remote Config in App

**Steps:**
1. Revert any local overrides from Phase 1
2. Add fetch call in AppDelegate:
   ```swift
   Task {
       await RemoteConfigService.shared.fetchConfig()
       print("🎛️ Remote Config fetched")
       print("🎛️ Firestore sync: \(RemoteConfigService.shared.enableFirestoreSync)")
   }
   ```
3. Run app
4. Check console logs for:
   ```
   ✅ RemoteConfigService: Config fetched and activated
   🎛️ Firestore sync: true
   ```

**Expected Result:**
- Remote Config fetches successfully
- `enableFirestoreSync` is now `true`
- StorageFactory returns `.hybrid` type

---

#### Test 2.3: Gradual Rollout (10% of Users)

**Firebase Console - Conditional Targeting:**
1. Go to Remote Config
2. Click on `enableFirestoreSync` parameter
3. Add condition: "10% of users"
4. Publish

**Steps:**
1. Test with multiple test accounts
2. ~10% should see dual-write enabled
3. Monitor telemetry for 24 hours
4. Check for errors in Crashlytics

---

### Phase 3: Backfill Testing (After Dual-Write Stable)

#### Test 3.1: Enable Backfill for Test Account

**Goal:** Migrate existing UserDefaults data to Firestore

**Setup:**
1. Create test account with 5+ habits (all in UserDefaults only)
2. Complete some habits (create completion history)
3. Enable backfill:
   ```json
   "enableBackfill": true
   ```

**Steps:**
1. Restart app
2. BackfillJob should run automatically
3. Check console logs for:
   ```
   🔄 BackfillJob: Starting backfill migration
   ✅ BackfillJob: Migrated 5 habits to Firestore
   ✅ BackfillJob: Backfill complete
   ```
4. Verify all habits in Firestore Console
5. Verify completion history preserved

**Expected Result:**
- All existing habits migrated to Firestore
- Completion history intact
- No data loss
- UserDefaults data still present (not deleted)

---

## 🔍 Monitoring Checklist

### Console Logs to Watch For:

**✅ Good Signs:**
```
✅ Firebase Core configured
✅ User authenticated with uid: [uid]
✅ Firestore configured with offline persistence
✅ FirestoreService: Habit created
✅ UserDefaultsStorage: Saved X habits
dualwrite.create.primary_ok: 1
dualwrite.create.secondary_ok: 1
```

**⚠️ Warning Signs:**
```
⚠️ FirestoreService: Write failed (retrying...)
⚠️ Firestore offline - queuing writes
dualwrite.secondary_err: 1  // Some Firestore writes failing
```

**❌ Red Flags:**
```
❌ FirestoreService: Not configured
❌ FirestoreService: Not authenticated
❌ Failed to save habits to UserDefaults
❌ Data loss detected
```

---

### Firebase Console Monitoring:

**Firestore Data:**
- Navigate to: Firestore → Data → `users` collection
- Verify user documents exist with correct UIDs
- Check `habits` subcollection has all habits
- Verify field structure matches `FirestoreHabit` model

**Authentication:**
- Navigate to: Authentication → Users
- Verify anonymous users are being created
- Check user retention (users don't get deleted)

**Crashlytics:**
- Navigate to: Crashlytics → Dashboard
- Monitor for any Firebase-related crashes
- Check error rates

---

## 🎯 Success Criteria

### Phase 1 (Local Testing) - Complete When:
- [ ] Anonymous auth creates and persists users
- [ ] Habits save to both UserDefaults AND Firestore
- [ ] All CRUD operations work (create, update, complete, delete)
- [ ] Data visible in Firestore Console matches app
- [ ] Offline persistence queues writes correctly
- [ ] No errors in console logs
- [ ] Telemetry counters show dual-write success

### Phase 2 (Remote Config) - Complete When:
- [ ] Remote Config fetches successfully
- [ ] Feature flags update from server
- [ ] 10% rollout works correctly
- [ ] No increase in crash rate
- [ ] Telemetry shows healthy dual-write metrics
- [ ] No user-reported issues after 48 hours

### Phase 3 (Backfill) - Complete When:
- [ ] BackfillJob migrates all existing data
- [ ] Completion history preserved
- [ ] No data loss
- [ ] All users see their habits after migration
- [ ] Telemetry shows 100% successful migrations

---

## 🚨 Rollback Procedures

### If Issues Arise:

#### Immediate Rollback (Remote Config):
1. Firebase Console → Remote Config
2. Set `enableFirestoreSync = false`
3. Publish changes
4. Users revert to UserDefaults-only on next app launch

#### Local Development Rollback:
1. Revert `remote_config.json` changes
2. Remove any local overrides in AppDelegate
3. Clean build and run

#### Emergency Kill Switch:
```swift
// In AppDelegate
RemoteConfigService.shared.maintenanceMode = true
// This disables all Firebase operations
```

---

## 📊 Expected Timeline

### Conservative Approach:

**Week 1: Local Testing**
- Day 1-2: Verify Firebase Auth and Firestore work
- Day 3-4: Test dual-write locally with all CRUD operations
- Day 5: Test offline behavior and edge cases

**Week 2: Remote Config Rollout**
- Day 1: Enable for 1% of users
- Day 2-3: Monitor metrics, no issues → increase to 10%
- Day 4-5: Monitor metrics, no issues → increase to 50%
- Day 6-7: Monitor metrics, no issues → 100% rollout

**Week 3: Backfill Migration**
- Day 1-2: Enable backfill for 10% of users
- Day 3-5: Monitor migration success rates
- Day 6-7: 100% backfill rollout

### Aggressive Approach:

**Day 1:** Local testing + enable Remote Config for 10%  
**Day 2:** Monitor + increase to 100%  
**Day 3:** Enable backfill for all users  

---

## 🛠️ Development Commands

### Check Current Feature Flags:
```swift
// Add to a debug view or print in AppDelegate
print("🎛️ Feature Flags:")
print("  Firestore Sync: \(FeatureFlags.enableFirestoreSync)")
print("  Backfill: \(FeatureFlags.enableBackfill)")
print("  Legacy Fallback: \(FeatureFlags.enableLegacyReadFallback)")
print("  Storage Type: \(StorageFactory.shared.getRecommendedStorageType())")
```

### Check Telemetry:
```swift
// In a debug menu or console
FirestoreService.shared.logTelemetry()
```

### Force Remote Config Fetch:
```swift
// Add to a debug button
Task {
    await RemoteConfigService.shared.fetchConfig()
    print("Config refreshed!")
}
```

---

## 📝 Next Steps

**Ready to Start Testing?**

1. **Start with Test 1.1** - Verify Firebase Auth works
2. **Then Test 1.2** - Enable Firestore locally and test dual-write
3. **Document results** - Log any issues or unexpected behavior
4. **Move to Remote Config** - Only after local tests pass

**I can help you with:**
- Modifying the config files
- Adding debug logging
- Creating a test view to manually test operations
- Monitoring the Firebase Console
- Analyzing telemetry data

Let me know when you're ready to start! 🚀

