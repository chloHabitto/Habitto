# StoreKit Diagnostic & Fix

## Current Problem
StoreKit returns 0 products even though configuration file exists.

## Critical Fix Steps

### Step 1: Verify Scheme Configuration in Xcode UI

**This MUST be done in Xcode, not by editing the file directly:**

1. **Open Xcode** with your Habitto project
2. **Product → Scheme → Edit Scheme...**
3. Select **"Run"** in left sidebar
4. Click **"Options"** tab
5. Scroll to **"StoreKit Configuration"**
6. **IMPORTANT**: The dropdown should show `HabittoSubscriptions.storekit`
   - If it shows "None" or is empty, click the dropdown
   - Select `HabittoSubscriptions.storekit`
   - If it's not in the list, click the folder icon (📁) and browse to select it
7. **Click "Close"** to save

### Step 2: Verify File Location

The StoreKit file MUST be in the project root (same level as `Habitto.xcodeproj`):
```
/Users/chloe/Desktop/Habitto/
  ├── Habitto.xcodeproj/
  └── HabittoSubscriptions.storekit  ← Must be here
```

### Step 3: Verify File is in Xcode Project

1. In Xcode Project Navigator, you should see `HabittoSubscriptions.storekit`
2. Select it
3. In File Inspector (right sidebar):
   - **Target Membership**: "Habitto" should be ✅ checked
   - **Location**: Should be "Relative to Group" or "Relative to Project"

### Step 4: Clean Everything

1. **Product → Clean Build Folder** (Shift+Cmd+K)
2. **Quit Xcode completely** (Cmd+Q)
3. **Quit Simulator** (if running)
4. **Reopen Xcode**
5. **Reopen the project**
6. **Build and Run** (Cmd+R)

### Step 5: Test with Enhanced Logging

I've added enhanced logging to `SubscriptionManager.swift`. When you try to purchase, you'll now see:

```
🔍 SubscriptionManager: Testing StoreKit - fetching all products...
🔍 SubscriptionManager: StoreKit test - found X total product(s)
```

**If it says "found 0 total product(s)"**, the StoreKit configuration is NOT being loaded.

## Common Issues & Solutions

### Issue: Still Getting 0 Products

**Solution 1: Check Simulator/Device**
- StoreKit testing requires iOS 15+ simulator or device
- Try a different simulator (iPhone 15 Pro, iOS 17+)
- Or test on a physical device

**Solution 2: Verify Scheme File Format**
After configuring in Xcode UI, the scheme file should have:
```xml
<StoreKitConfigurationFileReference
   identifier = "container:HabittoSubscriptions.storekit">
</StoreKitConfigurationFileReference>
```

NOT:
```xml
<StoreKitConfigurationFileReference
   identifier = "../../HabittoSubscriptions.storekit">
</StoreKitConfigurationFileReference>
```

If it shows the `../../` path, Xcode didn't properly register it. Reconfigure in Xcode UI.

**Solution 3: Check Xcode Version**
- StoreKit Configuration requires Xcode 13+
- Update Xcode if needed

**Solution 4: Recreate StoreKit File**
1. In Xcode: **File → New → File...**
2. Choose **"StoreKit Configuration File"**
3. Name it `HabittoSubscriptions.storekit`
4. Copy your products from the old file
5. Delete the old file
6. Configure the new file in the scheme

**Solution 5: Check Product IDs Match Exactly**
- In `SubscriptionManager.swift`: `com.chloe-lee.Habitto.subscription.lifetime`
- In `HabittoSubscriptions.storekit`: `"productID" : "com.chloe-lee.Habitto.subscription.lifetime"`
- They must match **exactly** (case-sensitive, no extra spaces)

## Expected Success Output

When working correctly, you should see:
```
🔍 SubscriptionManager: Testing StoreKit - fetching all products...
🔍 SubscriptionManager: StoreKit test - found 3 total product(s)
✅ SubscriptionManager: StoreKit is working! Available products:
   - com.chloe-lee.Habitto.subscription.lifetime: Lifetime Access (€24.99)
   - com.chloe-lee.Habitto.subscription.annual: Annual Premium (€12.99/year)
   - com.chloe-lee.Habitto.subscription.monthly: Monthly Premium (€1.99/month)
🔍 SubscriptionManager: Fetching specific product: com.chloe-lee.Habitto.subscription.lifetime...
🔍 SubscriptionManager: Fetched 1 product(s) for com.chloe-lee.Habitto.subscription.lifetime
✅ SubscriptionManager: Product found: Lifetime Access - €24.99
```

## If Nothing Works

1. **Check Console.app** for StoreKit errors:
   - Open Console.app on your Mac
   - Filter by "StoreKit" or your app name
   - Look for any errors

2. **Try a fresh simulator**:
   - Device → Erase All Content and Settings
   - Or create a new simulator

3. **Check if StoreKit Testing is enabled**:
   - In Xcode: Product → Scheme → Edit Scheme → Run → Options
   - "StoreKit Configuration" should NOT be "None"

4. **Verify the .storekit file is valid JSON**:
   - Open `HabittoSubscriptions.storekit` in a text editor
   - Verify it's valid JSON (no syntax errors)

