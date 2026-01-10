# Target Membership Fix Guide

## Build Errors Fixed

✅ **Fixed in code:**
- Renamed `HabitRowView` → `WidgetHabitRowView` in `MediumWidgetView.swift` to avoid conflict with main app

## Xcode Target Membership Fixes Required

You need to manually fix target membership in Xcode. Follow these steps:

### 1. Fix @main Attribute Conflict

**Problem:** Both `HabittoApp.swift` and `HabittoWidgetBundle.swift` are in the Habitto target.

**Fix:**
1. Select `HabittoWidget/Sources/HabittoWidgetBundle.swift` in Xcode
2. Open File Inspector (right panel, or press ⌘⌥1)
3. Under **Target Membership**, **UNCHECK** `Habitto`
4. Ensure only `HabittoWidgetExtension` is checked ✅

### 2. Fix Color Extension Conflict

**Problem:** Both `ColorSystem.swift` and `Color+Hex.swift` define `Color(hex:)` and are in the same target.

**Fix:**

**For Core/Utils/Design/ColorSystem.swift:**
1. Select the file in Xcode
2. File Inspector → Target Membership
3. **CHECK** `Habitto` only
4. **UNCHECK** `HabittoWidgetExtension`

**For HabittoWidget/Sources/Extensions/Color+Hex.swift:**
1. Select the file in Xcode
2. File Inspector → Target Membership
3. **CHECK** `HabittoWidgetExtension` only
4. **UNCHECK** `Habitto`

### 3. Verify All Widget Files Are ONLY in Widget Extension

**Check each of these files** and ensure they are **ONLY** in `HabittoWidgetExtension` target:

```
HabittoWidget/
├── Sources/
│   ├── HabittoWidgetBundle.swift          ← ONLY HabittoWidgetExtension
│   ├── HabittoWidget.swift                ← ONLY HabittoWidgetExtension
│   ├── Extensions/
│   │   └── Color+Hex.swift                ← ONLY HabittoWidgetExtension
│   ├── Provider/
│   │   └── HabitWidgetProvider.swift      ← ONLY HabittoWidgetExtension
│   ├── Views/
│   │   ├── HabitWidgetEntryView.swift     ← ONLY HabittoWidgetExtension
│   │   ├── SmallWidgetView.swift          ← ONLY HabittoWidgetExtension
│   │   └── MediumWidgetView.swift         ← ONLY HabittoWidgetExtension
│   └── Models/
│       └── HabitWidgetEntry.swift         ← ONLY HabittoWidgetExtension
├── Assets.xcassets/                       ← ONLY HabittoWidgetExtension
└── Info.plist                             ← ONLY HabittoWidgetExtension
```

**Action:** Select each file → File Inspector → Target Membership → Uncheck `Habitto`, Check `HabittoWidgetExtension`

### 4. Verify Main App Files Are ONLY in Habitto Target

**Check these key files** and ensure they are **ONLY** in `Habitto` target:

```
App/
└── HabittoApp.swift                       ← ONLY Habitto

Core/
└── [ALL FILES]                            ← ONLY Habitto
    └── Utils/Design/ColorSystem.swift     ← ONLY Habitto (contains Color(hex:))

Views/
└── [ALL FILES]                            ← ONLY Habitto
    └── Components/HabitsListPopup.swift   ← ONLY Habitto (contains HabitRowView)

Features/
└── [ALL FILES]                            ← ONLY Habitto
```

**Action:** Select each file/directory → File Inspector → Target Membership → Uncheck `HabittoWidgetExtension`, Check `Habitto`

### 5. Verify Shared Files Are in BOTH Targets

**These files MUST be in BOTH targets:**

```
Shared/
├── Models/
│   └── WidgetHabitData.swift              ← BOTH Habitto ✅ AND HabittoWidgetExtension ✅
└── Services/
    └── WidgetDataService.swift            ← BOTH Habitto ✅ AND HabittoWidgetExtension ✅
```

**Action:** Select each file → File Inspector → Target Membership → Check BOTH `Habitto` AND `HabittoWidgetExtension`

**Also ensure Core/Services/WidgetUpdateService.swift:**
- **ONLY** in `Habitto` target (NOT in HabittoWidgetExtension)

### 6. Bulk Fix Method (Recommended)

**For Widget Extension files:**
1. Select `HabittoWidget/` folder in Project Navigator
2. Select all files in the folder (⌘A)
3. File Inspector → Target Membership
4. **UNCHECK** `Habitto`
5. **CHECK** `HabittoWidgetExtension`
6. Then manually fix the Shared/ files to be in BOTH targets

**For Main App files:**
1. Select `App/`, `Core/`, `Views/`, `Features/` folders
2. File Inspector → Target Membership
3. **CHECK** `Habitto`
4. **UNCHECK** `HabittoWidgetExtension`

## Verification Checklist

After fixing, verify:

- [ ] `HabittoWidgetBundle.swift` is ONLY in HabittoWidgetExtension
- [ ] `HabittoApp.swift` is ONLY in Habitto
- [ ] `ColorSystem.swift` is ONLY in Habitto
- [ ] `Color+Hex.swift` is ONLY in HabittoWidgetExtension
- [ ] `WidgetHabitData.swift` is in BOTH targets
- [ ] `WidgetDataService.swift` is in BOTH targets
- [ ] `WidgetUpdateService.swift` is ONLY in Habitto
- [ ] All other widget files are ONLY in HabittoWidgetExtension
- [ ] All main app files are ONLY in Habitto

## Quick Verification Command

After fixing in Xcode, clean and build:

```
Product → Clean Build Folder (Shift + ⌘ + K)
Product → Build (⌘ + B)
```

If errors persist, use this command to find files with wrong targets:

1. In Xcode, go to Build Settings
2. Search for "Other Swift Flags"
3. Add `-diagnostics-editor-mode` temporarily to see detailed errors

## Common Mistakes to Avoid

❌ **Don't add widget files to main app target**
❌ **Don't add main app files to widget target** (except Shared/)
❌ **Don't forget to add Shared/ files to BOTH targets**
❌ **Don't leave @main in multiple files in same target**

✅ **Do isolate widget extension completely**
✅ **Do share only lightweight Codable models via Shared/**
✅ **Do use separate extensions for each target when needed**
