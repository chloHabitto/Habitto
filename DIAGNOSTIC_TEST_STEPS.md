# 🔍 DIAGNOSTIC TEST - EXACT STEPS

Please follow these steps **exactly** and share the console output:

## Step 1: Clean Build
```bash
# In Xcode:
Product → Clean Build Folder (Cmd+Shift+K)
Product → Build (Cmd+B)
Product → Run (Cmd+R)
```

## Step 2: Initial State Check
```
1. App launches
2. Look for these lines in console:
   🏪 STORE_INSTANCE XPManager created: ObjectIdentifier(0x...)
   🟢 HomeTabView re-render | xp: X | instance: ObjectIdentifier(0x...)
   
📋 Copy and paste BOTH lines here
```

## Step 3: Complete All Habits
```
1. Go to Home tab
2. Complete ALL habits for today
3. Look for console output:
   🔍 XP_SET totalXP:XX completedDays:X delta:XX
   
📋 Copy and paste this line here
```

## Step 4: Check Home Tab ObjectIdentifier
```
1. Still on Home tab
2. Look for the MOST RECENT line:
   🟢 HomeTabView re-render | xp: XX | instance: ObjectIdentifier(0x...)
   
📋 Copy and paste this line here
```

## Step 5: Switch to More Tab
```
1. Immediately tap More tab
2. Look for console output:
   🟣 MoreTabView re-render | xp: XX | instance: ObjectIdentifier(0x...)
   
📋 Copy and paste this line here
```

## Step 6: Check Visual Indicator
```
1. Look at the TOP of More tab screen
2. You should see a YELLOW box with red text
3. What does it say?
   - "🔎 XP Live: 0" or "🔎 XP Live: 50" or something else?
4. What color is the circle?
   - Green or Orange?
   
📋 Tell me: "XP Live: XX, Circle color: XXXX"
```

## Step 7: Check XP Display Below
```
1. Below the yellow diagnostic box, there's the normal XP display
2. What XP does it show?
   
📋 Tell me: "XPLevelDisplay shows: XX total XP"
```

---

## 🎯 What I Need From You

Please share:

1. **Console output** from steps 2, 3, 4, and 5 (copy-paste the exact lines)
2. **Visual indicator** reading from step 6
3. **XPLevelDisplay** reading from step 7

Specifically, I need to see:
- The **ObjectIdentifier** values (the `0x...` addresses)
- Whether they **match** between Home and More tabs
- What the **visual indicator** actually shows

This will tell me exactly what's wrong!

