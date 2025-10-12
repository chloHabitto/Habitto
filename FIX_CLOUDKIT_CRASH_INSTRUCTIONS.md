# 🔧 Fix CloudKit Crash - Deployment Instructions

**Issue**: App crashes with "Cannot initialize DailyAwardService" CloudKit error  
**Root Cause**: Old app version still running with CloudKit enabled  
**Status**: Code fixed, needs redeployment

---

## ⚡ Quick Fix (Do This Now)

### Step 1: Clean Build
```bash
cd /Users/chloe/Desktop/Habitto

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Habitto-*

# Clean build folder in Xcode
# Cmd+Shift+K (Product → Clean Build Folder)
```

### Step 2: Delete App from Simulator/Device
**In Simulator**:
1. Long press the Habitto app icon
2. Tap the **X** to delete
3. Confirm deletion

**Or via command line**:
```bash
xcrun simctl uninstall booted com.chloe-lee.Habitto
```

### Step 3: Rebuild and Run
```bash
# Build fresh
xcodebuild clean build \
  -scheme Habitto \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Or just run in Xcode
# Cmd+R (will rebuild and install)
```

---

## What This Does

1. **Deletes old database** from simulator (with CloudKit config)
2. **Installs new app** with CloudKit disabled for DailyAward
3. **Creates fresh database** without CloudKit constraints
4. **App launches successfully**

---

## If You're Still Getting the Error

The error logs show the app is running from:
```
/var/mobile/Containers/Data/Application/5C332691-9B76-4DC7-A72B-443B30A5CB4A/
```

This means you're running on a **physical device** (not simulator). You need to:

### Option 1: Delete Database Manually
```bash
# This won't work on real device due to sandboxing
# You MUST delete the app and reinstall
```

### Option 2: Delete App from Device
1. Long press Habitto app icon on device
2. Tap "Remove App"
3. Confirm "Delete App"
4. Rebuild in Xcode and run (Cmd+R)

### Option 3: Reset Database Programmatically

Add this one-time code to delete the old database on app launch:

**In `App/HabittoApp.swift`**, add after Firebase configuration:

```swift
// ONE-TIME FIX: Delete corrupted CloudKit database
Task {
  let databaseURL = URL.applicationSupportDirectory.appending(path: "default.store")
  if FileManager.default.fileExists(atPath: databaseURL.path) {
    try? FileManager.default.removeItem(at: databaseURL)
    print("🗑️ Deleted old CloudKit database")
  }
}
```

Then rebuild and run.

---

## Verification

After rebuild, you should see in console:
```
✅ Firebase Core configured
🔧 SwiftData: Creating ModelContainer (CloudKit sync: DISABLED)...
✅ SwiftData: Container initialized successfully
✅ HabitRepository: Initial habit loading completed
🚀 HomeViewState: Initializing...
✅ App launched successfully
```

**NO CloudKit errors!**

---

## Why This Happened

1. Old app had CloudKit enabled for all models
2. Old database was created with CloudKit schema  
3. I disabled CloudKit in code
4. But old app binary still running on device
5. Old database still incompatible

**Solution**: Fresh install with new code

---

## Next Steps

After successful rebuild:
1. ✅ App should launch without crashes
2. ✅ Your 2 habits should load from UserDefaults
3. ✅ Ready for Step 2 (Firestore migration)

---

**Quick command to do everything:**
```bash
# Stop the app (in Xcode: Cmd+.)
# Clean
rm -rf ~/Library/Developer/Xcode/DerivedData/Habitto-*
# Delete app from simulator
xcrun simctl uninstall booted com.chloe-lee.Habitto
# Rebuild and run
# In Xcode: Cmd+R
```

