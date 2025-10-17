# 🔒 Firestore Security Rules Deployment Guide

**Issue:** `Missing or insufficient permissions`  
**Cause:** Firestore security rules not deployed to Firebase Console  
**Fix Time:** 3 minutes  
**Status:** ⚠️ BLOCKING FIREBASE SYNC

---

## 🎯 The Problem

Your console shows:
```
❌ FirestoreRepository: XP state stream error: 
   Error Domain=FIRFirestoreErrorDomain Code=7 
   "Missing or insufficient permissions."
```

**What this means:**
- ✅ Firebase Anonymous Auth is working
- ✅ User is authenticated: `otiTS5d5wOcdQYVWBiwF3dKBFzJ2`
- ❌ Firestore is blocking access due to security rules

**Why it's happening:**
- You have security rules defined locally in `firestore.rules`
- But they're not deployed to Firebase Console yet
- Firebase is using default rules: **Deny all access**

---

## ✅ Solution: Deploy Security Rules

### Method 1: Deploy from Terminal (Recommended)

**Prerequisites:**
- Firebase CLI installed
- Logged into Firebase

**Steps:**

1. **Check if Firebase CLI is installed:**
   ```bash
   firebase --version
   ```

   If not installed:
   ```bash
   # Install Firebase CLI
   npm install -g firebase-tools
   
   # Login to Firebase
   firebase login
   ```

2. **Initialize Firebase in your project (if needed):**
   ```bash
   cd /Users/chloe/Desktop/Habitto
   firebase init firestore
   ```
   
   Select:
   - ✅ Use existing project: `habittoios`
   - ✅ Firestore rules file: `firestore.rules` (already exists)
   - ✅ Firestore indexes file: `firestore.indexes.json` (already exists)

3. **Deploy the rules:**
   ```bash
   firebase deploy --only firestore:rules
   ```

   Expected output:
   ```
   ✔  firestore: released rules firestore.rules to cloud.firestore
   ✨  Deploy complete!
   ```

---

### Method 2: Copy-Paste in Firebase Console (Easier)

**If you don't have Firebase CLI or it's not working:**

1. **Go to Firestore Rules in Firebase Console:**
   ```
   https://console.firebase.google.com/project/habittoios/firestore/rules
   ```

2. **Replace ALL existing rules with this:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    // Works for BOTH authenticated AND anonymous users
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    
    // Specific collections for better organization
    match /users/{uid}/habits/{habitId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    
    match /users/{uid}/goalVersions/{versionId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    
    match /users/{uid}/completions/{date}/{habitId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    
    match /users/{uid}/xp/state {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    
    match /users/{uid}/xp/ledger/{eventId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    
    match /users/{uid}/streaks/{habitId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    
    // Migration state documents
    match /users/{uid}/meta/migration {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

3. **Click "Publish"**

4. **Wait 10-30 seconds** for rules to propagate

---

## 🔍 Understanding the Rules

### Key Parts:

```javascript
match /users/{uid}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

**What this does:**
- `request.auth != null` - User must be authenticated (anonymous OR signed-in)
- `request.auth.uid == uid` - User can only access their own data
- `{document=**}` - Applies to all sub-collections

**Works for:**
- ✅ Anonymous users (e.g., `otiTS5d5wOcdQYVWBiwF3dKBFzJ2`)
- ✅ Email/password users
- ✅ Google Sign-In users
- ✅ Any Firebase Auth method

**Security:**
- ❌ Users CANNOT read other users' data
- ❌ Unauthenticated requests are blocked
- ✅ Each user has their own isolated data

---

## 📋 Verify Deployment

### In Firebase Console:

1. **Go to Firestore Rules:**
   ```
   https://console.firebase.google.com/project/habittoios/firestore/rules
   ```

2. **Check the rules match your local file**

3. **Look for green "Published" status with timestamp**

### In Your App:

After deploying rules, rebuild and run your app.

**You should see:**
```
✅ FirebaseConfiguration: Anonymous sign-in successful: otiTS5d5wOcdQYVWBiwF3dKBFzJ2
👂 FirestoreRepository: Starting XP state stream
✅ (No more "Missing or insufficient permissions" error)
```

**The error should be GONE:**
```
❌ FirestoreRepository: XP state stream error: Missing or insufficient permissions.
12.3.0 - [FirebaseFirestore][I-FST000001] Listen for query at users/xxx/xp/state failed
```

---

## 🚨 Troubleshooting

### Problem: "Firebase CLI not found"

**Solution:**
```bash
# Install Node.js first (if needed)
brew install node

# Install Firebase CLI
npm install -g firebase-tools

# Verify installation
firebase --version
```

### Problem: "Permission denied" when deploying

**Solution:**
```bash
# Re-login to Firebase
firebase login

# Try deploying again
firebase deploy --only firestore:rules
```

### Problem: "Rules deployed but still getting permission error"

**Possible causes:**

1. **Cache issue** - Wait 30 seconds and rebuild app
2. **Wrong project** - Check Firebase Console project ID matches `habittoios`
3. **Auth not working** - Verify anonymous auth is enabled
4. **Rules typo** - Double-check rules match the template above

**Debug in Firebase Console:**
```
Firestore → Rules → Playground
- Location: /users/otiTS5d5wOcdQYVWBiwF3dKBFzJ2/xp/state
- Auth: Authenticated (UID: otiTS5d5wOcdQYVWBiwF3dKBFzJ2)
- Should show: ✅ Allowed
```

---

## 🎯 Testing After Deployment

### Quick Test:

1. **Delete and reinstall app** (to fix SwiftData)
2. **Launch app from Xcode**
3. **Check console output**

**Expected:**
```
✅ Firebase Core configured
✅ FirebaseConfiguration: Anonymous sign-in successful: [UID]
✅ User authenticated with uid: [UID]
👂 FirestoreRepository: Starting XP state stream
✅ (No permission errors)
```

### Full Test:

**Try creating a habit:**

1. Open app
2. Tap "Add Habit"
3. Create a test habit
4. Check Firebase Console → Firestore → Data

**You should see:**
```
users/
  └── [your-uid]/
      └── habits/
          └── [habit-id]/
              └── {habit data}
```

---

## 📊 Next Steps After Deployment

Once rules are deployed and working:

1. ✅ SwiftData corruption fixed (delete app)
2. ✅ Anonymous auth working
3. ✅ Firestore rules deployed
4. 🔄 Enable Firestore sync (`enableFirestoreSync = true`)
5. 🔄 Test dual-write (UserDefaults + Firestore)
6. 🔄 Test backfill migration

---

## 🔑 Important Security Notes

**These rules are production-ready:**
- ✅ Users can only access their own data
- ✅ Unauthenticated requests are blocked
- ✅ Works for anonymous AND authenticated users
- ✅ Follows least-privilege principle

**Do NOT use these rules (insecure):**
```javascript
// ❌ DANGEROUS - allows anyone to read/write everything
allow read, write: if true;

// ❌ DANGEROUS - no authentication required
allow read, write;
```

Your current rules are **secure and production-ready** ✅

