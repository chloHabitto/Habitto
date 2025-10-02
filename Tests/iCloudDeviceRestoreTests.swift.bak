import Foundation

// MARK: - iCloud Device Restore Tests
// Tests that prove backups + payload version yield consistent post-restore state

struct iCloudDeviceRestoreTests {
    
    // MARK: - Test Scenarios
    
    /// Test iCloud restore with backup files and payload version consistency
    func testiCloudRestoreWithBackups() async throws -> TestScenarioResult {
        let startTime = Date()
        
        let habitStore = CrashSafeHabitStore.shared
        
        // Create test data with specific version
        let testHabits = createTestHabits(count: 100)
        try await habitStore.saveHabits(testHabits)
        
        // Simulate iCloud restore scenario
        // 1. Main file is restored from iCloud
        // 2. Backup files are also restored
        // 3. UserDefaults cache is cleared (simulating new device)
        
        let _ = try Data(contentsOf: getMainFileURL())
        let _ = try Data(contentsOf: getBackupFileURL())
        
        // Clear UserDefaults cache (simulating new device)
        UserDefaults.standard.removeObject(forKey: "MigrationVersion:default_user")
        
        // Simulate restore by loading from main file
        let restoredHabits = await habitStore.loadHabits()
        
        // Verify consistency
        let success = restoredHabits.count == testHabits.count &&
                     restoredHabits.allSatisfy { habit in
                         testHabits.contains { $0.id == habit.id && $0.name == habit.name }
                     }
        
        return TestScenarioResult(
            scenario: .iCloudRestoreWithBackups,
            startTime: startTime,
            endTime: Date(),
            duration: Date().timeIntervalSince(startTime),
            success: success,
            error: success ? nil : "iCloud restore consistency check failed",
            metrics: TestScenarioResult.TestMetrics(
                recordsProcessed: restoredHabits.count,
                memoryUsage: 0,
                diskUsage: 0,
                networkCalls: 0,
                fileOperations: 2, // Read main + backup
                encryptionOperations: 0,
                validationChecks: 1
            ),
            severity: .high
        )
    }
    
    /// Test iCloud restore when main file is corrupted but backup is available
    func testiCloudRestoreFromBackup() async throws -> TestScenarioResult {
        let startTime = Date()
        
        let habitStore = CrashSafeHabitStore.shared
        
        // Create test data
        let testHabits = createTestHabits(count: 50)
        try await habitStore.saveHabits(testHabits)
        
        // Simulate corrupted main file
        try "corrupted main file data".write(to: getMainFileURL(), atomically: true, encoding: .utf8)
        
        // Clear UserDefaults cache
        UserDefaults.standard.removeObject(forKey: "MigrationVersion:default_user")
        
        // Load from backup (should happen automatically)
        let restoredHabits = await habitStore.loadHabits()
        
        // Verify we got data from backup
        let success = restoredHabits.count == testHabits.count &&
                     restoredHabits.allSatisfy { habit in
                         testHabits.contains { $0.id == habit.id && $0.name == habit.name }
                     }
        
        return TestScenarioResult(
            scenario: .iCloudRestoreFromBackup,
            startTime: startTime,
            endTime: Date(),
            duration: Date().timeIntervalSince(startTime),
            success: success,
            error: success ? nil : "iCloud restore from backup failed",
            metrics: TestScenarioResult.TestMetrics(
                recordsProcessed: restoredHabits.count,
                memoryUsage: 0,
                diskUsage: 0,
                networkCalls: 0,
                fileOperations: 2, // Read main (failed) + backup (success)
                encryptionOperations: 0,
                validationChecks: 1
            ),
            severity: .high
        )
    }
    
    /// Test iCloud restore with version mismatch handling
    func testiCloudRestoreVersionMismatch() async throws -> TestScenarioResult {
        let startTime = Date()
        
        let habitStore = CrashSafeHabitStore.shared
        
        // Create test data with specific version
        let testHabits = createTestHabits(count: 75)
        try await habitStore.saveHabits(testHabits)
        
        // Simulate version mismatch in restored data
        let mainFileURL = getMainFileURL()
        let mainFileData = try Data(contentsOf: mainFileURL)
        
        // Parse and modify version
        var container = try JSONDecoder().decode(HabitDataContainer.self, from: mainFileData)
        container = HabitDataContainer(
            habits: container.habits,
            version: "0.9.0", // Simulate older version
            completedSteps: container.completedMigrationSteps
        )
        
        // Write modified data back
        let modifiedData = try JSONEncoder().encode(container)
        try modifiedData.write(to: mainFileURL)
        
        // Clear UserDefaults cache
        UserDefaults.standard.removeObject(forKey: "MigrationVersion:default_user")
        
        // Load and verify migration is triggered
        let restoredHabits = await habitStore.loadHabits()
        
        // Check if migration was triggered by checking current version
        let currentVersion = await habitStore.getCurrentVersion()
        let success = restoredHabits.count == testHabits.count && currentVersion != "0.9.0"
        
        return TestScenarioResult(
            scenario: .iCloudRestoreVersionMismatch,
            startTime: startTime,
            endTime: Date(),
            duration: Date().timeIntervalSince(startTime),
            success: success,
            error: success ? nil : "Version mismatch handling failed",
            metrics: TestScenarioResult.TestMetrics(
                recordsProcessed: restoredHabits.count,
                memoryUsage: 0,
                diskUsage: 0,
                networkCalls: 0,
                fileOperations: 3, // Read, modify, write
                encryptionOperations: 0,
                validationChecks: 1
            ),
            severity: .medium
        )
    }
    
