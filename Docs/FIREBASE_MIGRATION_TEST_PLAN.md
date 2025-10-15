# 🔥 Firebase Migration Test Plan

**Date**: December 2024  
**Status**: Ready for Testing  
**Migration**: UserDefaults → HybridStorage (UserDefaults + Firestore)

## 📋 **Test Overview**

This document outlines the complete testing procedure for migrating from UserDefaults-only storage to HybridStorage (dual-write to both UserDefaults and Firestore).

## 🎯 **Test Objectives**

1. **Data Safety**: Ensure no data loss during migration
2. **Feature Flag Control**: Verify Remote Config controls migration
3. **Offline Support**: Test app functionality without internet
4. **Cross-Device Sync**: Verify data syncs across devices
5. **Rollback Capability**: Test ability to disable Firestore sync

## 🧪 **Test Environment Setup**

### **Prerequisites**
- ✅ Firebase packages installed (FirebaseFirestore, FirebaseCrashlytics, FirebaseRemoteConfig)
- ✅ Firebase project configured with Firestore enabled
- ✅ Test device with internet connection
- ✅ Firebase Console access

### **Test Data**
Create test habits with various data types:
- Simple habit (text-based)
- Habit with completion history
- Habit with difficulty tracking
- Habit with custom reminders
- Habit with notes and tags

## 📝 **Test Cases**

### **Test Case 1: Current State Verification**

**Objective**: Verify current UserDefaults-only behavior

**Steps**:
1. Ensure `enableFirestoreSync` feature flag is `false` (default)
2. Launch app and create 3-5 test habits
3. Complete some habits and add completion history
4. Verify habits are saved in UserDefaults
5. Force-close app and restart
6. Verify habits are still present

**Expected Result**: 
- ✅ All habits load from UserDefaults
- ✅ No Firestore writes occur
- ✅ App functions normally

---

### **Test Case 2: Feature Flag Activation**

**Objective**: Test enabling Firestore sync via Remote Config

**Steps**:
1. In Firebase Console → Remote Config
2. Add parameter: `enableFirestoreSync = true`
3. Publish the configuration
4. In app, pull to refresh or restart app
5. Create a new test habit
6. Check Firebase Console → Firestore → Data

**Expected Result**:
- ✅ New habit appears in Firestore `habits` collection
- ✅ Habit document contains `userId` field
- ✅ Habit document ID matches `habit.id.uuidString`

---

### **Test Case 3: Hybrid Storage Migration**

**Objective**: Test dual-write functionality

**Steps**:
1. With `enableFirestoreSync = true`
2. Create 2-3 new habits
3. Complete some habits (add to completion history)
4. Modify existing habits
5. Check both UserDefaults and Firestore

**Expected Result**:
- ✅ Data written to both UserDefaults and Firestore
- ✅ Both storages contain identical data
- ✅ No data loss or corruption

---

### **Test Case 4: Offline Functionality**

**Objective**: Test app works without internet

**Steps**:
1. With `enableFirestoreSync = true`
2. Ensure habits are loaded and cached
3. Disable internet connection (airplane mode)
4. Create new habits
5. Complete existing habits
6. Modify habit details
7. Re-enable internet
8. Check if data syncs to Firestore

**Expected Result**:
- ✅ App functions normally offline
- ✅ Data saved locally in UserDefaults
- ✅ Data syncs to Firestore when online (Firestore offline persistence)

---

### **Test Case 5: Cross-Device Sync**

**Objective**: Test data sync across multiple devices

**Prerequisites**: Two devices with same Firebase user

**Steps**:
1. Device A: Sign in with test account
2. Device A: Create habits with `enableFirestoreSync = true`
3. Device B: Sign in with same account
4. Device B: Launch app and check habits
5. Device B: Modify a habit
6. Device A: Check if changes appear

**Expected Result**:
- ✅ Habits appear on Device B
- ✅ Changes sync between devices
- ✅ No duplicate habits created

---

### **Test Case 6: App Deletion and Restoration**

**Objective**: Test data survives app deletion

**Steps**:
1. With `enableFirestoreSync = true`
2. Create several test habits
3. Complete some habits
4. Delete app from device
5. Reinstall app
6. Sign in with same account
7. Check if habits are restored

**Expected Result**:
- ✅ All habits restored from Firestore
- ✅ Completion history intact
- ✅ User settings preserved

---

### **Test Case 7: Rollback Testing**

**Objective**: Test ability to disable Firestore sync

**Steps**:
1. With `enableFirestoreSync = true`
2. Create some test habits
3. In Firebase Console: Set `enableFirestoreSync = false`
4. Restart app
5. Create new habits
6. Check Firestore - should see no new documents

**Expected Result**:
- ✅ New habits only saved to UserDefaults
- ✅ Existing Firestore data remains intact
- ✅ App functions normally with local-only storage

---

### **Test Case 8: Error Handling**

**Objective**: Test behavior when Firestore is unavailable

**Steps**:
1. With `enableFirestoreSync = true`
2. Create habits normally (should work)
3. Block Firestore API calls (network restrictions)
4. Try to create new habits
5. Check app behavior and error logs

