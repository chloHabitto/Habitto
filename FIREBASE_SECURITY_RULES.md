# 🔐 Firestore Security Rules Setup Guide

## Problem

You're seeing this error:
```
⚠️ [CLOUD_BACKUP] Permission denied - Firestore security rules need configuration
Missing or insufficient permissions
```

This means your Firestore security rules need to be updated to allow anonymous users to write their data.

---

## Solution: Update Firestore Security Rules

### Step 1: Open Firebase Console

1. Go to https://console.firebase.google.com
2. Select your Firebase project
3. Click **Firestore Database** in the left sidebar
4. Click the **Rules** tab at the top

### Step 2: Paste These Rules

Replace your existing rules with this:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ✅ ANONYMOUS BACKUP: Users can only access their own data (including anonymous users)
    // Anonymous users are authenticated via Firebase Auth, so request.auth.uid will be their anonymous UID
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    
    // Specific collections for better organization
    match /users/{uid}/habits/{habitId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    
    // ✅ ANONYMOUS BACKUP: Completions organized by year-month
    match /users/{uid}/completions/{yearMonth}/records/{recordId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    
    // ✅ ANONYMOUS BACKUP: Daily awards
    match /users/{uid}/daily_awards/{dateKey} {
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

### Step 3: Publish Rules

1. Click **Publish** button
2. Wait for confirmation: "Rules published successfully"

---

## How These Rules Work

### Anonymous User Support

- **Anonymous users ARE authenticated** - they have a Firebase UID
- `request.auth != null` - checks if user is authenticated (including anonymous)
- `request.auth.uid == uid` - ensures users can only access their own data

### Data Isolation

- Each user (including anonymous) can only read/write their own data
- Path: `/users/{uid}/...` where `uid` matches `request.auth.uid`
- Anonymous users get a unique UID (e.g., `3ywaYBbdoLgVN97wXCNDacFrNOC3`)

### Collections Protected

- ✅ `habits/{habitId}` - Habit data
- ✅ `completions/{yearMonth}/records/{recordId}` - Completion records
- ✅ `daily_awards/{dateKey}` - Daily XP awards
- ✅ All other existing collections

---

## Testing the Rules

After publishing:

1. **Run the app**
2. **Create a new habit**
3. **Check console for:**
   ```
   ☁️ [CLOUD_BACKUP] Habit backed up successfully
   ```
4. **Verify in Firestore Console:**
   - Go to Firestore Database → Data tab
   - Navigate to: `users/{your-anonymous-uid}/habits/{habitId}`
   - You should see the habit data

---

## Troubleshooting

### Still Getting Permission Errors?

1. **Check if rules were published:**
   - Rules tab should show "Published" timestamp
   - Wait 1-2 minutes for rules to propagate

2. **Verify anonymous auth:**
   - Check console for: `✅ [ANONYMOUS_AUTH] SUCCESS`
   - User ID should be visible

3. **Check Firestore Console:**
   - Go to Firestore Database → Data
   - Look for `users/{anonymous-uid}/habits/`
   - If path exists but empty, rules might be blocking writes

4. **Test with Firebase Console:**
   - Try manually creating a document in Firestore Console
   - Path: `users/{your-anonymous-uid}/habits/test123`
   - If this works, rules are correct

### Rules Not Working?

- Make sure you clicked **Publish** (not just Save)
- Wait 1-2 minutes for propagation
- Check Firebase Console → Firestore → Rules for syntax errors
- Verify `request.auth.uid` matches the document path `uid`

---

## Security Notes

✅ **Safe:** These rules ensure:
- Users can only access their own data
- Anonymous users are isolated from each other
- No user can access another user's data

⚠️ **Important:** 
- Never allow `allow read, write: if true` (would allow anyone to access anything)
- Always check `request.auth.uid == uid` for user-scoped data
- Anonymous users are authenticated, so `request.auth != null` works for them

---

## Quick Reference

**Firebase Console URL:**
```
https://console.firebase.google.com/project/YOUR_PROJECT_ID/firestore/rules
```

**Replace `YOUR_PROJECT_ID` with your actual Firebase project ID**

---

**Status:** ✅ Rules updated in `firestore.rules` file - ready to paste into Firebase Console

