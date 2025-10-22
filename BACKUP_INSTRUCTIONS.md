# 🛡️ STAGE 0: BACKUP INSTRUCTIONS

**Date:** October 22, 2025  
**Purpose:** Create complete backup before any code changes  
**Time Required:** 10-15 minutes

---

## 📍 FILES TO BACKUP

### 1. SwiftData Database
**Location:**
```
~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/data/Containers/Data/Application/[APP_ID]/Library/Application Support/
```

**For Physical Device:**
```
Access via Xcode → Devices & Simulators → Download Container
```

**What to backup:**
- `default.store` (SwiftData database file)
- `default.store-shm` (shared memory file)
- `default.store-wal` (write-ahead log)

### 2. UserDefaults
**Location:**
```
~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/data/Containers/Data/Application/[APP_ID]/Library/Preferences/
```

**What to backup:**
- `com.habitto.app.plist` (or your bundle identifier)

### 3. Documents Directory (if any local files)
**Location:**
```
~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/data/Containers/Data/Application/[APP_ID]/Documents/
```

### 4. Source Code
**What to backup:**
- Current git commit hash
- Any uncommitted changes

---

## 🚀 AUTOMATED BACKUP SCRIPT

I've created a script that will backup everything automatically.

### Option A: Using Xcode Simulator (Easiest)

**Step 1:** Copy this script to a file called `backup_habitto_data.sh`

```bash
#!/bin/bash

# Habitto Data Backup Script
# Run this from your Desktop (same level as Habitto folder)

BACKUP_DIR="$HOME/Desktop/Habitto_Backup_$(date +%Y%m%d_%H%M%S)"
BUNDLE_ID="com.habitto.app"  # Replace with your actual bundle ID

echo "🛡️  Creating Habitto Data Backup..."
echo "📁 Backup location: $BACKUP_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Find the most recent simulator device
DEVICE_PATH=$(find ~/Library/Developer/CoreSimulator/Devices -name "*.store" | grep -i "habitto\|default" | head -1)

if [ -z "$DEVICE_PATH" ]; then
    echo "❌ Error: Could not find SwiftData database"
    echo "💡 Tip: Run the app once in simulator first"
    exit 1
fi

# Get the container path (go up to Application Support)
CONTAINER_PATH=$(dirname "$DEVICE_PATH")
APP_PATH=$(echo "$CONTAINER_PATH" | sed 's|/Library/Application Support.*||')

echo "📍 Found app container: $APP_PATH"

# Backup SwiftData database
echo "📦 Backing up SwiftData database..."
cp -R "$CONTAINER_PATH" "$BACKUP_DIR/SwiftData/"
echo "✅ SwiftData backed up"

# Backup UserDefaults
echo "📦 Backing up UserDefaults..."
PREFS_PATH="$APP_PATH/Library/Preferences"
if [ -d "$PREFS_PATH" ]; then
    cp -R "$PREFS_PATH" "$BACKUP_DIR/Preferences/"
    echo "✅ UserDefaults backed up"
else
    echo "⚠️  No UserDefaults found (this is OK if app is fresh)"
fi

# Backup Documents directory
echo "📦 Backing up Documents..."
DOCS_PATH="$APP_PATH/Documents"
if [ -d "$DOCS_PATH" ]; then
    cp -R "$DOCS_PATH" "$BACKUP_DIR/Documents/"
    echo "✅ Documents backed up"
else
    echo "⚠️  No Documents found (this is OK)"
fi

# Export data to JSON for human readability
echo "📦 Creating JSON export..."
# This will be done via app's export function

# Save git commit info
cd "$HOME/Desktop/Habitto"
git rev-parse HEAD > "$BACKUP_DIR/git_commit.txt"
git status > "$BACKUP_DIR/git_status.txt"
echo "✅ Git info saved"

# Create backup manifest
cat > "$BACKUP_DIR/MANIFEST.txt" << EOF
Habitto Backup Manifest
Created: $(date)
Backup Location: $BACKUP_DIR

Contents:
- SwiftData database files
- UserDefaults preferences
- Documents directory
- Git commit hash

To Restore:
See RESTORE_INSTRUCTIONS.txt in this backup folder
EOF

echo ""
echo "✅ BACKUP COMPLETE!"
echo "📁 Location: $BACKUP_DIR"
echo ""
echo "⚠️  IMPORTANT: Verify backup before proceeding!"
echo "   Run: ls -lah '$BACKUP_DIR/SwiftData/'"
echo ""

# Verify backup
STORE_FILE="$BACKUP_DIR/SwiftData/default.store"
if [ -f "$STORE_FILE" ]; then
    STORE_SIZE=$(ls -lh "$STORE_FILE" | awk '{print $5}')
    echo "✅ Verification: Database file found ($STORE_SIZE)"
    echo ""
    echo "🎯 Reply to Cursor: BACKUP COMPLETE - PROCEED TO STAGE 1"
else
    echo "❌ Verification FAILED: Database file not found!"
    echo "   Do NOT proceed with code changes!"
fi
```

