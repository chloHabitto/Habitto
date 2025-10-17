# 🚀 Quick Test Guide - XP Duplication Fix

## ⚡ 30-Second Test

1. **Build & Run** in Xcode (Cmd+R)
2. **Complete all habits** for today
3. **Watch top-right debug badge** (green = good, red = broken)
4. **Switch tabs** Home → More → Home (10x)
5. **Check XP stays at 50** (not 100, 150, 200...)

---

## 🔍 What to Look For

### ✅ GOOD (Fixed)
```
Console:
✅ INITIAL_XP: Set to 50 (completedDays: 1)
🔍 XP_SET totalXP:50 completedDays:1 delta:+50
(No more XP_SET logs on tab switches)

Debug Badge:
completedDays: 1
totalXP: 50
expected: 50  ← GREEN
```

### ❌ BAD (Still Broken)
```
Console:
🔍 XP_SET totalXP:50 completedDays:1 delta:+50
🔍 XP_SET totalXP:100 completedDays:1 delta:+50  ← DUPLICATE!
🔍 XP_SET totalXP:150 completedDays:1 delta:+50  ← DUPLICATE!

Debug Badge:
completedDays: 1
totalXP: 150
expected: 50  ← RED (BROKEN!)
```

---

## 🐛 If Still Broken

**Paste the first "XP_SET" log that shows wrong delta:**
```
Example:
🔍 XP_SET totalXP:100 completedDays:1 delta:+50
```

And the line **before** it (shows where the call came from).

---

## 📞 Quick Diagnostics

```bash
# Check for ghost XP mutations
grep -rn "totalXP\s*+=" --include="*.swift"

# Check for old award calls
grep -rn "updateXPFromDailyAward" --include="*.swift" | grep -v "unavailable"

# Verify single XPManager instance (should appear ONCE)
grep "STORE_INSTANCE XPManager" console_output.txt
```

---

**Expected Result:** XP stays at 50 no matter how many times you switch tabs! 🎉

