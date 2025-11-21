# CloudKit Quick Start - Code Changes

## Quick Reference: Exact Code Changes

### Change 1: Update Entitlements File

**File:** `Habitto.entitlements`

**Remove the comment markers and uncomment:**

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.$(CFBundleIdentifier)</string>
</array>
<key>com.apple.developer.ubiquity-container-identifiers</key>
<array>
    <string>iCloud.$(CFBundleIdentifier)</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
    <string>CloudDocuments</string>
</array>
```

---

### Change 2: Update SwiftDataContainer

**File:** `Core/Data/SwiftData/SwiftDataContainer.swift`

**Line 224: Change this:**
```swift
cloudKitDatabase: .none)  // Disable automatic CloudKit sync
```

**To this:**
```swift
cloudKitDatabase: .automatic)  // Enable automatic CloudKit sync
```

**Also update the comment above (line 218-220):**
```swift
// ✅ CLOUDKIT SYNC: Enable automatic CloudKit sync
// This enables seamless cross-device sync and data protection
// Works automatically with existing iCloud account (no sign-in UI)
let modelConfiguration = ModelConfiguration(
  schema: schema,
  isStoredInMemoryOnly: false,
  cloudKitDatabase: .automatic)  // Enable CloudKit sync

logger.info("🔧 SwiftData: Creating ModelContainer with CloudKit sync enabled...")
logger.info("🔧 SwiftData: CloudKit sync will work automatically if iCloud is enabled")
logger.info("🔧 SwiftData: Falls back to local storage if iCloud is unavailable")
```

---

### Change 3: Xcode Capabilities

**In Xcode:**
1. Select **Habitto** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability** → **iCloud**
4. Check **CloudKit** checkbox
5. Add container: `iCloud.com.chloe-lee.Habitto`
6. Add **Background Modes** capability
7. Check **Remote notifications**

---

### Change 4: Deploy CloudKit Schema

**Before release:**
1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
2. Select your container
3. Go to **Schema** tab
4. Click **Deploy Schema Changes**
5. Wait for deployment (5-30 minutes)

---

## That's It!

**Total code changes:** 2 files
**Time to implement:** 30 minutes (code) + testing
**User impact:** Zero (completely invisible)

---

## Testing Checklist

- [ ] App launches with CloudKit enabled
- [ ] Existing data preserved
- [ ] Test on 2 devices (sync works)
- [ ] Test offline (works, syncs when online)
- [ ] Test iCloud disabled (graceful fallback)
- [ ] Schema deployed to production

---

## Important: Unique Constraints

**⚠️ Your models have `@Attribute(.unique)` constraints:**
- `HabitData.id`
- `CompletionRecord.userIdHabitIdDateKey`

**CloudKit Limitation:**
- CloudKit doesn't enforce unique constraints at schema level
- SwiftData may handle this gracefully, but **test thoroughly**
- If duplicates appear, you may need to remove `.unique` and handle in code

**Testing:**
- Test creating habits with same ID
- Test creating duplicate completions
- Monitor for duplicate records in CloudKit

---

## Common Issues

### Issue: "CloudKit container not found"
**Solution:** Wait 30 minutes after creating container, or check container ID matches

### Issue: "Schema mismatch"
**Solution:** Deploy schema to production in CloudKit Dashboard

### Issue: "Sync not working"
**Solution:** Check iCloud is enabled, check internet connection

### Issue: "Duplicate records in CloudKit"
**Solution:** Remove `@Attribute(.unique)` and handle uniqueness in application logic

---

**For detailed information, see `CLOUDKIT_IMPLEMENTATION_GUIDE.md`**

