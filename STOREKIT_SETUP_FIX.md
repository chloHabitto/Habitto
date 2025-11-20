# StoreKit Configuration Fix

## Problem
The StoreKit configuration file exists but isn't being loaded, causing "Product not found" errors when trying to purchase subscriptions.

## Solution

### Step 1: Add StoreKit File to Xcode Project

1. Open `Habitto.xcodeproj` in Xcode
2. In the Project Navigator (left sidebar), right-click on the project root (the blue "Habitto" icon)
3. Select **"Add Files to Habitto..."**
4. Navigate to and select `HabittoSubscriptions.storekit` (it's in the project root directory)
5. **IMPORTANT**: Make sure these options are checked:
   - ✅ "Copy items if needed" (should be unchecked since file is already in project root)
   - ✅ "Create groups" (not "Create folder references")
   - ✅ Add to target: **Habitto** (your main app target)
6. Click **"Add"**

### Step 2: Verify Scheme Configuration

The scheme has already been updated with the correct path. To verify:

1. In Xcode, go to **Product → Scheme → Edit Scheme...**
2. Select **"Run"** in the left sidebar
3. Go to the **"Options"** tab
4. Under **"StoreKit Configuration"**, you should see:
   - **StoreKit Configuration File**: `HabittoSubscriptions.storekit`
   
   If it's not there or shows an error:
   - Click the dropdown and select `HabittoSubscriptions.storekit`
   - Or click the folder icon and navigate to the file

### Step 3: Clean and Rebuild

1. In Xcode, go to **Product → Clean Build Folder** (Shift+Cmd+K)
2. Close Xcode completely
3. Reopen the project
4. Build and run the app (Cmd+R)

### Step 4: Test

1. Run the app on a simulator or device
2. Try to purchase a subscription
3. The products should now be found and purchasable

## Verification

After following these steps, when you run the app and try to purchase, you should see in the console:
```
✅ SubscriptionManager: Product found: Lifetime Access - €24.99
```

Instead of:
```
❌ SubscriptionManager: Product not found in StoreKit
```

## Troubleshooting

If products are still not found:

1. **Check file location**: Make sure `HabittoSubscriptions.storekit` is in the project root (same directory as `Habitto.xcodeproj`)

2. **Check scheme**: Verify the scheme is using the correct file:
   - Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration

3. **Check target membership**: 
   - Select `HabittoSubscriptions.storekit` in Project Navigator
   - In File Inspector (right sidebar), check "Target Membership"
   - Make sure "Habitto" target is checked

4. **Restart Xcode**: Sometimes Xcode needs a full restart to recognize StoreKit files

5. **Check product IDs**: Verify the product IDs in `SubscriptionManager.swift` match those in `HabittoSubscriptions.storekit`:
   - `com.chloe-lee.Habitto.subscription.lifetime`
   - `com.chloe-lee.Habitto.subscription.annual`
   - `com.chloe-lee.Habitto.subscription.monthly`