**Step 2:** Make the script executable
```bash
chmod +x backup_habitto_data.sh
```

**Step 3:** Run the script
```bash
./backup_habitto_data.sh
```

---

### Option B: Manual Backup (If Script Fails)

**Step 1:** Find your app's data directory

Open Terminal and run:
```bash
# Find SwiftData database
find ~/Library/Developer/CoreSimulator/Devices -name "*.store" | grep -i "habitto\|default"
```

Copy the path that appears (something like):
```
/Users/chloe/Library/Developer/CoreSimulator/Devices/[UUID]/data/Containers/Data/Application/[UUID]/Library/Application Support/default.store
```

**Step 2:** Copy the entire Application Support directory
```bash
# Replace [PATH_FROM_STEP1] with the path you found
# Remove "/default.store" from the end - we want the directory
cp -R "/Users/chloe/Library/Developer/CoreSimulator/Devices/[UUID]/data/Containers/Data/Application/[UUID]/Library/Application Support" ~/Desktop/Habitto_Backup_Manual/
```

**Step 3:** Verify files copied
```bash
ls -lah ~/Desktop/Habitto_Backup_Manual/
```

You should see:
- `default.store`
- `default.store-shm`
- `default.store-wal`

**Step 4:** Backup UserDefaults
```bash
# Use same container path but go to Preferences
cp -R "/Users/chloe/Library/Developer/CoreSimulator/Devices/[UUID]/data/Containers/Data/Application/[UUID]/Library/Preferences" ~/Desktop/Habitto_Backup_Manual/
```

**Step 5:** Save current git state
```bash
cd ~/Desktop/Habitto
git rev-parse HEAD > ~/Desktop/Habitto_Backup_Manual/git_commit.txt
```

---

### Option C: Using Xcode (Physical Device)

**Step 1:** Connect your iPhone/iPad

**Step 2:** Open Xcode → Window → Devices and Simulators

**Step 3:** Select your device

**Step 4:** Find Habitto app in list

**Step 5:** Click gear icon → Download Container...

**Step 6:** Save to: `~/Desktop/Habitto_Backup_Device/`

**Step 7:** Extract the downloaded .xcappdata file:
```bash
cd ~/Desktop/Habitto_Backup_Device/
unzip Habitto*.xcappdata
```

---

## ✅ VERIFICATION STEPS

After backup completes, verify it's valid:

### 1. Check Database File Exists
```bash
# Replace with your actual backup path
ls -lh ~/Desktop/Habitto_Backup_*/SwiftData/default.store
```

**Expected:** File size > 0 KB (probably 50-500 KB depending on your data)

### 2. Check Git State Saved
```bash
cat ~/Desktop/Habitto_Backup_*/git_commit.txt
```