    /// Test iCloud restore with missing backup files
    func testiCloudRestoreMissingBackups() async throws -> TestScenarioResult {
        let startTime = Date()
        
        let habitStore = CrashSafeHabitStore.shared
        
        // Create test data
        let testHabits = createTestHabits(count: 25)
        try await habitStore.saveHabits(testHabits)
        
        // Simulate missing backup files (deleted during restore)
        try? FileManager.default.removeItem(at: getBackupFileURL())
        try? FileManager.default.removeItem(at: getBackup2FileURL())
        
        // Clear UserDefaults cache
        UserDefaults.standard.removeObject(forKey: "MigrationVersion:default_user")
        
        // Load should still work with just main file
        let restoredHabits = await habitStore.loadHabits()
        
        let success = restoredHabits.count == testHabits.count &&
                     restoredHabits.allSatisfy { habit in
                         testHabits.contains { $0.id == habit.id && $0.name == habit.name }
                     }
        
        return TestScenarioResult(
            scenario: .iCloudRestoreMissingBackups,
            startTime: startTime,
            endTime: Date(),
            duration: Date().timeIntervalSince(startTime),
            success: success,
            error: success ? nil : "iCloud restore with missing backups failed",
            metrics: TestScenarioResult.TestMetrics(
                recordsProcessed: restoredHabits.count,
                memoryUsage: 0,
                diskUsage: 0,
                networkCalls: 0,
                fileOperations: 1, // Read main only
                encryptionOperations: 0,
                validationChecks: 1
            ),
            severity: .medium
        )
    }
    
    /// Test iCloud restore with corrupted payload version
    func testiCloudRestoreCorruptedVersion() async throws -> TestScenarioResult {
        let startTime = Date()
        
        let habitStore = CrashSafeHabitStore.shared
        
        // Create test data
        let testHabits = createTestHabits(count: 30)
        try await habitStore.saveHabits(testHabits)
        
        // Simulate corrupted version in payload
        let mainFileURL = getMainFileURL()
        let mainFileData = try Data(contentsOf: mainFileURL)
        
        // Parse and corrupt version
        var container = try JSONDecoder().decode(HabitDataContainer.self, from: mainFileData)
        container = HabitDataContainer(
            habits: container.habits,
            version: "", // Corrupted version
            completedSteps: container.completedMigrationSteps
        )
        
        // Write corrupted data back
        let corruptedData = try JSONEncoder().encode(container)
        try corruptedData.write(to: mainFileURL)
        
        // Clear UserDefaults cache
        UserDefaults.standard.removeObject(forKey: "MigrationVersion:default_user")
        
        // Load should handle corrupted version gracefully
        let restoredHabits = await habitStore.loadHabits()
        
        // Should still get the habits even with corrupted version
        let success = restoredHabits.count == testHabits.count
        
        return TestScenarioResult(
            scenario: .iCloudRestoreCorruptedVersion,
            startTime: startTime,
            endTime: Date(),
            duration: Date().timeIntervalSince(startTime),
            success: success,
            error: success ? nil : "Corrupted version handling failed",
            metrics: TestScenarioResult.TestMetrics(
                recordsProcessed: restoredHabits.count,
                memoryUsage: 0,
                diskUsage: 0,
                networkCalls: 0,
                fileOperations: 2, // Read, write
                encryptionOperations: 0,
                validationChecks: 1
            ),
            severity: .medium
        )
    }
    
    // MARK: - Helper Methods
    
    private func getMainFileURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("habits.json")
    }
    
    private func getBackupFileURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("habits_backup.json")
    }
    
    private func getBackup2FileURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("habits_backup2.json")
    }
    
    private func createTestHabits(count: Int, prefix: String = "Restore") -> [Habit] {
        return (0..<count).map { index in
            createTestHabit(name: "\(prefix)Habit\(index)")
        }
    }
    
    private func createTestHabit(name: String) -> Habit {
        return Habit(
            id: UUID(),
            name: name,
            description: "Test habit for iCloud restore testing",
            icon: "star",
            color: .blue,
            habitType: .formation,
            schedule: "daily",
            goal: "1",
            reminder: "9:00 AM",
            startDate: Date(),
            endDate: nil,
            isCompleted: false,
            streak: 0,
            createdAt: Date(),
            reminders: [],
            baseline: 0,
            target: 0,
            completionHistory: [:],
            difficultyHistory: [:],
            actualUsage: [:]
        )
    }
}

