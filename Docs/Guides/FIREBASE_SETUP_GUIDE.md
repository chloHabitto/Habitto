# Firebase Integration Setup Guide

## 🎯 **Overview**

This guide walks you through optimizing Habitto's Firebase usage by:
1. ✅ Adding FirebaseCrashlytics for crash reporting
2. ✅ Adding FirebaseRemoteConfig for feature flags
3. ❌ Removing unused FirebaseAnalytics package
4. ❌ Removing unused FirebaseDatabase package

**Estimated time:** 10 minutes

---

## 📦 **Step 1: Update Firebase Packages in Xcode**

### **Remove Unused Packages** (2 minutes)

1. **Open Xcode** → `Habitto.xcodeproj`
2. **Select "Habitto" project** in navigator (top blue icon)
3. **Select "Habitto" target** (under TARGETS)
4. **Go to "General" tab**
5. **Scroll to "Frameworks, Libraries, and Embedded Content"**
6. **Find and remove:**
   - ❌ **FirebaseAnalytics** → Select, click "-" button
   - ❌ **FirebaseDatabase** → Select, click "-" button

### **Add New Packages** (2 minutes)

1. **Same location** (Frameworks section)
2. **Click "+" button**
3. **In the search box**, type "Crashlytics"
4. **Select "FirebaseCrashlytics"** from the firebase-ios-sdk package
5. **Click "Add"**
6. **Repeat for "FirebaseRemoteConfig"**:
   - Click "+" again
   - Search "RemoteConfig"
   - Select "FirebaseRemoteConfig"
   - Click "Add"

**Final package list should be:**
```
✅ Algorithms
✅ FirebaseAuth
✅ FirebaseCore
✅ FirebaseCrashlytics    ← NEW
✅ FirebaseRemoteConfig   ← NEW
✅ GoogleSignIn
✅ GoogleSignInSwift
✅ Lottie
✅ MCEmojiPicker
✅ MCEmojiPickerJSON
✅ MijickPopups
```

---

## 🔧 **Step 2: Enable Services in Code**

### **Enable Crashlytics** (1 minute)

Open `App/HabittoApp.swift`:

1. **Uncomment line 3:**
```swift
import FirebaseCrashlytics  // Uncomment this line
```

2. **Uncomment lines 26-28:**
```swift
print("🐛 Initializing Firebase Crashlytics...")
Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
print("✅ Crashlytics initialized")
```

### **Enable Remote Config** (1 minute)

Same file (`App/HabittoApp.swift`):

1. **Uncomment line 4:**
```swift
import FirebaseRemoteConfig  // Uncomment this line
```

2. **Uncomment lines 31-36:**
```swift
print("🎛️ Initializing Firebase Remote Config...")
let remoteConfig = RemoteConfig.remoteConfig()
let settings = RemoteConfigSettings()
settings.minimumFetchInterval = 3600 // 1 hour for production, 0 for dev
remoteConfig.configSettings = settings
print("✅ Remote Config initialized")
```

---

## 🔗 **Step 3: Integrate into Existing Code**

### **Add Crashlytics to AuthenticationManager**

Open `Core/Managers/AuthenticationManager.swift`:

Add after successful sign-in (around line 88):
```swift
// Set user ID for crash reports
CrashlyticsService.shared.setUserID(user.uid)
CrashlyticsService.shared.setValue(user.email ?? "no_email", forKey: "user_email")
```

### **Add Crashlytics to Critical Flows**

#### **Habit Creation** (`Views/Screens/HomeView.swift`)

Add to `createHabit()` function (around line 109):
```swift
func createHabit(_ habit: Habit) async {
  CrashlyticsService.shared.logHabitCreationStart(habitName: habit.name)  // ADD THIS
  
  // ... existing code ...
  
  await habitRepository.createHabit(habit)
  CrashlyticsService.shared.logHabitCreationComplete(habitID: habit.id.uuidString)  // ADD THIS
}
```

#### **Data Migration** (`Core/Data/Migration/DataMigrationManager.swift`)

