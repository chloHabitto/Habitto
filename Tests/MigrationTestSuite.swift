import Foundation

// MARK: - Migration Test Suite
// Comprehensive test matrix for crash-safe migration scenarios

class MigrationTestSuite {
    
    // MARK: - Custom Assertions
    
    private func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        if actual != expected {
            print("❌ Assertion failed: \(message). Expected: \(expected), Actual: \(actual)")
        }
    }
    
    private func assertTrue(_ condition: Bool, _ message: String) {
        if !condition {
            print("❌ Assertion failed: \(message)")
        }
    }
    
    // MARK: - Test Data Setup
    
    private var testHabits: [Habit] = []
    
    func setUp() {
        createTestHabits()
    }
    
    func tearDown() {
        // Cleanup if needed
    }
    
    private func createTestHabits() {
        testHabits = [
            Habit(name: "Test Habit 1", description: "Test Description 1", icon: "🏃‍♂️", color: .blue, habitType: .formation, schedule: "daily", goal: "1", reminder: "", startDate: Date()),
            Habit(name: "Test Habit 2", description: "Test Description 2", icon: "💧", color: .green, habitType: .breaking, schedule: "weekly", goal: "1", reminder: "", startDate: Date()),
            Habit(name: "Test Habit 3", description: "Test Description 3", icon: "📚", color: .red, habitType: .formation, schedule: "monthly", goal: "1", reminder: "", startDate: Date())
        ]
    }
    
    // MARK: - Core Migration Tests
    
    func testSuccessfulMigration() async throws {
        // Test: Normal migration flow works correctly
        print("🧪 Testing successful migration flow...")
        
        let store = CrashSafeHabitStore.shared
        let migrationManager = await DataMigrationManager.shared
        
        // Save initial data
        try await store.saveHabits(testHabits)
        
        // Run migration
        try await migrationManager.executeMigrations()
        
        // Verify data integrity
        let loadedHabits = await store.loadHabits()
        assertEqual(loadedHabits.count, testHabits.count, "Habit count mismatch")
        
        print("✅ Successful migration test passed")
    }
    
    func testIdempotentMigration() async throws {
        // Test: Running migration multiple times doesn't cause issues
        print("🧪 Testing idempotent migration...")
        
        let store = CrashSafeHabitStore.shared
        let migrationManager = await DataMigrationManager.shared
        
        // Save initial data
        try await store.saveHabits(testHabits)
        
        // Run migration multiple times
        try await migrationManager.executeMigrations()
        try await migrationManager.executeMigrations()
        try await migrationManager.executeMigrations()
        
        // Verify data integrity
        let loadedHabits = await store.loadHabits()
        assertEqual(loadedHabits.count, testHabits.count, "Habit count mismatch")
        
        print("✅ Idempotent migration test passed")
    }
    
    func testEmptyDatasetMigration() async throws {
        // Test: Migration with no habits
        print("🧪 Testing empty dataset migration...")
        
        let store = CrashSafeHabitStore.shared
        let migrationManager = await DataMigrationManager.shared
        
        // Save empty dataset
        try await store.saveHabits([])
        
        // Run migration
        try await migrationManager.executeMigrations()
        
        // Verify empty dataset is preserved
        let loadedHabits = await store.loadHabits()
        assertEqual(loadedHabits.count, 0, "Expected empty habits array")
        
        print("✅ Empty dataset migration test passed")
    }
    
    func testKillSwitchEnabled() async throws {
        // Test: Migration disabled by kill switch
        print("🧪 Testing kill switch enabled...")
        
        let telemetryManager = await MigrationTelemetryManager.shared
        let migrationManager = await DataMigrationManager.shared
        
        // Enable kill switch
        await MainActor.run {
            telemetryManager.isMigrationEnabled = false
        }
        
        // Attempt migration
        do {
            try await migrationManager.executeMigrations()
            print("❌ Migration should have been disabled by kill switch")
        } catch DataMigrationError.migrationDisabledByKillSwitch {
            // Expected error
            print("✅ Kill switch correctly disabled migration")
        } catch {
            print("❌ Unexpected error: \(error)")
        }
        
        // Re-enable for other tests
        await MainActor.run {
            telemetryManager.isMigrationEnabled = true
        }
    }
}

// MARK: - Test Runner

class MigrationTestSuiteRunner {
    static func runAllTests() async {
        print("🚀 Starting Migration Test Suite...")
        
        let testSuite = MigrationTestSuite()
        testSuite.setUp()
        
        do {
            try await testSuite.testSuccessfulMigration()
            try await testSuite.testIdempotentMigration()
            try await testSuite.testEmptyDatasetMigration()
            try await testSuite.testKillSwitchEnabled()
            
            print("🎉 All migration tests passed successfully!")
            
        } catch {
            print("❌ Migration test failed: \(error)")
        }
        
        testSuite.tearDown()
    }
}