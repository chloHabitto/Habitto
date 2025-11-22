# Firebase Console Verification Guide

## Quick Navigation

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **Firestore Database** in the left sidebar
4. You should see the data structure below

---

## Expected Firestore Data Structure

### Root Collection: `users`

```
users/
  └── {firebaseUID}/          ← Your anonymous user's Firebase UID
      ├── events/             ← Progress events (habit completions, progress updates)
      │   └── {yearMonth}/    ← Format: "2024-11" (year-month)
      │       └── events/
      │           └── {eventId}/
      │               ├── id: String
      │               ├── userId: String (should match the UID in path)
      │               ├── habitId: String
      │               ├── dateKey: String (format: "2024-11-22")
      │               ├── operationId: String (for idempotency)
      │               ├── type: String (e.g., "completion", "progress")
      │               ├── progress: Int (0-100)
      │               └── timestamp: Timestamp
      │
      ├── completions/         ← Daily habit completion records
      │   └── {completionId}/ ← Format: "comp_{habitId}_{dateKey}"
      │       ├── completionId: String
      │       ├── habitId: String
      │       ├── dateKey: String
      │       ├── isCompleted: Bool
      │       ├── progress: Int (0-100)
      │       ├── createdAt: Timestamp
      │       └── updatedAt: Timestamp
      │
      └── daily_awards/        ← Daily XP awards and achievements
          └── {userIdDateKey}/ ← Format: "{userId}#{dateKey}"
              ├── userIdDateKey: String
              ├── dateKey: String
              ├── xpGranted: Int
              ├── allHabitsCompleted: Bool
              └── createdAt: Timestamp
```

---

## Step-by-Step Verification

### Step 1: Find Your Firebase UID

**In Xcode Console:**
- Look for: `✅ AppDelegate: User authenticated - uid: [Firebase UID]`
- Copy the UID (it's a long string like `fQVQZ0ch8uYsR6sSlvxf5BG3iUe2`)

**Or in Firebase Console:**
1. Go to **Authentication** → **Users**
2. Look for an anonymous user (no email)
3. Copy the UID

### Step 2: Check Firestore Database

1. Go to **Firestore Database**
2. Click on `users` collection
3. You should see a document with your Firebase UID as the document ID
4. Click on that document

### Step 3: Verify Events Collection

**After creating/completing a habit:**

1. Navigate to: `users/{yourUID}/events/`
2. You should see subcollections named by year-month (e.g., `2024-11`)
3. Click on a year-month → `events/`
4. You should see event documents with:
   - `id`: Event ID
   - `userId`: Should match your Firebase UID
   - `habitId`: The habit that was completed
   - `dateKey`: Date of the event (format: "2024-11-22")
   - `type`: Event type (e.g., "completion")
   - `progress`: Progress value (0-100)

**What to look for:**
- ✅ Events appear within 5 minutes of completing a habit
- ✅ `userId` field matches your Firebase UID
- ✅ `dateKey` matches today's date
- ✅ `habitId` matches the habit you completed

### Step 4: Verify Completions Collection

1. Navigate to: `users/{yourUID}/completions/`
2. You should see completion documents with IDs like: `comp_{habitId}_{dateKey}`
3. Each document should have:
   - `completionId`: Matches the document ID
   - `habitId`: The habit that was completed
   - `dateKey`: Date of completion
   - `isCompleted`: `true` if habit was completed
   - `progress`: Progress value (0-100)

**What to look for:**
- ✅ Completions appear after completing habits
- ✅ `isCompleted` is `true` for completed habits
- ✅ `dateKey` matches the date you completed the habit

### Step 5: Verify Daily Awards Collection

**After earning XP or completing all habits:**

1. Navigate to: `users/{yourUID}/daily_awards/`
2. You should see award documents with IDs like: `{userId}#{dateKey}`
3. Each document should have:
   - `userIdDateKey`: Matches the document ID
   - `dateKey`: Date of the award
   - `xpGranted`: Amount of XP granted
   - `allHabitsCompleted`: `true` if all habits completed that day

**What to look for:**
- ✅ Awards appear after earning XP
- ✅ `xpGranted` matches the XP you earned
- ✅ `dateKey` matches the date you earned the award

---

## Troubleshooting

### No Data in Firestore

**Check:**
1. ✅ Anonymous auth succeeded (check console logs)
2. ✅ Sync started (check for "Periodic sync started" log)
3. ✅ Sync cycles are running (check for "Full sync cycle completed" log)
4. ✅ Firestore security rules allow writes for authenticated users

**Firestore Security Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /events/{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /completions/{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /daily_awards/{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

### Data Appears in Wrong Location

**Check:**
- The `userId` in the document path matches your Firebase UID
- The `userId` field in documents matches the path
- You're looking in the correct Firebase project

### Data Not Updating

**Check:**
1. Wait 5 minutes (sync interval)
2. Check console for sync errors
3. Verify network connectivity
4. Check Firestore quota/limits

---

## Expected Timeline

- **Immediate (0-5 seconds):** Anonymous auth creates Firebase UID
- **Immediate (0-5 seconds):** Guest data migration runs
- **Immediate (0-5 seconds):** First sync cycle starts
- **Within 5 minutes:** Data appears in Firestore after creating/completing habits
- **Every 5 minutes:** Periodic sync runs automatically

---

## Quick Verification Checklist

- [ ] Firebase UID exists in Authentication → Users (anonymous user)
- [ ] `users/{firebaseUID}/` document exists in Firestore
- [ ] `users/{firebaseUID}/events/` collection exists
- [ ] Events appear after completing habits
- [ ] `users/{firebaseUID}/completions/` collection exists
- [ ] Completions appear after completing habits
- [ ] `users/{firebaseUID}/daily_awards/` collection exists (if XP earned)
- [ ] All document `userId` fields match the Firebase UID in path

---

**Last Updated:** November 2024

