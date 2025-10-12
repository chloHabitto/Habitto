# CloudKit Setup Guide

## ✅ Code Changes Complete

The CloudKit code has been updated and is ready to use. This guide explains how to enable CloudKit in Xcode.

## 📋 Your CloudKit Configuration

- **Bundle Identifier**: `com.chloe-lee.Habitto`
- **iCloud Container**: `iCloud.com.chloe-lee.Habitto`
- **Database**: Private CloudKit Database
- **Custom Zone**: `HabittoHabitsZone`

## 🔧 Xcode Configuration Steps

### Step 1: Enable iCloud Capability

1. Open **Habitto.xcodeproj** in Xcode
2. Select your **Habitto** target in the left sidebar
3. Go to the **Signing & Capabilities** tab
4. Click **+ Capability** (top left)
5. Search for and add **iCloud**

### Step 2: Configure iCloud Services

Once iCloud capability is added, you'll see iCloud settings appear:

1. ✅ Check **CloudKit**
2. ✅ Check **CloudKit Documents** (optional, for iCloud Drive)
3. Under **Containers**, click the **+** button
4. Select **Use default container** (will create `iCloud.com.chloe-lee.Habitto`)
5. Ensure the container is checked/selected

### Step 3: Verify Entitlements

The entitlements file has already been updated with the correct configuration:

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.$(CFBundleIdentifier)</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
    <string>CloudDocuments</string>
</array>
```

### Step 4: Apple Developer Portal

**Important**: After enabling CloudKit in Xcode:

1. Xcode will automatically create the CloudKit container in your Apple Developer account
2. New containers can take **15-30 minutes** to become active
3. You can check status at: https://developer.apple.com/account/resources/identifiers/list
4. Navigate to **Identifiers → iCloud Containers**
5. Verify `iCloud.com.chloe-lee.Habitto` appears in the list

### Step 5: Test on Device/Simulator

**Simulator**:
- Go to **Settings → Apple ID** and sign in with your Apple ID
- Ensure iCloud Drive is enabled
- Run the app - CloudKit should now work

**Physical Device**:
- Sign in with your Apple ID in Settings
- Ensure iCloud Drive is enabled
- Run the app from Xcode

## 🔍 Verification

### Check CloudKit Status in App

Once the app is running, check the console for these messages:

✅ **Success**:
```
✅ CloudKitManager: CloudKit container initialized safely
✅ CloudKitManager: CloudKit is available and ready
```

⚠️ **Not Signed In**:
```
⚠️ CloudKitManager: iCloud not available (not signed in or disabled)
```

⚠️ **Guest Mode**:
```
ℹ️ CloudKitManager: Guest mode - using local storage only
```

### Manual Test Button

Use the CloudKit settings view in your app to:
1. Check CloudKit status
2. Manually trigger sync
3. View sync history
4. See error messages if configuration is incorrect

## 🎯 How It Works Now

### For Authenticated Users (Firebase Auth)

1. User signs in with **Google**, **Apple**, or **Email**
2. App checks if **iCloud is enabled** on device
3. If iCloud available → **CloudKit sync enabled**
4. Habits sync to private CloudKit database
5. Data persists even if app is deleted

### For Guest Users

1. User opens app without signing in
2. App detects **guest mode**
3. CloudKit sync is **disabled** (no Apple ID to associate data with)
4. Habits save to **local storage only** (SwiftData)
5. When user signs in → **CloudKit sync activates** and uploads local data

### Data Persistence Flow

```
Sign In → Check iCloud → Enable CloudKit → Sync Local Data → Cloud Backup Active
                ↓                    ↓
          Not Available        Guest Mode
                ↓                    ↓
         Local Only          Local Only
```

## 🚨 Troubleshooting

### "iCloud not available"
- Ensure you're signed into iCloud on the device
- Check Settings → Apple ID → iCloud → iCloud Drive is ON

### "CloudKit container not initialized"
- Wait 15-30 minutes after enabling CloudKit in Xcode
- Container creation isn't instant
- Check Apple Developer Portal to confirm container exists

### "User not authenticated for CloudKit"
- For Firebase users: This should work (we don't need Apple ID authentication)
- If error persists, sign out and sign in again

### "Guest mode - using local storage only"
- This is **expected behavior** for users who haven't signed in
- Prompt user to create account to enable cloud backup

## ⚙️ Advanced Configuration

### Custom Container (Optional)

If you want a different container name:

1. In **Xcode → Signing & Capabilities → iCloud**
2. Click **+** under Containers
3. Select **Specify custom containers**
4. Enter your custom container ID (must start with `iCloud.`)

### CloudKit Dashboard

Monitor your CloudKit usage:
1. Go to https://icloud.developer.apple.com/dashboard
2. Select your container: `iCloud.com.chloe-lee.Habitto`
3. View:
   - Record types (Habit, CompletionEvent)
   - Storage usage
   - Request counts
   - User activity

## 📊 Next Steps

After configuration:

1. ✅ **Test sync** - Create habits, delete app, reinstall, verify data returns
2. ✅ **Test guest → authenticated** - Start as guest, sign in, verify data uploads
3. ✅ **Test cross-device** - Sign in on two devices, verify sync works
4. ✅ **Monitor CloudKit Dashboard** - Check for errors or quota issues

## 💡 Benefits of This Setup

- ✅ **Free** (1GB storage + 10GB data transfer per user)
- ✅ **Private** (data stays in user's private iCloud)
- ✅ **Secure** (end-to-end encryption via Apple)
- ✅ **No server** (no backend infrastructure needed)
- ✅ **Automatic conflict resolution** (built-in via your CloudKit code)
- ✅ **Works offline** (syncs when connection returns)

## 🔒 Privacy & Security

- All data stored in **user's private iCloud account**
- You (the developer) cannot access user data
- Data automatically deleted if user deletes iCloud account
- Compliant with Apple's privacy guidelines
- No personal data sent to third-party servers

---

**Status**: ✅ Code ready, waiting for Xcode configuration
**Time to complete**: 5-10 minutes in Xcode + 15-30 minutes for container activation

