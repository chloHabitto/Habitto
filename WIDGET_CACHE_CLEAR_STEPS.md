# Widget Cache Clear Steps

## Problem
The widget works correctly in the gallery preview (shows correct streak with white text on black background), but the home screen shows a black/blank screen. This is caused by iOS caching an old widget snapshot from when the widget had bugs.

## Solution
Follow these steps to completely clear the widget cache and force iOS to use the new widget code:

---

## Step-by-Step Instructions

### 1. Remove all Habitto widgets from home screen
- Long press each Habitto widget on the home screen
- Tap **Remove Widget**
- Confirm removal
- Repeat for all Habitto widgets

### 2. Delete the Habitto app
- Long press the Habitto app icon
- Tap **Remove App** or **Delete App**
- Tap **Delete** to confirm
- This removes the app and all its cached data including widget snapshots

### 3. In Xcode - Clean everything

**Option A: Using Xcode UI**
- Open Xcode
- Go to **Product → Clean Build Folder** (or press `Cmd+Shift+K`)
- Wait for cleanup to complete

**Option B: Using Terminal**
```bash
# Delete DerivedData (contains cached build artifacts)
rm -rf ~/Library/Developer/Xcode/DerivedData/Habitto-*
```

**Recommended: Do both Option A and Option B**

### 4. Restart the iPhone (CRITICAL - clears widget cache)
This step is **essential** - iOS stores widget snapshots in system memory that persists until restart.

- Press and hold the **Side button** + **Volume down button** (or **Side button** + **Volume up button** on older iPhones)
- Wait for the "slide to power off" slider to appear
- Slide to power off
- Wait at least 10 seconds for the device to fully shut down
- Press and hold the **Side button** until the Apple logo appears
- Wait for the device to fully boot

### 5. Rebuild and install
- Open Xcode
- Select your device/simulator
- Build the project: **Product → Build** (or press `Cmd+B`)
- Run the app: **Product → Run** (or press `Cmd+R`)
- Wait for the app to install and launch

### 6. Add widget to home screen
- Long press on an empty area of the home screen
- Tap the **+** button in the top-left corner
- Search for **"Habitto"** in the widget gallery
- Select **"My Widget"** (the small size widget)
- Tap **Add Widget**
- Position it on your home screen
- Tap **Done**

---

## Expected Result

After completing these steps, the widget should display:
- ✅ **White text** showing the correct streak number (e.g., "2", "3", etc.)
- ✅ **"Streak Days"** label in white (slightly transparent)
- ✅ **Fire icon** in white at bottom right
- ✅ **Black background**

The widget will automatically update when the streak changes in the main app.

---

## Troubleshooting

If the widget still shows a black screen after following all steps:

1. **Verify the widget extension is included in the build:**
   - In Xcode, check that `HabittoWidget` target is included in the scheme
   - Go to **Product → Scheme → Edit Scheme**
   - Ensure `HabittoWidget` is checked under "Build"

2. **Check widget extension logs:**
   - In Xcode, go to **Window → Devices and Simulators**
   - Select your device
   - Click **View Device Logs**
   - Filter for "HabittoWidget"
   - Look for logs starting with "🔴" or "📱" to verify the widget is running

3. **Try a different widget size:**
   - Remove the widget
   - Add it again, but try a different size if available

4. **Verify App Group is configured:**
   - Check that both the main app and widget extension have the same App Group ID: `group.com.habitto.widget`
   - Verify in **Signing & Capabilities** for both targets

---

## Technical Notes

- Widget snapshots are cached by iOS WidgetKit and persist across app updates
- The widget cache is stored in system memory and is cleared on device restart
- Gallery preview always shows fresh snapshots (not cached)
- Home screen widgets use cached snapshots for performance
- `WidgetCenter.shared.reloadAllTimelines()` requests a refresh but doesn't guarantee immediate update if iOS has a cached snapshot

---

## Prevention

To avoid this issue in the future:
- Test widget changes in the gallery preview first (always shows fresh code)
- If making significant widget changes, consider incrementing the widget version
- After major widget updates, inform users they may need to remove and re-add the widget
