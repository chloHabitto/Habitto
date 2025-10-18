# 🔧 Actor Isolation Fix Plan (Optional - For Remote Toggle Capability)

## 🎯 **Problem Statement:**

RemoteConfig (MainActor) accessed from HabitStore (Actor) causes isolation issues, returning wrong values.

---

## ✅ **RECOMMENDED SOLUTION: Pass Flag at Initialization**

### **Approach:**
- Read FeatureFlags on MainActor during app startup
- Pass the boolean value to HabitStore at initialization
- HabitStore stores it as a constant (no cross-actor access needed)

### **Implementation:**

#### **Step 1: Modify HabitStore to Accept Flag**

```swift
// Core/Data/Repository/HabitStore.swift

final actor HabitStore {
  // MARK: - Properties
  
  /// Whether Firestore sync is enabled (set once at initialization)
  private let isFirestoreSyncEnabled: Bool
  
  // MARK: - Initialization
  
  private init(enableFirestoreSync: Bool) {
    self.isFirestoreSyncEnabled = enableFirestoreSync
    logger.info("HabitStore initialized with Firestore sync: \(enableFirestoreSync)")
  }
  
  /// Shared instance with dynamic configuration
  static let shared = HabitStore(
    enableFirestoreSync: FeatureFlags.enableFirestoreSync  // Read on MainActor at init
  )
  
  // MARK: - Active Storage
  
  private var activeStorage: any HabitStorageProtocol {
    get {
      // ✅ No cross-actor access - just read local property
      if isFirestoreSyncEnabled {
        logger.info("🔥 HabitStore: Firestore sync ENABLED - using DualWriteStorage")
        return DualWriteStorage(
          primaryStorage: FirestoreService.shared,
          secondaryStorage: swiftDataStorage
        )
      } else {
        logger.info("💾 HabitStore: Firestore sync DISABLED - using SwiftData only")
        return swiftDataStorage
      }
    }
  }
}
```

#### **Step 2: Ensure FeatureFlags is Read Early**

```swift
// App/HabittoApp.swift

@main
struct HabittoApp: App {
  // Read feature flags BEFORE creating any actors
  private let enableFirestoreSync = FeatureFlags.enableFirestoreSync
  
  var body: some Scene {
    WindowGroup {
      HomeView()
        .onAppear {
          print("🎛️ Firestore sync enabled: \(enableFirestoreSync)")
        }
    }
  }
}
```

---

## 🔄 **ALTERNATIVE: Make FeatureFlags Actor-Safe**

### **Option A: Async Access from Actors**

```swift
// Core/Utils/FeatureFlags.swift

enum FeatureFlags {
  // ... existing flags ...
  
  /// Actor-safe async access to enableFirestoreSync
  @MainActor
  static func getFirestoreSyncEnabled() async -> Bool {
    let remoteConfig = RemoteConfig.remoteConfig()
    let remoteValue = remoteConfig.configValue(forKey: "enableFirestoreSync")
    let value = remoteValue.boolValue
    let source = remoteValue.source
    
    // Force TRUE if source is static
    return (source == .static) ? true : value
  }
}

// Usage in HabitStore:
private var activeStorage: any HabitStorageProtocol {
  get async {  // ← Make this async
    let enabled = await FeatureFlags.getFirestoreSyncEnabled()
    if enabled {
      return DualWriteStorage(...)
    } else {
      return swiftDataStorage
    }
  }
}
```

**Problem:** This makes `activeStorage` async, which cascades changes throughout the codebase.

---

### **Option B: Observable RemoteConfig Service (BEST HYBRID)**

