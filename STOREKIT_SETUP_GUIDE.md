# StoreKit Configuration Setup Guide

This guide explains how to use the StoreKit configuration file to test subscriptions in your app.

## 📁 Files Created

- **`HabittoSubscriptions.storekit`** - StoreKit configuration file with your subscription products

## 🚀 How to Use the StoreKit Configuration File

### Step 1: Add the File to Your Xcode Project

1. Open your project in Xcode
2. Right-click on your project in the navigator
3. Select "Add Files to Habitto..."
4. Select `HabittoSubscriptions.storekit`
5. Make sure "Copy items if needed" is checked
6. Click "Add"

### Step 2: Configure Your Scheme

1. In Xcode, go to **Product → Scheme → Edit Scheme...**
2. Select **Run** in the left sidebar
3. Go to the **Options** tab
4. Under **StoreKit Configuration**, select **HabittoSubscriptions.storekit**
5. Click **Close**

### Step 3: Test Subscriptions

When you run the app with the StoreKit configuration:

1. **Free Version (Default)**
   - The app starts as a free user
   - You can create up to 5 habits
   - Premium features are locked

2. **Test Purchases**
   - Navigate to the subscription screen
   - Tap on any subscription option (Lifetime, Annual, or Monthly)
   - The purchase will complete instantly (no real payment)
   - Premium features will unlock immediately

3. **Test Subscription Renewal**
   - The StoreKit config is set to renew subscriptions **hourly** (for fast testing)
   - You can see subscription status changes quickly
   - To change renewal rate: Edit the `.storekit` file → `settings._subscriptionRenewalRate`

### Step 4: Test Different Scenarios

#### Test Free User Experience:
- Don't make any purchases
- Try creating more than 5 habits (should be blocked)
- Verify premium features are locked

#### Test Premium User Experience:
- Purchase any subscription (Lifetime, Annual, or Monthly)
- Verify you can create unlimited habits
- Check that all premium features are unlocked
- Test "Restore Purchase" functionality

#### Test Subscription Expiration:
- Purchase a subscription
- Wait for it to expire (or manually expire in StoreKit testing)
- Verify the app correctly detects the expired subscription

## 🔧 Product IDs

The following product IDs are configured:

- **Lifetime**: `com.chloe-lee.Habitto.subscription.lifetime`
- **Annual**: `com.chloe-lee.Habitto.subscription.annual`
- **Monthly**: `com.chloe-lee.Habitto.subscription.monthly`

These are defined in `SubscriptionManager.ProductID` and used throughout the app.

## 📱 Testing in Archived Builds

### For TestFlight:
1. The StoreKit configuration file **only works in development builds**
2. For TestFlight, you'll need to use **sandbox test accounts**:
   - Create sandbox accounts in App Store Connect
   - Sign in with a sandbox account on your device
   - Make test purchases in the sandbox environment

### For App Store:
- Real purchases only (no StoreKit config)
- Make sure your products are configured in App Store Connect

## 🛠️ Troubleshooting

### Products Not Loading?
- Make sure the `.storekit` file is added to your Xcode project
- Verify the scheme is configured to use the StoreKit file
- Check that product IDs match exactly (case-sensitive)

### Purchases Not Working?
- Ensure you're running the app (not just building)
- Check Xcode console for StoreKit errors
- Verify the StoreKit configuration file is selected in scheme options

### Subscription Status Not Updating?
- The app checks subscription status on launch
- Use "Restore Purchase" to manually refresh status
- Check console logs for subscription status messages

## 📝 Next Steps

1. **Update SubscriptionView** to use the new `purchase()` method from `SubscriptionManager`
2. **Test thoroughly** with the StoreKit configuration
3. **Configure products in App Store Connect** before submitting to TestFlight/App Store
4. **Remove or comment out** any debug subscription toggles before release

## 🔗 Resources

- [Apple StoreKit Testing Documentation](https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_sandbox)
- [StoreKit Configuration File Format](https://developer.apple.com/documentation/storekit/in-app_purchase/creating_a_storekit_configuration_file)

