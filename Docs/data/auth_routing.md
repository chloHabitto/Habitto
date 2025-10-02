# Auth Routing Trace - Guest ↔ Account Data Isolation

## Authentication State Management

### 1. AuthenticationManager.swift - Sign-out Handling
**File**: `Core/Managers/AuthenticationManager.swift:123-143`

```swift
func signOut() {
    print("🔐 AuthenticationManager: Starting sign out")
    do {
        try Auth.auth().signOut()
        authState = .unauthenticated
        currentUser = nil
        
        // Clear sensitive data from Keychain
        KeychainManager.shared.clearAuthenticationData()
        print("✅ AuthenticationManager: Cleared sensitive data from Keychain")
        
        // Clear XP data to prevent data leakage between users
        XPManager.shared.handleUserSignOut()
        print("✅ AuthenticationManager: Cleared XP data")
        
        print("✅ AuthenticationManager: User signed out successfully")
    } catch {
        authState = .error(error.localizedDescription)
        print("❌ AuthenticationManager: Failed to sign out: \(error.localizedDescription)")
    }
}
```

**Analysis**: ✅ **GOOD** - Calls `XPManager.shared.handleUserSignOut()` to clear XP data

### 2. XPManager.swift - User Sign-out Handling
**File**: `Core/Managers/XPManager.swift:501-505`

```swift
func handleUserSignOut() {
    // Clear all XP-related data
    userProgress = UserProgress()
    recentTransactions = []
    dailyAwards = [:]
    
    // Remove the keys from UserDefaults to ensure clean state
    userDefaults.removeObject(forKey: userProgressKey)
    userDefaults.removeObject(forKey: recentTransactionsKey)
    userDefaults.removeObject(forKey: dailyAwardsKey)
}
```

**Analysis**: ✅ **GOOD** - Clears XP data and UserDefaults keys on sign-out

## Data Container Management

### 1. SwiftDataContainer.swift - Single Container Issue
**File**: `Core/Data/SwiftData/SwiftDataContainer.swift:7-46`

```swift
@MainActor
final class SwiftDataContainer: ObservableObject {
    static let shared = SwiftDataContainer()
    
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    private init() {
        do {
            // Create the model container with comprehensive entities
            let schema = Schema([
                HabitData.self,
                CompletionRecord.self,
                DifficultyRecord.self,
                UsageRecord.self,
                HabitNote.self,
                StorageHeader.self,
                MigrationRecord.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            self.modelContext = ModelContext(modelContainer)
```

**Analysis**: ❌ **CRITICAL ISSUE** - Single shared container for all users, no user isolation

### 2. UserAwareStorage.swift - User ID Management
**File**: `Core/Data/Storage/UserAwareStorage.swift:29-44`

```swift
@MainActor
private func getCurrentUserId() async -> String {
    // Get current user ID from authentication manager
    let manager = await authManager
    if let user = manager.currentUser {
        return user.uid
    }
    
    // Fallback to guest user ID if no authenticated user
    return "guest_user"
}

private func getUserSpecificKey(_ baseKey: String) async -> String {
    let userId = await getCurrentUserId()
    return "\(userId)_\(baseKey)"
}

private func clearCacheIfUserChanged() {
    Task { @MainActor in
        let currentUserId = await getCurrentUserId()
        if self.currentUserId != currentUserId {
            self.cachedHabits = nil
            self.currentUserId = currentUserId
        }
    }
}
```

**Analysis**: ⚠️ **PARTIAL** - User-aware storage wrapper but relies on single SwiftData container

### 3. SwiftDataStorage.swift - User ID Retrieval
**File**: `Core/Data/SwiftData/SwiftDataStorage.swift:15-20`

```swift
// Helper method to get current user ID for data isolation
private func getCurrentUserId() async -> String? {
    return await MainActor.run {
        return AuthenticationManager.shared.currentUser?.uid
    }
}
```

**Analysis**: ⚠️ **PARTIAL** - Gets user ID but doesn't create separate containers

## Singleton Cache Issues

### 1. HabitRepository.swift - Singleton Cache
**File**: `Core/Data/HabitRepository.swift:129`

```swift
@MainActor
class HabitRepository: ObservableObject {
    static let shared = HabitRepository()
    @Published var habits: [Habit] = []
```

**Analysis**: ❌ **CRITICAL ISSUE** - Singleton cache that survives sign-out

### 2. HabitStorageManager.swift - Singleton Cache
**File**: `Core/Models/Habit.swift:4-7`

```swift
class HabitStorageManager {
    static let shared = HabitStorageManager()
    private let userDefaults = UserDefaults.standard
    private let habitsKey = "SavedHabits"
    // Performance optimization: Cache loaded habits
    private var cachedHabits: [Habit]?
```