**Expected:** A 40-character git commit hash

### 3. List All Backed Up Files
```bash
find ~/Desktop/Habitto_Backup_* -type f
```

**Expected:** At least 3-4 files

---

## 🔄 RESTORATION PROCEDURE (If Needed)

If something goes wrong during refactoring:

### Quick Restore (Simulator)

```bash
#!/bin/bash
# restore_habitto_data.sh

BACKUP_DIR="[YOUR_BACKUP_PATH]"  # e.g., ~/Desktop/Habitto_Backup_20251022_143000

# Find current app container
CURRENT_CONTAINER=$(find ~/Library/Developer/CoreSimulator/Devices -name "*.store" | grep -i "habitto\|default" | head -1)
CURRENT_CONTAINER=$(dirname "$CURRENT_CONTAINER")

# Stop app first!
xcrun simctl terminate booted com.habitto.app

# Restore database
cp -R "$BACKUP_DIR/SwiftData/"* "$CURRENT_CONTAINER/"

# Restore UserDefaults
APP_PATH=$(echo "$CURRENT_CONTAINER" | sed 's|/Library/Application Support.*||')
cp -R "$BACKUP_DIR/Preferences/"* "$APP_PATH/Library/Preferences/"

echo "✅ Restore complete. Restart the app."
```

### Restore Git State

```bash
cd ~/Desktop/Habitto
git reset --hard $(cat ~/Desktop/Habitto_Backup_*/git_commit.txt)
```

---

## 📝 BACKUP CHECKLIST

Before replying "BACKUP COMPLETE", verify:

- [ ] Backup directory created with timestamp
- [ ] SwiftData database file exists and size > 0
- [ ] Git commit hash saved
- [ ] You know where the backup is located
- [ ] You tested listing the backup files
- [ ] Total backup size looks reasonable (should be < 10 MB for typical use)

---

## 🎯 AFTER BACKUP COMPLETE

Once you've verified the backup:

**Reply to Cursor:**
```
BACKUP COMPLETE - PROCEED TO STAGE 1

Backup Location: [paste your backup path]
Database Size: [paste file size]
Git Commit: [paste commit hash]

Verified:
✅ SwiftData database backed up
✅ Git state saved
✅ Backup location known
✅ Can restore if needed

Ready for emergency toHabit() fix.
```

---

## ⚠️ IMPORTANT NOTES

1. **Keep backup until Phase 1 fully complete and tested**
2. **Don't delete backup even if tests pass** - keep for 1 week minimum
3. **Consider copying backup to external drive or cloud storage**
4. **If backup fails, STOP and ask for help** - don't proceed without backup
5. **Test restore procedure before making changes** (optional but recommended)

---

## 🆘 TROUBLESHOOTING

### Issue: Can't find database file
**Solution:** 
1. Run the app once in simulator
2. Make sure you're searching the right simulator (latest iOS version)
3. Try: `find ~/Library/Developer/CoreSimulator/Devices -name "*.store" -mtime -1`

### Issue: Backup script permission denied
**Solution:**
```bash
chmod +x backup_habitto_data.sh
sudo chown $(whoami) backup_habitto_data.sh
```

### Issue: Multiple database files found
**Solution:** Use the most recently modified one:
```bash
find ~/Library/Developer/CoreSimulator/Devices -name "*.store" -mtime -1 -ls | sort -k8,9
```

---

## 📞 IF YOU NEED HELP

If any step fails:
1. **Stop immediately**
2. **Don't proceed to Stage 1**
3. **Reply with exact error message**
4. **Include output of:**
   ```bash
   find ~/Library/Developer/CoreSimulator/Devices -name "*.store" | head -5
   ```

---

**Status:** 🟡 AWAITING YOUR BACKUP CONFIRMATION  
**Next Step:** You execute backup, verify, then reply "BACKUP COMPLETE"  
**Then:** I proceed to Stage 1 (Emergency toHabit() fix)

