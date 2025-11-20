# StoreKit Configuration Troubleshooting

## Current Issue
Products are not being found: `Fetched 0 product(s)`

## Critical Steps (Must Do in Xcode UI)

According to [Apple's documentation](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode), you **MUST** configure StoreKit through Xcode's scheme editor:

### Step 1: Configure StoreKit in Scheme (REQUIRED)

1. **Open Xcode** with your Habitto project
2. **Open Scheme Editor**:
   - Click the scheme selector (next to the stop/play buttons) → **"Edit Scheme..."**
   - OR: **Product → Scheme → Edit Scheme...**

3. **Configure StoreKit**:
   - In the left sidebar, select **"Run"** (under "App")
   - Click the **"Options"** tab at the top
   - Scroll down to **"StoreKit Configuration"** section
   - Click the dropdown next to **"StoreKit Configuration File"**
   - **Select `HabittoSubscriptions.storekit`** from the list
   
   **If the file doesn't appear in the dropdown:**
   - Click the folder icon (📁) next to the dropdown
   - Navigate to your project root: `/Users/chloe/Desktop/Habitto/`
   - Select `HabittoSubscriptions.storekit`
   - Click "Open"

4. **Save**:
   - Click **"Close"** to save the scheme

### Step 2: Verify File is in Project

1. In Xcode Project Navigator, find `HabittoSubscriptions.storekit`
2. Select it
3. In File Inspector (right sidebar), check:
   - **Target Membership**: "Habitto" should be ✅ checked
   - **Location**: Should show "Relative to Group" or "Relative to Project"

### Step 3: Clean and Rebuild

1. **Clean Build Folder**: **Product → Clean Build Folder** (Shift+Cmd+K)
2. **Quit Xcode completely** (Cmd+Q)
3. **Reopen Xcode** and the project
4. **Build and Run** (Cmd+R)

### Step 4: Test

1. Run the app on a **simulator or device**
2. Try to purchase a subscription
3. Check console for:
   ```
   ✅ SubscriptionManager: Product found: Lifetime Access - €24.99
   ```

## Common Issues

### Issue: "Fetched 0 product(s)"

**Causes:**
- StoreKit configuration not set in scheme
- File not properly added to project
- Running wrong scheme
- Need to clean/rebuild

**Solutions:**
1. ✅ Verify scheme configuration (Step 1 above)
2. ✅ Clean build folder and restart Xcode
3. ✅ Make sure you're running the "Habitto" scheme (not a test scheme)
4. ✅ Check file is in project with correct target membership

### Issue: File not in dropdown

**Solution:**
- Use the folder icon to browse and select the file manually
- Make sure the file is in the project root directory
- Verify the file has `.storekit` extension (not `.json`)

### Issue: Still not working after configuration

**Additional checks:**
1. **Check simulator/device**:
   - StoreKit testing works on iOS 15+ simulators
   - Try a physical device if simulator fails

2. **Verify product IDs match**:
   - In `SubscriptionManager.swift`: `com.chloe-lee.Habitto.subscription.lifetime`
   - In `HabittoSubscriptions.storekit`: `"productID" : "com.chloe-lee.Habitto.subscription.lifetime"`
   - They must match **exactly** (case-sensitive)

3. **Check Xcode version**:
   - StoreKit Configuration requires Xcode 13+
   - Update Xcode if needed

4. **Restart everything**:
   - Quit Xcode
   - Quit Simulator
   - Restart both
   - Try again

## Verification Checklist

- [ ] StoreKit file is in Xcode project
- [ ] File has Habitto target membership
- [ ] Scheme is configured with StoreKit file (Options tab)
- [ ] Clean build folder completed
- [ ] Xcode restarted
- [ ] App rebuilt and run
- [ ] Product IDs match exactly
- [ ] Testing on iOS 15+ simulator/device

## Expected Console Output (Success)

When working correctly, you should see:
```
🛒 SubscriptionManager: Attempting to purchase: com.chloe-lee.Habitto.subscription.lifetime
🔍 SubscriptionManager: Fetching product from StoreKit...
🔍 SubscriptionManager: Fetched 1 product(s)  ← Should be 1, not 0!
✅ SubscriptionManager: Product found: Lifetime Access - €24.99
```

## Still Not Working?

If after all these steps it still doesn't work:

1. **Check the scheme file directly**:
   - Open: `Habitto.xcodeproj/xcshareddata/xcschemes/Habitto.xcscheme`
   - Look for `<StoreKitConfigurationFileReference>`
   - The identifier should reference the file correctly

2. **Try creating a new StoreKit file**:
   - File → New → File → StoreKit Configuration File
   - Copy your products from the old file
   - Configure the new file in the scheme

3. **Check for multiple schemes**:
   - Make sure you're editing the correct scheme
   - Check if there are multiple schemes and configure all of them

