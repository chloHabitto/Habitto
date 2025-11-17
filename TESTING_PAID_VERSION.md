# How to Test the Paid Version of Habitto

## Quick Setup (5 minutes)

### Step 1: Add StoreKit File to Xcode
1. Open your project in Xcode
2. In the Project Navigator, right-click on your project folder
3. Select **"Add Files to Habitto..."**
4. Navigate to and select **`HabittoSubscriptions.storekit`**
5. Make sure **"Copy items if needed"** is checked
6. Click **"Add"**

### Step 2: Configure Your Scheme
1. In Xcode menu: **Product → Scheme → Edit Scheme...**
2. Select **Run** in the left sidebar
3. Click the **Options** tab
4. Under **StoreKit Configuration**, select **HabittoSubscriptions.storekit**
5. Click **Close**

### Step 3: Run the App
Press **⌘R** (or click Run) to launch the app

---

## Testing the Paid Version

### Method 1: Purchase a Subscription (Recommended)

1. **Open the Subscription Screen**
   - Navigate to the **More** tab
   - Tap on the subscription banner or find the subscription option
   - Or go directly to the subscription view

2. **Select a Plan**
   - Choose **Lifetime**, **Annual**, or **Monthly**
   - Tap **"See all plans"** if needed

3. **Make a Test Purchase**
   - Select your preferred plan (Lifetime, Annual, or Monthly)
   - Tap **"Continue"**
   - The purchase will complete **instantly** (no real payment!)
   - You'll see a success message

4. **Verify Premium Status**
   - The subscription screen should dismiss automatically
   - Check the console for: `✅ SubscriptionManager: Premium status enabled`
   - Try creating more than 5 habits (should work now!)
   - Premium features should be unlocked

### Method 2: Restore Purchase

If you've already made a test purchase:

1. Go to the subscription screen
2. Tap **"Restore purchase"**
3. Your premium status will be restored
4. Premium features will unlock

---

## What to Test

### ✅ Free Version (Before Purchase)
- [ ] Can only create up to 5 habits
- [ ] Premium features are locked (Progress Insights, Vacation Mode)
- [ ] Subscription prompts appear when hitting limits

### ✅ Paid Version (After Purchase)
- [ ] Can create unlimited habits
- [ ] Progress Insights are accessible
- [ ] Vacation Mode is available
- [ ] All premium features work correctly
- [ ] Subscription status persists after app restart

---

## Quick Test Scenarios

### Test 1: Fresh Install (Free User)
1. Delete the app (or reset data)
2. Launch the app
3. Try creating 6 habits
4. Should be blocked at 5 habits
5. Should see subscription prompt

### Test 2: Purchase Lifetime
1. Go to subscription screen
2. Select **Lifetime Access**
3. Tap **Continue**
4. Verify premium unlocks immediately
5. Create more than 5 habits (should work)

### Test 3: Purchase Monthly Subscription
1. Go to subscription screen
2. Select **Monthly** plan
3. Tap **Continue**
4. Verify premium unlocks
5. Wait for subscription to renew (hourly in test mode)
6. Premium should remain active

### Test 4: Restore Purchase
1. Make a purchase
2. Close the app completely
3. Reopen the app
4. Go to subscription screen
5. Tap **"Restore purchase"**
6. Premium status should be restored

---

## Troubleshooting

### ❌ "Product not found" Error
**Solution:**
- Make sure the `.storekit` file is added to your Xcode project
- Verify the scheme is configured to use the StoreKit file
- Check that product IDs match exactly (they're case-sensitive)

### ❌ Purchase Not Working
**Solution:**
- Ensure you're **running** the app (not just building)
- Check Xcode console for StoreKit errors
- Verify StoreKit configuration is selected in scheme options
- Try restarting Xcode

### ❌ Premium Status Not Updating
**Solution:**
- Check console logs for subscription status messages
- Use "Restore Purchase" to manually refresh
- The app checks subscription status on launch
- Make sure you're using the StoreKit config (not real purchases)

### ❌ Can't See Subscription Screen
**Solution:**
- Navigate to **More** tab
- Look for subscription banner (if you're a free user)
- Or add a direct navigation link to `SubscriptionView()`

---

## Console Messages to Look For

When testing, watch for these console messages:

**Successful Purchase:**
```
🛒 SubscriptionManager: Attempting to purchase: com.chloe-lee.Habitto.subscription.lifetime
✅ SubscriptionManager: Purchase successful for com.chloe-lee.Habitto.subscription.lifetime
✅ SubscriptionManager: Found active subscription/product: com.chloe-lee.Habitto.subscription.lifetime
✅ SubscriptionManager: Premium status enabled
```

**Free User:**
```
ℹ️ SubscriptionManager: No active subscription found - free user
```

**Restore:**
```
🔄 SubscriptionManager: Starting restore purchases...
✅ SubscriptionManager: Restore successful - active subscription found
```

---

## Testing Subscription Renewal

The StoreKit config is set to renew subscriptions **hourly** for fast testing:

1. Purchase a monthly or annual subscription
2. Wait 1 hour (or adjust renewal rate in `.storekit` file)
3. Subscription should auto-renew
4. Premium status should remain active

To change renewal speed:
- Edit `HabittoSubscriptions.storekit`
- Find `"subscriptionRenewalRate": "hourly"`
- Change to `"daily"` or `"monthly"` if needed

---

## Next Steps

Once testing is complete:
1. ✅ Test all premium features work
2. ✅ Test subscription restoration
3. ✅ Test subscription expiration (if needed)
4. ✅ Configure products in App Store Connect for TestFlight
5. ✅ Remove any debug toggles before release

---

## Notes

- **StoreKit config only works in development builds**
- For TestFlight, use sandbox test accounts
- For App Store, real purchases only
- Test purchases don't cost money
- Subscriptions renew hourly in test mode (for fast testing)

