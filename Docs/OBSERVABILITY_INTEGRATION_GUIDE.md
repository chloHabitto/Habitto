# Observability Integration Guide

This guide shows how to integrate HabittoLogger and TelemetryService into your services for production debugging and monitoring.

## Overview

The observability stack consists of:
- **HabittoLogger**: Category-based logging (firestore, xp, streak, error, etc.)
- **TelemetryService**: In-memory counters for operational metrics
- **CrashlyticsService**: Crash reporting and non-fatal error tracking (guarded)
- **DebugOverlay**: Real-time UI showing telemetry counters (three-tap gesture)

---

## Integration Patterns

### 1. Firestore Operations

**Before**:
```swift
func createHabit(name: String) async throws -> String {
    let habitId = UUID().uuidString
    try await firestore.collection("habits").document(habitId).setData([
        "name": name
    ])
    return habitId
}
```

**After**:
```swift
func createHabit(name: String) async throws -> String {
    let habitId = UUID().uuidString
    
    do {
        try await firestore.collection("habits").document(habitId).setData([
            "name": name
        ])
        
        // ✅ Log successful write
        HabittoLogger.logFirestoreWrite(
            "Created habit",
            collection: "habits",
            documentId: habitId,
            success: true
        )
        
        // ✅ Increment telemetry
        TelemetryService.shared.incrementFirestoreWrite(success: true)
        
        return habitId
        
    } catch {
        // ❌ Log failed write
        HabittoLogger.logFirestoreWrite(
            "Failed to create habit",
            collection: "habits",
            documentId: habitId,
            success: false,
            error: error
        )
        
        // ❌ Increment telemetry
        TelemetryService.shared.incrementFirestoreWrite(success: false)
        
        // Record non-fatal error
        CrashlyticsService.shared.recordError(error, additionalInfo: [
            "operation": "createHabit",
            "habitId": habitId
        ])
        
        throw error
    }
}
```

---

### 2. XP Awards

**Before**:
```swift
func awardXP(delta: Int, reason: String) async throws {
    try await repository.awardXP(delta: delta, reason: reason)
}
```

**After**:
```swift
func awardXP(delta: Int, reason: String) async throws {
    let userId = Auth.auth().currentUser?.uid ?? "guest"
    
    do {
        try await repository.awardXP(delta: delta, reason: reason)
        
        // ✅ Log successful XP award
        HabittoLogger.logXPAward(
            amount: delta,
            reason: reason,
            userId: userId,
            success: true
        )
        
        // Increment telemetry
        TelemetryService.shared.incrementXPAward(success: true)
        
    } catch {
        // ❌ Log failed XP award
        HabittoLogger.logXPAward(
            amount: delta,
            reason: reason,
            userId: userId,
            success: false,
            error: error
        )
        
        // Increment telemetry
        TelemetryService.shared.incrementXPAward(success: false)
        
        // Record non-fatal error
        CrashlyticsService.shared.recordError(error, additionalInfo: [
            "operation": "awardXP",
            "delta": delta,
            "reason": reason
        ])
        
        throw error
    }
}
```

---

### 3. Streak Updates

**Before**:
```swift
func calculateStreak(habitId: String, date: Date, isComplete: Bool) async throws {
    // ... streak calculation logic
    try await repository.updateStreak(habitId: habitId, current: newStreak, longest: longestStreak)
}
```

**After**:
```swift
func calculateStreak(habitId: String, date: Date, isComplete: Bool) async throws {
    do {
        // ... streak calculation logic
        try await repository.updateStreak(habitId: habitId, current: newStreak, longest: longestStreak)
        
        // ✅ Log successful streak update
        HabittoLogger.logStreakUpdate(
            habitId: habitId,
            current: newStreak,
            longest: longestStreak,
            action: isComplete ? "increment" : "reset",
            success: true
        )
        
        // Increment telemetry
        TelemetryService.shared.incrementStreakUpdate(success: true)
        
    } catch {
        // ❌ Log failed streak update
        HabittoLogger.logStreakUpdate(
            habitId: habitId,
            current: 0,
            longest: 0,
            action: "failed",
            success: false
        )
        
        // Increment telemetry
        TelemetryService.shared.incrementStreakUpdate(success: false)
        
        throw error
    }
}
```

---

### 4. Completions

**Before**:
```swift
func markComplete(habitId: String, at date: Date) async throws -> Int {
    return try await repository.incrementCompletion(habitId: habitId, date: date)
}
```