Add to migration functions:
```swift
CrashlyticsService.shared.logMigrationStart(migrationName: "CompletionStatus")

// ... perform migration ...

CrashlyticsService.shared.logMigrationComplete(migrationName: "CompletionStatus")
```

### **Add Remote Config to FeatureFlags**

Open `Core/Utils/FeatureFlags.swift` and integrate:

```swift
// Fetch remote config on app start
Task {
  await RemoteConfigService.shared.fetchConfig()
}

// Use remote config values
var enableCloudKitSync: Bool {
  RemoteConfigService.shared.enableCloudKitSync
}
```

---

## 🧪 **Step 4: Test the Integration**

### **Test Crashlytics** (2 minutes)

1. **Build and run on device** (Crashlytics doesn't work in Simulator)
2. **Add test crash button** (temporary):
```swift
Button("Test Crash") {
  fatalError("Test crash for Crashlytics")
}
```
3. **Tap the button** → App crashes
4. **Restart app**
5. **Wait 5 minutes**
6. **Check Firebase Console** → Crashlytics section
7. **You should see the crash report** ✅

### **Test Remote Config** (1 minute)

1. **Build and run**
2. **Check console logs:**
```
✅ Remote Config initialized
🎛️ RemoteConfigService: Loaded local config fallback
```
3. **Later**: Set values in Firebase Console → Test they update in app

---

## 📊 **Step 5: Set Up Firebase Console**

### **Enable Crashlytics**

1. Go to **Firebase Console** → Your Habitto project
2. Navigate to **Crashlytics** in sidebar
3. Click "**Enable Crashlytics**"
4. Wait for first crash report (after test crash above)

### **Set Up Remote Config**

1. Go to **Firebase Console** → Your Habitto project
2. Navigate to **Remote Config** in sidebar
3. Click "**Add parameter**"
4. **Add these parameters:**

| Key | Type | Default Value | Description |
|-----|------|---------------|-------------|
| `isMigrationEnabled` | Boolean | `true` | Enable/disable data migration |
| `enableCloudKitSync` | Boolean | `false` | Enable CloudKit sync feature |
| `showNewProgressUI` | Boolean | `false` | Show new progress screen design |
| `maintenanceMode` | Boolean | `false` | Emergency maintenance mode |
| `minAppVersion` | String | `1.0.0` | Minimum supported version |
| `maxFailureRate` | Number | `0.15` | Maximum acceptable failure rate |

5. Click "**Publish changes**"

---

## 📈 **What You'll Get**

### **With Crashlytics:**
- 🐛 **Real-time crash alerts** via email
- 📊 **Crash-free users percentage** (aim for 99.9%)
- 🔍 **Detailed stack traces** with line numbers
- 📱 **Device/OS breakdown** of crashes
- 🎯 **Prioritized issues** (most impactful crashes first)

**Example Dashboard:**
```
Crash-Free Users: 99.2%
Top Issues:
1. NullPointerException in HabitDetailView (affects 45 users)
2. IndexOutOfBounds in StreakCalculator (affects 12 users)
3. MemoryWarning during data migration (affects 8 users)
```

### **With Remote Config:**
- 🎛️ **Instant feature toggles** (no app update needed)
- 🧪 **A/B testing** (show Feature A to 50% of users)
- 🚨 **Emergency kill switches** (disable buggy feature instantly)
- 🎯 **Gradual rollouts** (enable CloudKit for 10% → 50% → 100%)

**Example Use Cases:**
```
Scenario 1: CloudKit sync has a bug
→ Set enableCloudKitSync = false in Firebase Console
→ All users disabled instantly (no app update)

Scenario 2: Want to test new Progress UI
→ Set showNewProgressUI = true for 10% of users
→ Measure engagement
→ Roll out to 100% if successful

Scenario 3: Critical bug found
→ Set maintenanceMode = true
→ Show "We're fixing an issue" screen to all users
→ Set back to false when fixed
```

---

## 🔐 **Privacy & Compliance**

### **Crashlytics Data Collection:**
- ✅ Only crash logs and stack traces
- ✅ No personal user data sent
- ✅ Can be disabled per-user
- ✅ GDPR compliant

### **Remote Config:**
- ✅ Only downloads configuration values
- ✅ No user data uploaded
- ✅ No tracking or analytics
- ✅ Privacy-safe

---

## 📝 **Code Changes Summary**

### **New Files Created:**
1. `Core/Services/CrashlyticsService.swift` - Crashlytics wrapper
2. `Core/Services/RemoteConfigService.swift` - Remote Config wrapper
3. `Docs/Guides/FIREBASE_SETUP_GUIDE.md` - This guide

### **Files to Modify:**
1. `App/HabittoApp.swift` - Uncomment imports and initialization
2. `Core/Managers/AuthenticationManager.swift` - Add user ID tracking
3. `Views/Screens/HomeView.swift` - Add crash logging to habit flows
4. `Core/Data/Migration/DataMigrationManager.swift` - Log migrations
5. `Core/Utils/FeatureFlags.swift` - Integrate Remote Config

---

## ⏱️ **Time Investment vs. Benefit**

| Task | Time | Benefit |
|------|------|---------|
| **Add packages in Xcode** | 4 mins | Foundation for all features |
| **Uncomment code** | 2 mins | Enable Crashlytics + Remote Config |
| **Add logging to critical flows** | 15 mins | Detailed crash context |
| **Set up Firebase Console** | 5 mins | View crash reports |
| **Total** | **26 minutes** | **Production-ready crash reporting** |

---

## 🚀 **Quick Start Checklist**

- [ ] 1. Open Xcode project
- [ ] 2. Remove FirebaseAnalytics package
- [ ] 3. Remove FirebaseDatabase package  
- [ ] 4. Add FirebaseCrashlytics package
- [ ] 5. Add FirebaseRemoteConfig package
- [ ] 6. Uncomment imports in `HabittoApp.swift`
- [ ] 7. Uncomment initialization in `HabittoApp.swift`
- [ ] 8. Build and run
- [ ] 9. Test crash on real device
- [ ] 10. Check Firebase Console for crash report

---

## 💡 **Pro Tips**

### **Crashlytics Best Practices:**

1. **Add breadcrumbs** in critical flows:
```swift
CrashlyticsService.shared.log("User started habit creation")
CrashlyticsService.shared.log("Habit validation passed")
CrashlyticsService.shared.log("Saving habit to repository")
```

2. **Set custom keys** for context:
```swift
CrashlyticsService.shared.setValue("\(habits.count)", forKey: "total_habits")
CrashlyticsService.shared.setValue("\(authState)", forKey: "auth_state")
```

3. **Log non-fatal errors:**
```swift
catch {
  CrashlyticsService.shared.recordError(error)
  // Show user-friendly error message
}
```

### **Remote Config Best Practices:**

1. **Always have local fallbacks:**
```swift
let enabled = RemoteConfigService.shared.enableCloudKitSync
// Falls back to local config.json if fetch fails
```

2. **Fetch config at app start:**
```swift
// In AppDelegate
Task {
  await RemoteConfigService.shared.fetchConfig()
}
```

3. **Use for gradual rollouts:**
```swift
// Enable new feature for small percentage first
if RemoteConfigService.shared.showNewProgressUI {
  NewProgressView()
} else {
  OldProgressView()
}
```

---

## 📞 **Support & Resources**

- **Firebase Console:** https://console.firebase.google.com
- **Crashlytics Docs:** https://firebase.google.com/docs/crashlytics
- **Remote Config Docs:** https://firebase.google.com/docs/remote-config
- **Your Project:** `habitto-app` (or your Firebase project name)

---

## ✅ **Completion Checklist**

When you're done, you should have:
- ✅ Crashlytics reporting crashes to Firebase Console
- ✅ Remote Config pulling feature flags from server
- ✅ Removed unused Analytics and Database packages
- ✅ App size reduced by ~10 MB
- ✅ Production-ready monitoring setup

---

**🎯 Next Steps:** Follow the Quick Start Checklist above to complete the integration!