**Expected Result**:
- ✅ App continues to function with local storage
- ✅ Errors logged but don't crash app
- ✅ Data syncs when Firestore becomes available

---

### **Test Case 9: Performance Testing**

**Objective**: Test performance impact of dual-write

**Steps**:
1. Measure habit creation time with `enableFirestoreSync = false`
2. Measure habit creation time with `enableFirestoreSync = true`
3. Test with 50+ habits
4. Monitor memory usage and CPU

**Expected Result**:
- ✅ Dual-write adds <200ms to habit creation
- ✅ Memory usage increase <10MB
- ✅ No noticeable UI lag

---

### **Test Case 10: Data Integrity**

**Objective**: Test data consistency between storages

**Steps**:
1. With `enableFirestoreSync = true`
2. Create habits with complex data (completion history, notes, etc.)
3. Export UserDefaults data
4. Export Firestore data
5. Compare data structures

**Expected Result**:
- ✅ Data structures match exactly
- ✅ All fields preserved correctly
- ✅ No data corruption or loss

## 🔍 **Debugging Tools**

### **Console Logs to Monitor**
```
🔥 FirestoreStorage: Saving X habits to Firestore
✅ HybridStorage: X habits saved to local storage
✅ HybridStorage: X habits synced to cloud storage
🎛️ RemoteConfigService: Firestore sync: true/false
```

### **Firebase Console Checks**
- Firestore → Data → `habits` collection
- Remote Config → Parameters → `enableFirestoreSync`
- Authentication → Users (verify user IDs match)

### **UserDefaults Inspection**
```swift
// In debugger or code:
let habits = UserDefaults.standard.data(forKey: "SavedHabits")
let decoded = try? JSONDecoder().decode([Habit].self, from: habits)
print("UserDefaults habits count: \(decoded?.count ?? 0)")
```

## 📊 **Success Criteria**

### **Must Pass (Critical)**
- ✅ No data loss during migration
- ✅ Feature flag controls migration correctly
- ✅ App works offline
- ✅ Rollback works without issues

### **Should Pass (Important)**
- ✅ Cross-device sync works
- ✅ Data survives app deletion
- ✅ Performance impact is minimal
- ✅ Error handling is graceful

### **Nice to Have (Optional)**
- ✅ Real-time sync updates
- ✅ Conflict resolution works
- ✅ Bulk operations are efficient

## 🚨 **Known Issues & Limitations**

### **Current Limitations**
1. **Anonymous Users**: Data tied to anonymous UID, not recoverable if app deleted
2. **Conflict Resolution**: Uses last-write-wins (no merge conflicts)
3. **Batch Operations**: Large habit lists may take time to sync

### **Workarounds**
1. **Anonymous Users**: Encourage users to sign in with email/Google
2. **Conflicts**: Rare in single-user app, acceptable for now
3. **Batch Operations**: Background sync, doesn't block UI

## 📈 **Performance Benchmarks**

### **Target Metrics**
- Habit Creation: <500ms total (local + cloud)
- Habit Loading: <200ms (from cache)
- Data Sync: <2 seconds for 100 habits
- Memory Usage: <50MB additional

### **Monitoring**
```swift
// Add to FirestoreStorage for monitoring
let startTime = CFAbsoluteTimeGetCurrent()
// ... operation ...
let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
logger.info("Operation took \(timeElapsed)s")
```

## 🔄 **Rollback Plan**

### **If Migration Fails**
1. Set `enableFirestoreSync = false` in Remote Config
2. Publish configuration
3. App will revert to UserDefaults-only
4. No data loss (local storage still intact)

### **If Data Corruption**
1. Disable Firestore sync
2. Clear local cache: `HybridStorage.clearCache()`
3. Reload habits from UserDefaults
4. Investigate Firestore data structure

## ✅ **Test Completion Checklist**

- [ ] Test Case 1: Current State Verification
- [ ] Test Case 2: Feature Flag Activation  
- [ ] Test Case 3: Hybrid Storage Migration
- [ ] Test Case 4: Offline Functionality
- [ ] Test Case 5: Cross-Device Sync
- [ ] Test Case 6: App Deletion and Restoration
- [ ] Test Case 7: Rollback Testing
- [ ] Test Case 8: Error Handling
- [ ] Test Case 9: Performance Testing
- [ ] Test Case 10: Data Integrity

## 📞 **Support & Resources**

### **Firebase Console**
- Project: habittoios
- Firestore: https://console.firebase.google.com/project/habittoios/firestore
- Remote Config: https://console.firebase.google.com/project/habittoios/config

### **Documentation**
- FirestoreStorage.swift - Implementation details
- HybridStorage.swift - Dual-write logic
- RemoteConfigService.swift - Feature flag management

### **Logs & Monitoring**
- Console.app → Filter by "com.habitto.app"
- Firebase Console → Crashlytics (when enabled)
- Xcode Console for detailed logs

---

**Next Steps**: Execute test cases in order, document results, and proceed with production rollout if all tests pass.