**Analysis**: ❌ **CRITICAL ISSUE** - Singleton cache that survives sign-out

### 3. HabitStore.swift - Actor Cache
**File**: `Core/Data/Repository/HabitStore.swift:10`

```swift
final actor HabitStore {
    static let shared = HabitStore()
```

**Analysis**: ❌ **CRITICAL ISSUE** - Actor-based singleton that survives sign-out

### 4. SegmentedHabitStore.swift - Hardcoded User ID
**File**: `Core/Data/Storage/SegmentedHabitStore.swift:17-18`

```swift
private init() {
    self.userId = "default_user" // In production, from auth
```

**Analysis**: ❌ **CRITICAL ISSUE** - Hardcoded user ID, no user isolation

### 5. CrashSafeHabitStore.swift - Hardcoded User ID
**File**: `Core/Data/Storage/CrashSafeHabitStore.swift:67-68`

```swift
// For now, use a default userId - in production, this would come from user authentication
self.userId = "default_user"
```

**Analysis**: ❌ **CRITICAL ISSUE** - Hardcoded user ID, no user isolation

## Data Isolation Analysis

### Current State
1. **Single SwiftData Container**: All users share the same `ModelContainer` and `ModelContext`
2. **Singleton Caches**: Multiple singleton classes cache user data and survive sign-out
3. **UserDefaults Keys**: Not properly scoped by userId in many places
4. **Hardcoded User IDs**: Several storage classes use hardcoded user IDs

### Missing Auth Routing
1. **No Container Switching**: No mechanism to switch between guest and user containers
2. **No Cache Clearing**: Singletons not cleared on sign-out (except XPManager)
3. **No User Scoping**: Most storage doesn't properly scope data by userId

## Critical Issues Found

### 1. Single SwiftData Container
- **Issue**: All users share the same `SwiftDataContainer.shared`
- **Impact**: Data leakage between users, no isolation
- **Fix**: Create separate containers per user

### 2. Sticky Singleton Caches
- **Issue**: `HabitRepository.shared`, `HabitStorageManager.shared`, `HabitStore.shared` survive sign-out
- **Impact**: User A's data visible to User B after sign-out/sign-in
- **Fix**: Clear all singleton caches on sign-out

### 3. Hardcoded User IDs
- **Issue**: `SegmentedHabitStore` and `CrashSafeHabitStore` use hardcoded `"default_user"`
- **Impact**: All users share the same storage files
- **Fix**: Use actual user ID from authentication

### 4. Missing Container Switching
- **Issue**: No mechanism to switch between guest and user data containers
- **Impact**: Guest data persists when user signs in
- **Fix**: Implement container switching based on auth state

### 5. Incomplete User Scoping
- **Issue**: Many storage operations don't scope data by userId
- **Impact**: Data leakage between users
- **Fix**: Ensure all storage operations are user-scoped

## Recommendations

### 1. Implement Container Switching
```swift
// Create separate containers per user
func getContainer(for userId: String) -> ModelContainer {
    // Create user-specific container
}

func switchToGuestContainer() {
    // Switch to guest container
}

func switchToUserContainer(userId: String) {
    // Switch to user-specific container
}
```

### 2. Clear All Singleton Caches
```swift
func handleUserSignOut() {
    // Clear all singleton caches
    HabitRepository.shared.clearCache()
    HabitStorageManager.shared.clearCache()
    HabitStore.shared.clearCache()
    XPManager.shared.handleUserSignOut()
}
```

### 3. Fix User ID Scoping
```swift
// Replace hardcoded user IDs with actual user IDs
private func getCurrentUserId() -> String {
    return AuthenticationManager.shared.currentUser?.uid ?? "guest"
}
```

### 4. Implement Proper Auth Routing
```swift
// Listen to auth state changes and switch containers
func setupAuthStateListener() {
    AuthenticationManager.shared.$authState
        .sink { [weak self] authState in
            switch authState {
            case .unauthenticated:
                self?.switchToGuestContainer()
            case .authenticated(let user):
                self?.switchToUserContainer(userId: user.uid)
            }
        }
}
```

## Root Cause of Guest/Sign-in Bug

The guest/sign-in bug occurs because:

1. **Single Container**: All users share the same SwiftData container
2. **Sticky Caches**: Singleton caches survive sign-out and leak data
3. **No Container Switching**: No mechanism to switch between guest and user data
4. **Hardcoded User IDs**: Storage classes don't use actual user IDs
5. **Incomplete User Scoping**: Data not properly isolated by userId

## Fix Priority

1. **HIGH**: Implement container switching based on auth state
2. **HIGH**: Clear all singleton caches on sign-out
3. **MEDIUM**: Fix hardcoded user IDs in storage classes
4. **MEDIUM**: Ensure all storage operations are user-scoped
5. **LOW**: Add comprehensive auth routing tests