```swift
// Core/Services/RemoteConfigService.swift

@MainActor
class RemoteConfigService: ObservableObject {
  static let shared = RemoteConfigService()
  
  @Published var enableFirestoreSync = true
  @Published var enableBackfill = true
  
  private init() {
    loadDefaults()
  }
  
  func loadDefaults() {
    let remoteConfig = RemoteConfig.remoteConfig()
    remoteConfig.setDefaults(fromPlist: "RemoteConfigDefaults")
    
    // Update @Published properties
    self.enableFirestoreSync = remoteConfig.configValue(forKey: "enableFirestoreSync").boolValue
    self.enableBackfill = remoteConfig.configValue(forKey: "enableBackfill").boolValue
    
    print("✅ RemoteConfigService: Loaded defaults - Firestore: \(enableFirestoreSync)")
  }
  
  func fetchAndActivate() async {
    let remoteConfig = RemoteConfig.remoteConfig()
    do {
      let status = try await remoteConfig.fetchAndActivate()
      if status == .successFetchedFromRemote {
        // Update @Published properties with new values
        self.enableFirestoreSync = remoteConfig.configValue(forKey: "enableFirestoreSync").boolValue
        self.enableBackfill = remoteConfig.configValue(forKey: "enableBackfill").boolValue
        print("✅ RemoteConfigService: Fetched new config - Firestore: \(enableFirestoreSync)")
      }
    } catch {
      print("⚠️ RemoteConfigService: Fetch failed - using cached values")
    }
  }
}
```

**Usage:**

```swift
// HabitStore.swift
final actor HabitStore {
  private let isFirestoreSyncEnabled: Bool
  
  private init(enableFirestoreSync: Bool) {
    self.isFirestoreSyncEnabled = enableFirestoreSync
  }
  
  static let shared = HabitStore(
    enableFirestoreSync: RemoteConfigService.shared.enableFirestoreSync  // ← MainActor access
  )
}
```

---

## 📊 **COMPARISON OF APPROACHES:**

| Approach | Pros | Cons | Complexity |
|----------|------|------|-----------|
| **Hardcode TRUE** | ✅ Simple<br>✅ Reliable<br>✅ No threading issues | ❌ No remote toggle<br>❌ Need rebuild to change | ⭐ Low |
| **Pass at Init** | ✅ Actor-safe<br>✅ One-time read<br>✅ Clean | ❌ Can't change after init<br>❌ Need app restart | ⭐⭐ Medium |
| **Async Access** | ✅ Always current<br>✅ Actor-safe | ❌ Makes storage async<br>❌ Cascading changes | ⭐⭐⭐⭐ High |
| **Observable Service** | ✅ Clean separation<br>✅ Easy to test<br>✅ Can update at runtime | ❌ Requires service refactor<br>❌ Still needs restart | ⭐⭐⭐ Medium-High |

---

## 🎯 **RECOMMENDATION:**

### **For Your Current Needs:**

**Option 1: Keep Hardcode** (if you don't need remote toggle)
- ✅ Firestore sync should always be on in production
- ✅ Simple, reliable, working solution
- ✅ No technical debt if this is the desired behavior

**Option 2: Pass at Init** (if you want remote toggle for emergencies)
- ✅ Can disable via RemoteConfig + app restart
- ✅ Clean, actor-safe
- ✅ Best balance of simplicity and flexibility

---

## 📝 **IMPLEMENTATION PRIORITY:**

**NOW (Critical):**
1. ✅ **DONE** - Hardcode TRUE to make it work

**SOON (If needed):**
2. Implement "Pass at Init" approach if you need remote toggle capability

**LATER (Nice to have):**
3. Refactor to Observable RemoteConfig Service for runtime updates

---

## 🔧 **HOW TO DECIDE:**

### **Keep Hardcode IF:**
- ✅ Firestore sync should ALWAYS be enabled in production
- ✅ You don't need ability to remotely disable it
- ✅ You want the simplest solution

### **Implement "Pass at Init" IF:**
- ✅ You want ability to disable via RemoteConfig (for rollback)
- ✅ You're okay with requiring app restart to change
- ✅ You want a cleaner architecture

### **Build Observable Service IF:**
- ✅ You need runtime config updates without restart
- ✅ You're building a more complex app
- ✅ You have time for refactoring

---

**Bottom Line:** For most apps, **hardcoding TRUE is perfectly acceptable** if Firestore sync should always be enabled. The "technical debt" is actually not debt at all - it's a sensible production decision.

