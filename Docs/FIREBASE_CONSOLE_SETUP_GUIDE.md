# 🎛️ Firebase Console Remote Config Setup Guide

**Purpose:** Set up Remote Config in Firebase Console to control Firebase sync rollout  
**Estimated Time:** 10 minutes  
**Prerequisites:** Firebase project exists (habittoios)

---

## 📋 Overview

Remote Config allows you to control feature flags from Firebase Console without releasing a new app version. This is perfect for gradual rollout and instant rollback if issues arise.

### What We're Setting Up:

| Parameter | Purpose | Initial Value |
|-----------|---------|---------------|
| `enableFirestoreSync` | Enable dual-write to Firestore | `false` → gradually enable |
| `enableBackfill` | Migrate existing data to Firestore | `false` until dual-write stable |
| `enableLegacyReadFallback` | Fallback to UserDefaults if Firestore empty | `true` (safety net) |

---

## 🚀 Step-by-Step Setup

### Step 1: Access Remote Config

1. **Go to Firebase Console:**
   ```
   https://console.firebase.google.com/project/habittoios/config
   ```

2. **Sign in** with your Google account (if not already signed in)

3. **Select the Habitto project** if you have multiple projects

4. **Click "Remote Config"** in the left sidebar (under "Engage" section)

---

### Step 2: Create Parameters

You'll need to create 3 parameters. For each one:

#### Parameter 1: `enableFirestoreSync`

**Click "+ Add parameter"**

- **Parameter key:** `enableFirestoreSync`
- **Description:** "Enable dual-write to both UserDefaults and Firestore"
- **Data type:** Boolean
- **Default value:** `false`

**Click "Save"**

---

#### Parameter 2: `enableBackfill`

**Click "+ Add parameter"**

- **Parameter key:** `enableBackfill`
- **Description:** "Enable backfill migration of existing UserDefaults data to Firestore"
- **Data type:** Boolean
- **Default value:** `false`

**Click "Save"**

---

#### Parameter 3: `enableLegacyReadFallback`

**Click "+ Add parameter"**

- **Parameter key:** `enableLegacyReadFallback`
- **Description:** "Enable fallback to UserDefaults when Firestore is empty (safety net)"
- **Data type:** Boolean
- **Default value:** `true`

**Click "Save"**

---

### Step 3: Publish Configuration

1. **Review your parameters:**
   - enableFirestoreSync: false
   - enableBackfill: false
   - enableLegacyReadFallback: true

2. **Click "Publish changes"** (top right)

3. **Confirm** the publish

**✅ Done!** Remote Config is now active with safe defaults.

---

## 🧪 Testing Remote Config (Before Rollout)

### Test 1: Verify Fetch Works

**Goal:** Confirm app can fetch Remote Config

**Steps:**
1. Run your app in simulator/device
2. Check console logs for:
   ```
   🎛️ RemoteConfigService: Fetching remote config...
   ✅ RemoteConfigService: Config fetched and activated
   🎛️ Firestore sync: false  // Should show default value
   ```

**Expected Result:** App fetches config successfully, uses default `false` values

---

### Test 2: Enable for Testing

**Goal:** Test enabling Firestore sync remotely

**Firebase Console Steps:**
1. Go to Remote Config
2. Click on `enableFirestoreSync` parameter
3. Change default value to `true`
4. **Publish changes**

**App Steps:**
1. Force-quit app
2. Relaunch app (fetches new config)
3. Check console logs:
   ```
   🎛️ Firestore sync: true  // Should show new value!
   ```
4. Create a habit
5. Verify it appears in Firestore Data

**Expected Result:** Feature flag changes without app update!

---

## 📊 Gradual Rollout Strategy

Once testing confirms Remote Config works, use conditional targeting:

### Phase 1: 1% Rollout (Day 1)

**Firebase Console:**
1. Click on `enableFirestoreSync`
2. Click "+ Add value for condition"
3. Create new condition:
   - **Condition name:** `1_percent_rollout`
   - **Applies if:** User in random percentile <= 1
   - **Value:** `true`
4. Default value stays `false`
5. **Publish changes**

**Result:** 1% of users get Firestore sync, 99% stay on UserDefaults-only

---

### Phase 2: Monitor & Scale

**Day 1-2: Monitor 1% Rollout**
- Check Crashlytics for errors
- Monitor telemetry in app logs
- Verify data appears in Firestore Console

**Day 3: Increase to 10%**
- Update condition: User in random percentile <= 10
- Publish changes

**Day 5: Increase to 50%**
- Update condition: User in random percentile <= 50
- Publish changes

**Day 7: Full Rollout (100%)**
- Change default value to `true`
- Remove condition
- Publish changes

---

### Phase 3: Enable Backfill

**After dual-write is stable for 1 week:**

1. Update `enableBackfill` parameter
2. Use same gradual rollout (1% → 10% → 50% → 100%)
3. Monitor migration completion rates

---

## 🎛️ Advanced: Conditional Targeting

Remote Config supports sophisticated targeting:

### Target Specific Users

