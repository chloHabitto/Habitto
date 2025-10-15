# 🚀 Firebase Migration Setup Guide

**Quick Start**: Enable Firestore sync in 5 minutes

## 📋 **Prerequisites Checklist**

- [ ] Firebase packages installed (FirebaseFirestore, FirebaseCrashlytics, FirebaseRemoteConfig)
- [ ] Firebase project configured with Firestore enabled
- [ ] App builds and runs without errors
- [ ] User has existing habits in UserDefaults

## ⚡ **Quick Setup (5 minutes)**

### **Step 1: Enable Firestore Sync (1 minute)**

1. **Open Firebase Console**: https://console.firebase.google.com/project/habittoios
2. **Go to Remote Config**: Left sidebar → Remote Config
3. **Add Parameter**:
   - Parameter key: `enableFirestoreSync`
   - Default value: `false`
   - Description: `Enable Firestore sync for habit data`
4. **Publish**: Click "Publish changes"

### **Step 2: Test the Migration (2 minutes)**

1. **Launch your app**
2. **Pull to refresh** (or restart app) to fetch new Remote Config
3. **Check console logs** for:
   ```
   🎛️ RemoteConfigService: Firestore sync: true
   ```

### **Step 3: Verify Migration (2 minutes)**

1. **Create a test habit** in your app
2. **Check Firebase Console** → Firestore → Data
3. **Look for** `habits` collection with your new habit
4. **Verify** habit document has `userId` field

## 🔍 **Verification Steps**

### **Console Logs to Look For**
```
🎛️ RemoteConfigService: Updated from remote config:
  - Firestore sync: true
🔥 FirestoreStorage: Saving 1 habits to Firestore
✅ HybridStorage: 1 habits saved to local storage
✅ HybridStorage: 1 habits synced to cloud storage
```

### **Firestore Console Checks**
- Collection: `habits`
- Document ID: Matches your habit's UUID
- Fields: `userId`, `name`, `description`, etc.
- Timestamp: `updatedAt` field present

## 🧪 **Test Scenarios**

### **Basic Test**
1. Create habit → Should appear in Firestore
2. Complete habit → Should sync to Firestore
3. Delete app → Reinstall → Sign in → Habits restored

### **Advanced Test**
1. Enable sync on Device A
2. Create habits
3. Sign in on Device B
4. Habits should appear on Device B

## 🚨 **Troubleshooting**

### **Habits Not Appearing in Firestore**
1. Check Remote Config: `enableFirestoreSync = true`
2. Verify user is authenticated: Check Firebase Auth
3. Check console for errors
4. Verify Firestore rules allow writes

### **App Crashes After Migration**
1. Check console logs for specific errors
2. Verify Firebase packages are installed
3. Check if user is authenticated
4. Rollback: Set `enableFirestoreSync = false`

### **Data Not Syncing**
1. Check internet connection
2. Verify Firestore rules
3. Check user authentication
4. Look for network errors in console

## 🔄 **Rollback Procedure**

### **If Something Goes Wrong**
1. **Firebase Console** → Remote Config
2. **Set** `enableFirestoreSync = false`
3. **Publish** changes
4. **Restart app** - will revert to UserDefaults-only
5. **No data loss** - local storage intact

## 📊 **Expected Behavior**

### **With `enableFirestoreSync = true`**
- ✅ New habits saved to both UserDefaults AND Firestore
- ✅ Existing habits remain in UserDefaults
- ✅ Data syncs across devices
- ✅ Data survives app deletion

### **With `enableFirestoreSync = false`**
- ✅ Habits saved only to UserDefaults (current behavior)
- ✅ No Firestore writes
- ✅ App functions exactly as before

## 🎯 **Success Indicators**

### **Migration Successful If:**
- [ ] Console shows "Firestore sync: true"
- [ ] New habits appear in Firestore Console
- [ ] App functions normally
- [ ] No crashes or errors
- [ ] Existing habits still accessible

### **Ready for Production If:**
- [ ] All test scenarios pass
- [ ] Performance is acceptable
- [ ] Error handling works
- [ ] Rollback procedure tested

## 📞 **Need Help?**

### **Check These Files**
- `FirestoreStorage.swift` - Firestore implementation
- `HybridStorage.swift` - Dual-write logic
- `RemoteConfigService.swift` - Feature flag management
- `StorageFactory.swift` - Storage selection logic

### **Console Commands**
```bash
# Check if Firebase is configured
grep -r "FirebaseApp.configure" .

# Check for Firestore imports
grep -r "import FirebaseFirestore" .
```

### **Firebase Console Links**
- **Project**: https://console.firebase.google.com/project/habittoios
- **Firestore**: https://console.firebase.google.com/project/habittoios/firestore/data
- **Remote Config**: https://console.firebase.google.com/project/habittoios/config
- **Authentication**: https://console.firebase.google.com/project/habittoios/authentication

---

**Total Time**: 5 minutes setup + 10 minutes testing = **15 minutes to migration**

**Risk Level**: 🟢 **LOW** - Feature flag controlled, rollback available, no data loss possible

