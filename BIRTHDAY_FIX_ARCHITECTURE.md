# Birthday Storage Architecture Diagram

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        HABITTO APP                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────┐         ┌─────────────────────────┐   │
│  │   AccountView.swift  │         │  BirthdayManager.swift  │   │
│  │   (UI Layer)         │◄────────┤  (Singleton Manager)    │   │
│  │                      │         │  @MainActor             │   │
│  │ • Display birthday   │         │  @Published birthday    │   │
│  │ • Save button        │         │  @Published hasSetBday  │   │
│  │ • Edit UI            │         │                         │   │
│  └──────────────────────┘         └────────┬────────────────┘   │
│                                             │                     │
│                                 ┌───────────▼──────────┐         │
│                                 │  User Storage Layer  │         │
│                                 ├──────────────────────┤         │
│                                 │                      │         │
│  ┌──────────────────────────────┼──────────────────┐  │         │
│  │  UserDefaults.standard       │  Firestore Cloud │  │         │
│  │  (Local Storage)             │  (Cloud Storage) │  │         │
│  ├──────────────────────────────┼──────────────────┤  │         │
│  │ • Guest Key:                 │ • Path: users/{} │  │         │
│  │   GuestUserBirthday          │   /profile/info  │  │         │
│  │                              │ • Field: birthday│  │         │
│  │ • User Key:                  │ • Field: updated │  │         │
│  │   UserBirthday_{UID}_{Email} │   At (timestamp) │  │         │
│  │                              │                  │  │         │
│  │ • Legacy Key (auto-migrated):│                  │  │         │
│  │   UserBirthday → converted   │                  │  │         │
│  └──────────────────────────────┴──────────────────┘  │         │
│                                                       │         │
│  ┌──────────────────────────────────────────────────┐ │         │
│  │  GuestDataMigration.swift                        │ │         │
│  │  (Migration on Sign-In)                          │ │         │
│  │                                                   │ │         │
│  │  Step 5: migrateGuestUserProfile()               │ │         │
│  │  └─→ BirthdayManager.migrateGuestBirthdayToUser()│ │         │
│  └──────────────────────────────────────────────────┘ │         │
│                                                       │         │
│  ┌──────────────────────────────────────────────────┐ │         │
│  │  AuthenticationManager                           │ │         │
│  │  (Auth State Changes)                            │ │         │
│  │                                                   │ │         │
│  │  Notifies BirthdayManager on auth state change   │ │         │
│  └──────────────────────────────────────────────────┘ │         │
│                                                       │         │
└────────────────────────────────────────────────────────┘         │
                                                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

### Scenario 1: Guest Sets Birthday

```
┌─────────────────────────────┐
│ User Sets Birthday in UI    │
└──────────────┬──────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ AccountView: Birthday Bottom Sheet       │
│ User picks: Dec 16, 1999                 │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ onSave callback:                         │
│ birthdayManager.saveBirthday(selectedDate)
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ BirthdayManager.saveBirthday()           │
│ • isUserAuthenticated() → false (guest)  │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ UserDefaults.set(date, forKey:           │
│   "GuestUserBirthday")                   │
│                                          │
│ ✅ Birthday saved to guest key           │
└──────────────────────────────────────────┘
```

### Scenario 2: Guest → Authenticated Conversion

```
┌─────────────────────────────────────────┐
│ Guest Taps "Sign in with Apple"         │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Firebase Authentication                 │
│ Creates account, issues auth token      │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ AuthenticationManager                   │
│ authState → .authenticated(user)        │
│ Notifies subscribers (including         │
│ BirthdayManager)                        │
└──────────────┬──────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ GuestDataMigration.migrateGuestData()    │
│ Step 5: migrateGuestUserProfile()        │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ BirthdayManager.migrateGuestBirthdayToUser() │
│                                          │
│ Load: UserDefaults.get("GuestUserBday")  │
│   → Date(Dec 16, 1999) found             │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ Generate user-specific key:              │
│ "UserBirthday_{uid}_{sanitized_email}"  │
│                                          │
│ Save to: UserDefaults.set(date, key: ...) │
│ Delete: UserDefaults.removeObject(       │
│   "GuestUserBday")                       │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ Firestore Sync:                          │
│ POST users/{uid}/profile/info            │
│   { birthday: 946684800,                 │
│     updatedAt: <timestamp> }             │
│                                          │
│ ✅ Birthday migrated & synced!           │
└──────────────────────────────────────────┘
```