**After**:
```swift
func markComplete(habitId: String, at date: Date) async throws -> Int {
    do {
        let count = try await repository.incrementCompletion(habitId: habitId, date: date)
        
        // ✅ Log successful completion
        HabittoLogger.firestore.info("Marked habit complete | habit: \(habitId) | count: \(count)")
        
        // Increment telemetry
        TelemetryService.shared.incrementCompletion(success: true)
        
        return count
        
    } catch {
        // ❌ Log failed completion
        HabittoLogger.firestore.error("Failed to mark complete | habit: \(habitId) | error: \(error.localizedDescription)")
        
        // Increment telemetry
        TelemetryService.shared.incrementCompletion(success: false)
        
        throw error
    }
}
```

---

### 5. Transaction Retries

**Before**:
```swift
func incrementWithTransaction(habitId: String) async throws {
    try await firestore.runTransaction { transaction, errorPointer in
        // ... transaction logic
    }
}
```

**After**:
```swift
func incrementWithTransaction(habitId: String, maxRetries: Int = 3) async throws {
    var attempt = 0
    
    while attempt < maxRetries {
        do {
            try await firestore.runTransaction { transaction, errorPointer in
                // ... transaction logic
            }
            
            // Success - no need to retry
            if attempt > 0 {
                HabittoLogger.debug.info("Transaction succeeded after \(attempt) retries")
            }
            return
            
        } catch {
            attempt += 1
            
            if attempt < maxRetries {
                // Log retry
                HabittoLogger.logTransactionRetry(
                    operation: "incrementCompletion",
                    attempt: attempt,
                    maxAttempts: maxRetries
                )
                
                // Increment telemetry
                TelemetryService.shared.incrementTransactionRetry()
                
                // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 100_000_000))
            } else {
                // Max retries reached
                HabittoLogger.error.error("Transaction failed after \(maxRetries) retries | error: \(error.localizedDescription)")
                throw error
            }
        }
    }
}
```

---

### 6. Security Rules Denials

**Before**:
```swift
func writeToFirestore() async throws {
    try await firestore.collection("users").document(userId).setData(data)
}
```

**After**:
```swift
func writeToFirestore() async throws {
    do {
        try await firestore.collection("users").document(userId).setData(data)
        
    } catch let error as NSError {
        // Check if it's a permission denied error
        if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
            // Security rule denial
        HabittoLogger.logRulesDenied(
            operation: "write",
            path: "/users/\(userId)",
            reason: error.localizedDescription
        )
        
        // Increment telemetry
        TelemetryService.shared.incrementRulesDenial()
        }
        
        throw error
    }
}
```

---

### 7. Error Handling

**Before**:
```swift
func someOperation() async throws {
    do {
        try await performOperation()
    } catch {
        print("Error: \(error)")
        throw error
    }
}
```

**After**:
```swift
func someOperation() async throws {
    do {
        try await performOperation()
        
    } catch {
        // Log error with context
        HabittoLogger.logError(
            "Operation failed",
            error: error,
            context: [
                "operation": "someOperation",
                "timestamp": Date().timeIntervalSince1970
            ]
        )
        
        // Record to Crashlytics
        CrashlyticsService.shared.recordError(error, additionalInfo: [
            "flow": "critical_operation"
        ])
        
        throw error
    }
}
```

---

## Debug Overlay Integration

Add three-tap gesture to any view:

```swift
struct ContentView: View {
    @State private var showDebugOverlay = false
    
    var body: some View {
        NavigationStack {
            // Your content
        }
        .debugOverlay(isPresented: $showDebugOverlay)
        .withDebugGesture(showDebugOverlay: $showDebugOverlay)
    }
}
```

Or manually:

```swift
.onTapGesture(count: 3) {
    showDebugOverlay.toggle()
}
.sheet(isPresented: $showDebugOverlay) {
    DebugOverlay()
}
```

---

## Telemetry Monitoring

### In Code

```swift
let telemetry = TelemetryService.shared
let summary = telemetry.getSummary()

if summary.hasIssues {
    print("⚠️ Telemetry issues detected!")
    print("  Firestore success rate: \(summary.firestoreWrites.successPercentage)")
    print("  Rules denials: \(summary.rulesDenials)")
    print("  Transaction retries: \(summary.transactionRetries)")
}
```

