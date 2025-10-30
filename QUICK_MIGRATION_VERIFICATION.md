# Quick Migration Verification Script

**5-Minute Test to Verify Guest Migration Fix**

---

## **Quick Test (Manual)**

### **Setup (30 seconds)**
1. Delete Habitto app from device/simulator
2. Reinstall from Xcode
3. Launch app (as guest - don't sign in)

### **Create Test Data (1 minute)**
1. Tap "+" to create a new habit
   - Name: "Test Migration"
   - Icon: 🎯
   - Save
2. Tap the habit to mark it completed (today)
3. Go back to habit list

### **Trigger Migration (1 minute)**
1. Tap "Profile" tab (bottom right)
2. Tap "Sign In"
3. Sign in with any account (Google/Apple/Email)

### **Verify Fix Works (1 minute)**
✅ **EXPECTED**: Migration UI appears with:
- Title: "Welcome to Your Account!"
- Shows: "1 habit" in the preview
- Two buttons: "Keep My Data" and "Start Fresh"

❌ **IF THIS HAPPENS**: Migration UI never appears, habits are gone
→ **FIX FAILED** - Report immediately

### **Complete Migration (30 seconds)**
1. Tap "Keep My Data"
2. Confirm the warning dialog
3. Wait for "Migration complete!"

### **Final Verification (30 seconds)**
1. Check habit list - should see "Test Migration" habit
2. Check if completion is still marked for today
3. ✅ If yes → **FIX WORKS!**

---

## **Console Log Quick Check**

While testing, watch Xcode console for these messages:

### ✅ **GOOD - Fix is working:**
```
🔄 HabitRepository: Guest data detected - showing migration UI...
✅ Guest data found, user can choose to migrate or start fresh
🔄 GuestDataMigration: Migrating 1 guest habits to user...
✅ GuestDataMigration: Successfully migrated guest data
```

### ❌ **BAD - Fix is NOT working:**
```
shouldShowMigrationView = false  // UI forcibly hidden
clearStaleGuestData()  // Data being deleted!
```

If you see ❌ messages, the fix didn't apply correctly.

---

## **Quick Debug Commands**

Run these in Xcode console if something seems wrong:

### **Check if guest data exists:**
```swift
po UserDefaults.standard.data(forKey: "guest_user_habits")
// Should return data (not nil) if habits were created
```

### **Check migration UI flag:**
```swift
po habitRepository.shouldShowMigrationView
// Should be true if guest data exists
```

### **Force show migration UI (for testing):**
```swift
habitRepository.shouldShowMigrationView = true
// Manually trigger the UI to appear
```

---

## **Common Issues**

| Issue | Cause | Fix |
|-------|-------|-----|
| Migration UI never appears | Line 232 still forcing false | Check HabittoApp.swift:232 |
| Habits disappear after sign-in | clearStaleGuestData() still running | Check HabitRepository.swift:954-960 |
| Migration fails with error | Network issue | Turn off Airplane Mode and retry |
| "No data found" but created habits | Wrong UserDefaults key | Check key is "guest_user_habits" |

---

## **Success Confirmation**

✅ **Test PASSES if**:
1. Migration UI appears after sign-in
2. Shows correct habit count
3. "Keep My Data" button works
4. All habits appear after migration
5. Completion history is preserved

❌ **Test FAILS if**:
1. No migration UI appears
2. Habits are lost after sign-in
3. Console shows "clearStaleGuestData()"
4. Migration can't be triggered

---

## **One-Liner Test**

```bash
# Quick build and run (from project directory)
cd /Users/chloe/Desktop/Habitto && \
xcodebuild -project Habitto.xcodeproj -scheme Habitto \
-destination 'platform=iOS Simulator,name=iPhone 15' \
clean build | grep -E "BUILD SUCCEEDED|BUILD FAILED"
```

If build succeeds, install and test manually as above.

---

**Estimated Time**: 5 minutes total  
**Result**: Clear pass/fail confirmation of guest migration fix

