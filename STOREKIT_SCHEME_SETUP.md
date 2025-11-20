# StoreKit Scheme Configuration

Since the `HabittoSubscriptions.storekit` file is already in your Xcode project with the Habitto target, you just need to configure it in the scheme.

## Steps to Configure StoreKit in Xcode Scheme

1. **Open Xcode** with your Habitto project

2. **Open Scheme Editor**:
   - Click on the scheme selector (next to the stop/play buttons at the top)
   - Select **"Edit Scheme..."**
   - OR go to: **Product → Scheme → Edit Scheme...**

3. **Configure StoreKit**:
   - In the left sidebar, select **"Run"** (under "App" section)
   - Click on the **"Options"** tab at the top
   - Scroll down to find **"StoreKit Configuration"** section
   - Click the dropdown next to **"StoreKit Configuration File"**
   - Select **"HabittoSubscriptions.storekit"** from the list
   
   If you don't see it in the dropdown:
   - Click the folder icon (📁) next to the dropdown
   - Navigate to your project root and select `HabittoSubscriptions.storekit`
   - Click "Open"

4. **Save the Scheme**:
   - Click **"Close"** to save the scheme

5. **Clean and Rebuild**:
   - **Product → Clean Build Folder** (Shift+Cmd+K)
   - **Product → Build** (Cmd+B)
   - Run the app (Cmd+R)

## Verify It's Working

After configuring and running the app, when you try to purchase, you should see in the console:

```
✅ SubscriptionManager: Product found: Lifetime Access - €24.99
```

Instead of:
```
❌ SubscriptionManager: Product not found in StoreKit
```

## Troubleshooting

If products are still not found after configuring the scheme:

1. **Verify the file is in the project**:
   - In Xcode Project Navigator, you should see `HabittoSubscriptions.storekit`
   - Select it and check the File Inspector (right sidebar)
   - Under "Target Membership", make sure **"Habitto"** is checked

2. **Check the scheme again**:
   - Product → Scheme → Edit Scheme → Run → Options
   - Verify "StoreKit Configuration File" shows `HabittoSubscriptions.storekit`

3. **Restart Xcode completely**:
   - Quit Xcode (Cmd+Q)
   - Reopen the project
   - Try again

4. **Check product IDs match**:
   - The product IDs in `SubscriptionManager.swift` must exactly match those in `HabittoSubscriptions.storekit`:
     - `com.chloe-lee.Habitto.subscription.lifetime`
     - `com.chloe-lee.Habitto.subscription.annual`
     - `com.chloe-lee.Habitto.subscription.monthly`

5. **Test on a device/simulator**:
   - Make sure you're testing on an actual iOS Simulator or device
   - StoreKit testing works best on simulators with iOS 15+