### Scenario 3: User Signs Back In (Reinstall)

```
┌─────────────────────────────────────────┐
│ Fresh Install / App Restart             │
│ User Signs In with Apple                │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Firebase Auth                           │
│ currentUser authenticated                │
└──────────────┬──────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ BirthdayManager                          │
│ handleAuthStateChange()                  │
│ → call loadBirthdayForAuthenticatedUser()
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ Generate user-specific key               │
│ Check: UserDefaults.get(userKey)         │
│ → nil (fresh install)                    │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ Call loadBirthdayFromFirestore()         │
│                                          │
│ GET users/{uid}/profile/info             │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ Parse response:                          │
│ birthday: 946684800 (Dec 16, 1999)       │
│                                          │
│ Save locally:                            │
│ UserDefaults.set(date, forKey: userKey)  │
│                                          │
│ ✅ Birthday restored from cloud!         │
└──────────────────────────────────────────┘
```

---

## Storage Keys Diagram

```
┌──────────────────────────────────────────────────────────┐
│                  UserDefaults Keys                        │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  GUEST MODE:                                             │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Key: "GuestUserBirthday"                           │  │
│  │ Value: Date object (Dec 16, 1999)                  │  │
│  │ Lifetime: Until user signs in                      │  │
│  │ Location: Device only                              │  │
│  └────────────────────────────────────────────────────┘  │
│                                                           │
│  AUTHENTICATED MODE:                                     │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Key: "UserBirthday_abc123_john_email_com"          │  │
│  │       └──┬──┘         └───┬───┘ └────┬─────┘       │  │
│  │          │                │         │              │  │
│  │       Base prefix      User UID   Sanitized        │  │
│  │                                   email            │  │
│  │ Value: Date object                                 │  │
│  │ Lifetime: Until user signs out                     │  │
│  │ Location: Device only (backed up to Firestore)     │  │
│  └────────────────────────────────────────────────────┘  │
│                                                           │
│  BACKWARD COMPATIBILITY (Legacy - Auto-migrated):        │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Key: "UserBirthday"                                │  │
│  │ Status: DETECTED ON FIRST LOAD                     │  │
│  │ Action: AUTO-MIGRATED to user-specific key         │  │
│  │         Then DELETED                               │  │
│  │ Result: No data loss, seamless upgrade             │  │
│  └────────────────────────────────────────────────────┘  │
│                                                           │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│                  Firestore Schema                         │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  Collection: "users"                                     │
│  Document:   "{userId}"                                  │
│  Subcollection: "profile"                                │
│  Document:   "info"                                      │
│                                                           │
│  Fields:                                                 │
│  ┌────────────────────────────────────────────────────┐  │
│  │ • birthday: number (TimeIntervalSince1970)         │  │
│  │   Value: 946684800 (Dec 16, 1999)                  │  │
│  │   Set By: BirthdayManager.syncBirthdayToFirestore()│  │
│  │                                                    │  │
│  │ • updatedAt: timestamp (server)                    │  │
│  │   Auto-generated by Firestore                      │  │
│  └────────────────────────────────────────────────────┘  │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

---

## State Machine Diagram

```
                    ┌──────────────┐
                    │ UNINITIALIZED│
                    └──────┬───────┘
                           │ app launch
                           ▼
                    ┌──────────────┐
         ┌─────────►│ GUEST MODE   │◄────────────┐
         │          └──────┬───────┘             │
         │                 │ set birthday       │
         │                 ▼                    │
         │          ┌──────────────┐            │
         │          │ GUEST HAS BIG│            │
         │          └──────┬───────┘            │
         │                 │ sign in            │
         │                 ▼                    │
         │          ┌──────────────────┐        │
         │          │ MIGRATING... Step│        │
         │          │ 5: USER PROFILE  │        │
         │          └──────┬───────────┘        │
         │                 │                    │
         │                 ▼                    │
         │          ┌──────────────┐            │
    sign out        │ AUTH MODE    │   load    │
    remove key      │ HAS BIRTHDAY │ ◄─────────┘
    sign in as      └──────┬───────┘
    different user          │ set/update birthday
                            ▼
                     ┌──────────────┐
                     │ AUTH MODE    │
                     │ HAS BIRTHDAY │
                     │ (synced)     │
                     └──────┬───────┘
                            │ sign out
                            ▼
         ┌──────────────────────────┐
         │ RETURN TO GUEST MODE     │
         └──────────────────────────┘
         (birthday cleared from view)
