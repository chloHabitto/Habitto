# 🧪 How to Add Test Target and Tests

The project currently doesn't have a test target configured. Here's how to add one and include the Firebase tests.

---

## Quick Setup (Xcode GUI)

### 1. Create Test Target

1. **Open** `Habitto.xcodeproj` in Xcode
2. **Select** the project in the navigator (top-level "Habitto")
3. **Click** the **+** button at the bottom of the targets list
4. **Choose** "iOS → Unit Testing Bundle"
5. **Configure**:
   - Product Name: `HabittoTests`
   - Target to be Tested: `Habitto`
   - Language: Swift
6. **Click** "Finish"

### 2. Add Test File

1. **Delete** the auto-generated `HabittoTests.swift` file
2. **Rename** `Documentation/TestsReadyToAdd/FirebaseIntegrationTests.swift.template` to `FirebaseIntegrationTests.swift`
3. **Drag** the renamed file into the `HabittoTests` folder in Xcode
4. **Check** "Copy items if needed"
5. **Target Membership**: Ensure `HabittoTests` is checked (NOT the main Habitto target)

### 3. Verify Setup

1. **Press** `Cmd+U` to run tests
2. **Expected**: All 11 tests should pass

---

## Alternative: Command Line Setup

### 1. Create Test Target Manually

```bash
cd /Users/chloe/Desktop/Habitto

# Create test directory if it doesn't exist
mkdir -p HabittoTests

# Rename and move test file
mv Documentation/TestsReadyToAdd/FirebaseIntegrationTests.swift.template HabittoTests/FirebaseIntegrationTests.swift

# Create Info.plist for test bundle
cat > HabittoTests/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
EOF
```

### 2. Open Xcode and Configure Target

1. Open `Habitto.xcodeproj`
2. Add test target as described in GUI method above
3. Add `HabittoTests/FirebaseIntegrationTests.swift` to the target
4. Build & Test

---

## Run Tests

### Via Xcode
```
Cmd+U (run all tests)
Cmd+Ctrl+Option+U (run without building)
```

### Via Command Line
```bash
# Run all tests
xcodebuild test \
  -scheme Habitto \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run specific test class
xcodebuild test \
  -scheme Habitto \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:HabittoTests/FirebaseIntegrationTests
```

### With Firebase Emulator
```bash
# Terminal 1: Start emulator
firebase emulators:start --only firestore,auth

# Terminal 2: Run tests
export USE_FIREBASE_EMULATOR=true
export FIRESTORE_EMULATOR_HOST=localhost:8080
export AUTH_EMULATOR_HOST=localhost:9099

xcodebuild test \
  -scheme Habitto \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

---

## Expected Test Results

### Without Emulator (Mock Mode)
```
Test Suite 'FirebaseIntegrationTests' started
✅ testEnvironmentDetection passed (0.001 seconds)
✅ testFirebaseConfigurationStatus passed (0.002 seconds)
✅ testEmulatorConfiguration passed (0.001 seconds)
✅ testFirestoreServiceInitialization passed (0.001 seconds)
✅ testCreateMockHabit passed (0.015 seconds)
✅ testUpdateMockHabit passed (0.012 seconds)
✅ testDeleteMockHabit passed (0.010 seconds)
✅ testFetchMockHabits passed (0.008 seconds)
✅ testCurrentUserIdProperty passed (0.001 seconds)
✅ testIsAnonymousProperty passed (0.001 seconds)
⚠️ testAnonymousSignIn skipped (Firebase not configured)
✅ testFirestoreErrorDescriptions passed (0.002 seconds)

Test Suite 'FirebaseConfigurationTests' started
✅ testConfigurationStatus passed (0.001 seconds)
✅ testCurrentUserId passed (0.001 seconds)

Executed 13 tests, with 0 failures (0 unexpected) in 0.056 seconds
```

### With Emulator
All tests above, plus:
```
✅ testAnonymousSignIn passed (0.234 seconds)
```

---

## Troubleshooting

### Error: "No such module 'Habitto'"
**Solution**: Ensure `@testable import Habitto` has access. Check:
1. Test target's "Target Dependencies" includes Habitto
2. Build Settings → "Enable Testability" is ON

### Error: "Cannot find 'AppEnvironment' in scope"
**Solution**: Test target needs to import app code
1. Select test target
2. Build Settings → Search "testability"
3. Enable "Enable Testability" = YES

### Tests don't run
**Solution**: 
1. Select `Habitto` scheme
2. Edit Scheme → Test
3. Ensure `HabittoTests` is checked

---

## What the Tests Cover

✅ **Environment Detection**
- Test environment flag
- Firebase configuration status
- Emulator configuration

✅ **Firestore Service (Mock)**
- Service initialization
- Create habit
- Update habit
- Delete habit
- Fetch habits list

✅ **Authentication**
- Current user ID property
- Anonymous user detection
- Anonymous sign-in (with emulator)

✅ **Error Handling**
- All FirestoreError cases
- Localized error descriptions

✅ **Configuration**
- Firebase config status
- Current user ID access

---

## Alternative: Skip Tests for Now

If you want to proceed without setting up tests:

1. **Keep tests in `TestsToAdd/` folder** (they won't compile but won't block builds)
2. **Focus on Step 2** (Firestore schema)
3. **Add test target later** when ready for production

The app will build and run perfectly without a test target. Tests are optional but recommended for production apps.

---

**Status**: Test file ready in `TestsToAdd/FirebaseIntegrationTests.swift`  
**Next**: Either set up test target now, or proceed to Step 2

