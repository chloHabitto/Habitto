# 📦 Step 1: Add FirebaseFirestore Package

**Status**: Ready to install  
**Required for**: Full Firestore functionality

---

## Quick Install (Xcode GUI)

1. Open `Habitto.xcodeproj` in Xcode
2. Select the project in the navigator
3. Go to **Target: Habitto → General → Frameworks, Libraries, and Embedded Content**
4. Click the **+** button
5. Click **Add Other → Add Package Dependency...**
6. The Firebase iOS SDK should already be in your package dependencies
7. If not, enter: `https://github.com/firebase/firebase-ios-sdk`
8. Select version: **12.3.0** or later
9. In the product selection, check **FirebaseFirestore**
10. Click **Add Package**

✅ Done! The package will download and integrate automatically.

---

## Verify Installation

After adding the package, verify it appears in:

### Project Navigator
```
Habitto
├── Dependencies
│   └── firebase-ios-sdk
│       ├── FirebaseAuth ✅ (already installed)
│       ├── FirebaseCore ✅ (already installed)
│       ├── FirebaseCrashlytics ✅ (already installed)
│       ├── FirebaseRemoteConfig ✅ (already installed)
│       └── FirebaseFirestore ⭐ (newly added)
```

### Build Phases → Link Binary With Libraries
Should now include:
- FirebaseFirestore (newly added)
- FirebaseAuth (existing)
- FirebaseCore (existing)
- FirebaseCrashlytics (existing)
- FirebaseRemoteConfig (existing)

---

## Enable Firestore Code

After package installation, uncomment the Firestore code:

### 1. App/AppFirebase.swift
**Line 38-60**: Uncomment the entire `configureFirestore()` implementation

```swift
// REMOVE THIS COMMENT:
/*
print("🔥 FirebaseConfiguration: Configuring Firestore...")

let db = Firestore.firestore()
let settings = FirestoreSettings()
// ... rest of the code
*/
```

### 2. Core/Services/FirestoreService.swift
**Line 9**: Uncomment the import
```swift
// CHANGE FROM:
// import FirebaseFirestore

// TO:
import FirebaseFirestore
```

**Throughout the file**: Uncomment all sections marked with `/* ... */`

Search for comment blocks like:
```swift
/*
// After adding FirebaseFirestore package, use this code:
let db = Firestore.firestore()
...
*/
```

Remove the `/*` and `*/` delimiters to activate the real Firestore implementation.

---

## Test the Installation

### Build Test
```bash
# Should compile without errors
xcodebuild build -scheme Habitto -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Run Tests
```bash
xcodebuild test -scheme Habitto -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Expected**: All `FirebaseIntegrationTests` should pass

### Run App
1. Launch app in simulator
2. Check console logs for:
   ```
   ✅ FirebaseConfiguration: Firestore configured with offline persistence
   ```

---

## Troubleshooting

### Error: "Module 'FirebaseFirestore' not found"
**Solution**: Package not installed yet. Follow the installation steps above.

### Error: "No such module 'Firestore'"
**Solution**: Use `import FirebaseFirestore`, not `import Firestore`

### Error: "Cannot find type 'Firestore' in scope"
**Solution**: Ensure you've uncommented the import statement in the file

### Build succeeds but features don't work
**Solution**: You need to uncomment the Firestore implementation code (see "Enable Firestore Code" above)

---

## Alternative: Manual Package Installation

If Xcode GUI doesn't work, manually edit `project.pbxproj`:

```bash
# Open in text editor
open Habitto.xcodeproj/project.pbxproj
```

### Add to PBXBuildFile section (around line 20)
```
8980C1552E9AA93000E491FB /* FirebaseFirestore in Frameworks */ = {isa = PBXBuildFile; productRef = 8980C1542E9AA93000E491FB /* FirebaseFirestore */; };
```

### Add to Frameworks section (around line 135)
```
8980C1552E9AA93000E491FB /* FirebaseFirestore in Frameworks */,
```

### Add to packageProductDependencies (around line 545)
```
8980C1542E9AA93000E491FB /* FirebaseFirestore */,
```

### Add to XCSwiftPackageProductDependency section (around line 1186)
```
8980C1542E9AA93000E491FB /* FirebaseFirestore */ = {
  isa = XCSwiftPackageProductDependency;
  package = 8935E7882E7C2260004BF684 /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */;
  productName = FirebaseFirestore;
};
```

**Then**:
1. Close Xcode
2. Run `xcodebuild -resolvePackageDependencies`
3. Reopen Xcode

---

## What Happens After Installation?

✅ **Offline Persistence Enabled**
- Firestore caches data locally
- App works offline
- Changes sync when online

✅ **Real-time Listeners Active**
- Habit list updates live
- No manual refresh needed
- Multi-device sync (when implemented)

✅ **Anonymous Auth Works**
- Users auto-signin on first launch
- Each user gets unique uid
- Data properly scoped per user

✅ **Emulator Support Ready**
- Set `USE_FIREBASE_EMULATOR=true`
- Test without production data
- Fast development iteration

---

## Next: Run the Demo

After installation and uncommenting code:

1. **Run App**
2. **Add Demo Screen to Navigation** (or create preview)
3. **Test CRUD Operations**:
   - Create habit: "Morning Run" (green)
   - Update habit: Change to "Evening Run" (blue)
   - Delete habit

**Console Should Show**:
```
🔥 FirebaseConfiguration: Configuring Firestore...
✅ FirebaseConfiguration: Firestore configured with offline persistence
📊 FirestoreService: Fetching habits
✅ FirestoreService: Fetched 3 habits
👂 FirestoreService: Starting real-time listener
✅ Real-time listener active on /users/{uid}/habits
```

---

**Ready for Step 2?** → See `Docs/FIREBASE_BOOTSTRAP_STEP1.md` for next steps