```

---

## Threading Model

```
┌─────────────────────────────────────────────────────────┐
│                  Main Thread                             │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  UI Updates (AccountView)                               │
│  ├─ @Published birthdayManager.birthday                 │
│  └─ triggers UI refresh via SwiftUI                     │
│                                                          │
│  BirthdayManager (@MainActor)                           │
│  ├─ saveBirthday()                                      │
│  ├─ loadBirthday()                                      │
│  ├─ migrateGuestBirthdayToUser()                        │
│  └─ handleAuthStateChange()                             │
│                                                          │
└─────────────────────────────────────────────────────────┘
         │                                │
         │ UserDefaults                   │ Firestore
         ▼ (sync)                         ▼ (async Task)
┌─────────────────────────────────────────────────────────┐
│                Background Operations                     │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Local Storage                                          │
│  └─ UserDefaults.set()/get() [very fast]               │
│                                                          │
│  Cloud Storage (non-blocking)                           │
│  └─ Task { await loadBirthdayFromFirestore() }         │
│     ├─ Firestore query (network)                       │
│     ├─ Parse response                                   │
│     └─ Update @Published on MainActor                   │
│                                                          │
│  syncBirthdayToFirestore() [non-blocking]              │
│  └─ Task { await firestore.setData(...) }              │
│     └─ Never blocks UI                                  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Error Handling Flowchart

```
                    ┌──────────────┐
                    │ saveBirthday()│
                    └──────┬───────┘
                           │
                ┌──────────┴──────────┐
                ▼                     ▼
        ┌─────────────────┐   ┌─────────────────┐
        │ isAuthenticated?│   │ Save to guest    │
        │                 │   │ key              │
        └────┬───────┬────┘   │ ✅ Success       │
        yes  │       │ no     └─────────────────┘
            ▼       │
    ┌─────────────────┐
    │ Save to user key│
    └────────┬────────┘
             │
             ▼
    ┌──────────────────────────┐
    │ syncBirthdayToFirestore()│
    └────┬──────────────────┬──┘
    success│                 │ error
         ▼                 ▼
    ┌──────────┐     ┌──────────────────┐
    │ ✅ Synced│     │ ⚠️ Log Warning   │
    │          │     │ ❌ Fallback OK   │
    │          │     │ (local saved)    │
    └──────────┘     └──────────────────┘
            │                 │
            └────────┬────────┘
                     ▼
            ┌──────────────────┐
            │ showToast Success │
            └──────────────────┘
```

---

## Sync Status Flow

```
SAVE OPERATION:

User taps "Done"
    │
    ├─ LocalStorage (immediate)
    │  └─ UserDefaults.set() ✅ instant
    │
    └─ Cloud Storage (background)
       └─ Task { Firestore.setData() }
          ├─ Network request
          ├─ Parse & update Firestore
          ├─ Return to MainActor
          └─ UI updates via @Published

LOAD OPERATION:

App Launch
    │
    ├─ Check LocalStorage (immediate)
    │  ├─ User-specific key exists?
    │  │  └─ Yes ✅ Use local (no cloud request)
    │  └─ User-specific key missing?
    │     └─ Legacy key exists?
    │        ├─ Yes ✅ Migrate & use
    │        └─ No → Continue to cloud
    │
    └─ Check Cloud Storage (background)
       └─ Task { Firestore.get() }
          ├─ Network request
          ├─ Parse birthday
          ├─ Save locally
          ├─ Return to MainActor
          └─ UI updates via @Published
```

---

## Key Insights

1. **Decoupling**: BirthdayManager fully decoupled from UI layer
2. **Reactivity**: @Published properties auto-update UI via SwiftUI
3. **Threading**: @MainActor ensures thread-safe operations
4. **Async**: Firestore operations non-blocking
5. **Fallback**: Works with or without Firestore
6. **Migration**: Automatic detection and migration of old keys
7. **Isolation**: User-specific keys prevent data mixing