### In UI

The DebugOverlay automatically displays all metrics with visual indicators:
- 🟢 Green: Success rate >= 95%
- 🟠 Orange: Success rate >= 80%
- 🔴 Red: Success rate < 80% or issues detected

---

## Best Practices

### 1. **Always Log Success and Failure**
```swift
// ✅ Good
if success {
    HabittoLogger.xp.info("XP awarded successfully")
    telemetry.incrementXPAward(success: true)
} else {
    HabittoLogger.xp.error("XP award failed")
    telemetry.incrementXPAward(success: false)
}

// ❌ Bad
if success {
    HabittoLogger.xp.info("XP awarded")
}
// Missing failure case!
```

### 2. **Include Context in Error Logs**
```swift
// ✅ Good
HabittoLogger.logError("Failed to sync", error: error, context: [
    "habitId": habitId,
    "userId": userId,
    "timestamp": Date().timeIntervalSince1970
])

// ❌ Bad
print("Error: \(error)")
```

### 3. **Use Appropriate Log Categories**
```swift
// ✅ Good
HabittoLogger.firestore.info("...")  // Firestore operations
HabittoLogger.xp.info("...")         // XP awards
HabittoLogger.streak.info("...")     // Streak updates
HabittoLogger.error.error("...")     // Error conditions

// ❌ Bad
print("...") // No categorization, hard to filter
```

### 4. **Monitor Telemetry in Production**
```swift
// Check for issues on app start
Task {
    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
    
    let summary = TelemetryService.shared.getSummary()
    if summary.hasIssues {
        // Alert developers or show warning to user
        CrashlyticsService.shared.log("⚠️ Telemetry issues detected")
    }
}
```

### 5. **Reset Counters Between Tests**
```swift
override func setUp() async throws {
    TelemetryService.shared.resetCounters()
}
```

---

## Testing Observability

### Unit Tests

```swift
func testObservabilityIntegration() async throws {
    // Given
    let telemetry = TelemetryService.shared
    telemetry.resetCounters()
    
    // When
    try await service.performOperation()
    
    // Then
    XCTAssertGreaterThan(telemetry.firestoreWritesOk, 0, "Should log Firestore writes")
    XCTAssertEqual(telemetry.firestoreWritesFailed, 0, "Should have no failures")
}
```

### Manual Testing

1. **Three-tap gesture** anywhere in the app
2. **View telemetry** in DebugOverlay
3. **Perform operations** (create habit, mark complete, etc.)
4. **Verify counters** update in real-time
5. **Check for issues** (red/orange indicators)

---

## Troubleshooting

### Telemetry Not Updating

**Problem**: Counters not incrementing  
**Solution**: Ensure you're calling `TelemetryService.shared.increment*()` methods

**Problem**: UI not updating  
**Solution**: Ensure `TelemetryService` is `@StateObject` or `@ObservedObject`

### Crashlytics Not Working

**Problem**: Crashes not appearing in Firebase Console  
**Solution**: Check that:
1. `GoogleService-Info.plist` exists
2. Running in RELEASE mode (disabled in DEBUG)
3. `CrashlyticsService.shared.enableCrashReporting()` was called

### Logs Not Appearing

**Problem**: Logger output not visible  
**Solution**: 
1. Check Console app (not Xcode console)
2. Filter by subsystem: `com.habitto.app`
3. Filter by category: `firestore_write`, `xp_award`, etc.

---

## Summary

**Key Benefits**:
- ✅ **Real-time monitoring** via DebugOverlay
- ✅ **Production debugging** via Crashlytics
- ✅ **Categorized logging** for easy filtering
- ✅ **In-memory counters** with no performance impact
- ✅ **Guarded initialization** (won't crash if Firebase not configured)

**Integration Checklist**:
- [ ] Add `HabittoLogger` calls for all operations
- [ ] Increment `TelemetryService` counters for success/failure
- [ ] Record non-fatal errors to `CrashlyticsService`
- [ ] Add three-tap gesture to main views
- [ ] Test DebugOverlay shows metrics
- [ ] Verify logs in Console app

For more details, see:
- `Core/Utils/HabittoLogger.swift` - Logger implementation
- `Core/Services/TelemetryService.swift` - Telemetry counters
- `Core/Services/CrashlyticsService.swift` - Crash reporting
- `Core/UI/Debug/DebugOverlay.swift` - Debug UI