**Use Case:** Test with your personal device first

**Condition:**
- **Condition name:** `test_users`
- **Applies if:** User ID in list
- **Value:** `your_firebase_uid`
- **Then set:** `enableFirestoreSync = true`

---

### Target by App Version

**Use Case:** Only enable for users on latest version

**Condition:**
- **Applies if:** App version >= 1.2.0
- **Then set:** `enableFirestoreSync = true`

---

### Target by Platform

**Use Case:** Enable for iOS only (when you add Android later)

**Condition:**
- **Applies if:** Platform == iOS
- **Then set:** `enableFirestoreSync = true`

---

## 🚨 Emergency Rollback

If issues arise with Firestore sync:

### Instant Rollback (No App Update Needed):

1. **Go to Firebase Console → Remote Config**
2. **Change** `enableFirestoreSync` to `false`
3. **Publish changes**
4. **Result:** Within seconds/minutes, all users revert to UserDefaults-only
5. **No data loss:** UserDefaults still has all data

### Kill Switch Scenario:

```
User reports: "App crashes when creating habits"
    ↓
You check: Firestore writes failing
    ↓
Action: Set enableFirestoreSync = false in Console
    ↓
Publish changes
    ↓
Users restart app → Auto-fetches new config
    ↓
App reverts to UserDefaults → Crashes stop
    ↓
You investigate and fix → Re-enable when ready
```

---

## 📊 Monitoring Dashboard

### What to Monitor After Enabling:

**Firebase Console → Analytics:**
- Active users count
- Retention rate (should not drop)
- Crash-free users (should stay high)

**Firebase Console → Crashlytics:**
- Crash rate (should not increase)
- Firestore-related errors
- ANR (Application Not Responding) events

**Firebase Console → Firestore:**
- Document count increasing
- Write operations per minute
- Read operations per minute
- Quota usage

---

## ✅ Verification Checklist

### After Initial Setup:
- [ ] All 3 parameters created in Remote Config
- [ ] Default values are safe (`enableFirestoreSync = false`)
- [ ] Configuration published
- [ ] App successfully fetches config
- [ ] App respects `false` value (UserDefaults-only mode)

### After Test Enablement:
- [ ] Changed `enableFirestoreSync` to `true`
- [ ] App fetched new value
- [ ] Habits write to both Firestore AND UserDefaults
- [ ] Data visible in Firestore Console
- [ ] No errors in console logs
- [ ] Telemetry counters incrementing

### Before Production Rollout:
- [ ] Tested with personal device
- [ ] Verified rollback works (flip to false, confirm app responds)
- [ ] Crashlytics shows no increase in errors
- [ ] Have monitoring dashboard ready
- [ ] Team knows how to rollback if needed

---

## 📞 Support Resources

### Firebase Documentation:
- **Remote Config Overview:** https://firebase.google.com/docs/remote-config
- **Conditional Targeting:** https://firebase.google.com/docs/remote-config/parameters
- **Best Practices:** https://firebase.google.com/docs/remote-config/best-practices

### Habitto-Specific Docs:
- **Data Management State:** `Docs/DATA_MANAGEMENT_CURRENT_STATE.md`
- **Activation Status:** `Docs/FIREBASE_ACTIVATION_STATUS.md`
- **Test Plan:** `Docs/FIREBASE_ACTIVATION_TEST_PLAN.md`

---

## 🎯 Quick Reference

### Current Parameter Values (Safe Defaults):

```json
{
  "enableFirestoreSync": false,
  "enableBackfill": false,
  "enableLegacyReadFallback": true
}
```

### Production Rollout Values (After Testing):

```json
{
  "enableFirestoreSync": true,   // Gradually roll out
  "enableBackfill": true,         // Enable after sync stable
  "enableLegacyReadFallback": true  // Keep as safety net
}
```

### How App Uses These:

```swift
// FeatureFlags.swift
static var enableFirestoreSync: Bool { 
  RemoteConfig.remoteConfig()["enableFirestoreSync"].boolValue
}

// StorageFactory.swift
if FeatureFlags.enableFirestoreSync {
  return .hybrid  // Dual-write mode
} else {
  return .userDefaults  // Current behavior
}
```

---

## 🎬 Timeline

**Today (Setup):**
- [ ] Create Remote Config parameters (10 min)
- [ ] Test fetch works (5 min)
- [ ] Document configuration (done)

**This Week (Testing):**
- [ ] Enable `enableFirestoreSync` for test devices
- [ ] Verify dual-write works
- [ ] Test rollback mechanism

**Next Week (Gradual Rollout):**
- [ ] Day 1: 1% of users
- [ ] Day 3: 10% of users
- [ ] Day 5: 50% of users
- [ ] Day 7: 100% of users

**Week 3 (Backfill):**
- [ ] Enable `enableBackfill` gradually
- [ ] Monitor migration completion
- [ ] Verify data integrity

---

**Ready to set up Remote Config? Follow the steps above and report back when complete!**

**Firebase Console Link:**  
https://console.firebase.google.com/project/habittoios/config

