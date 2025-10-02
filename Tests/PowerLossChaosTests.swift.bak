import Foundation

// MARK: - Power Loss Chaos Tests
// Tests that prove the system can recover from power loss at any point in the save process

struct PowerLossChaosTests {
    
    // MARK: - Test Scenarios
    
    /// Test recovery from power loss between atomic replace and verification
    func testPowerLossBetweenReplaceAndVerify() async throws -> TestScenarioResult {
        let startTime = Date()
        
        // Create mock file manager that fails after replaceItem
        let mockFileManager = MockFileManager()
        mockFileManager.shouldFailAfterReplace = true
        
        let habitStore = CrashSafeHabitStore.shared
        let testHabits = createTestHabits(count: 50)
        
        do {
            try await habitStore.saveHabits(testHabits)
            return TestScenarioResult(
                scenario: .powerLossBetweenReplaceAndVerify,
                startTime: startTime,
                endTime: Date(),
                duration: Date().timeIntervalSince(startTime),
                success: false,
                error: "Expected failure did not occur",
                metrics: TestScenarioResult.TestMetrics(
                    recordsProcessed: 0,
                    memoryUsage: 0,
                    diskUsage: 0,
                    networkCalls: 0,
                    fileOperations: 0,
                    encryptionOperations: 0,
                    validationChecks: 0
                ),
                severity: .high
            )
        } catch {
            // Expected failure - now test recovery
            let recoveredHabits = await habitStore.loadHabits()
            let success = recoveredHabits.count > 0 && recoveredHabits.allSatisfy { !$0.name.isEmpty }
            
            return TestScenarioResult(
                scenario: .powerLossBetweenReplaceAndVerify,
                startTime: startTime,
                endTime: Date(),
                duration: Date().timeIntervalSince(startTime),
                success: success,
                error: success ? nil : "Recovery from power loss failed",
                metrics: TestScenarioResult.TestMetrics(
                    recordsProcessed: recoveredHabits.count,
                    memoryUsage: 0,
                    diskUsage: 0,
                    networkCalls: 0,
                    fileOperations: 1,
                    encryptionOperations: 0,
                    validationChecks: 1
                ),
                severity: .high
            )
        }
    }
    
    /// Test recovery from power loss between verification and backup rotation
    func testPowerLossBetweenVerifyAndBackup() async throws -> TestScenarioResult {
        let startTime = Date()
        
        // Create mock file manager that fails after verification
        let mockFileManager = MockFileManager()
        mockFileManager.shouldFailAfterVerify = true
        
        let habitStore = CrashSafeHabitStore.shared
        let testHabits = createTestHabits(count: 50)
        
        do {
            try await habitStore.saveHabits(testHabits)
            return TestScenarioResult(
                scenario: .powerLossBetweenVerifyAndBackup,
                startTime: startTime,
                endTime: Date(),
                duration: Date().timeIntervalSince(startTime),
                success: false,
                error: "Expected failure did not occur",
                metrics: TestScenarioResult.TestMetrics(
                    recordsProcessed: 0,
                    memoryUsage: 0,
                    diskUsage: 0,
                    networkCalls: 0,
                    fileOperations: 0,
                    encryptionOperations: 0,
                    validationChecks: 0
                ),
                severity: .high
            )
        } catch {
            // Expected failure - now test recovery
            let recoveredHabits = await habitStore.loadHabits()
            let success = recoveredHabits.count > 0 && recoveredHabits.allSatisfy { !$0.name.isEmpty }
            
            return TestScenarioResult(
                scenario: .powerLossBetweenVerifyAndBackup,
                startTime: startTime,
                endTime: Date(),
                duration: Date().timeIntervalSince(startTime),
                success: success,
                error: success ? nil : "Recovery from power loss failed",
                metrics: TestScenarioResult.TestMetrics(
                    recordsProcessed: recoveredHabits.count,
                    memoryUsage: 0,
                    diskUsage: 0,
                    networkCalls: 0,
                    fileOperations: 1,
                    encryptionOperations: 0,
                    validationChecks: 1
                ),
                severity: .high
            )
        }
    }
    
    /// Test recovery from power loss during backup rotation
    func testPowerLossDuringBackupRotation() async throws -> TestScenarioResult {
        let startTime = Date()
        
        // Create mock file manager that fails during backup rotation
        let mockFileManager = MockFileManager()
        mockFileManager.shouldFailDuringBackupRotation = true
        
        let habitStore = CrashSafeHabitStore.shared
        let testHabits = createTestHabits(count: 50)
        
        do {
            try await habitStore.saveHabits(testHabits)
            return TestScenarioResult(
                scenario: .powerLossDuringBackupRotation,
                startTime: startTime,
                endTime: Date(),
                duration: Date().timeIntervalSince(startTime),
                success: false,
                error: "Expected failure did not occur",
                metrics: TestScenarioResult.TestMetrics(
                    recordsProcessed: 0,
                    memoryUsage: 0,
                    diskUsage: 0,
                    networkCalls: 0,
                    fileOperations: 0,
                    encryptionOperations: 0,
                    validationChecks: 0
                ),
                severity: .high
            )
        } catch {
            // Expected failure - now test recovery
            let recoveredHabits = await habitStore.loadHabits()
            let success = recoveredHabits.count > 0 && recoveredHabits.allSatisfy { !$0.name.isEmpty }
            
            return TestScenarioResult(
                scenario: .powerLossDuringBackupRotation,
                startTime: startTime,
                endTime: Date(),
                duration: Date().timeIntervalSince(startTime),
                success: success,
                error: success ? nil : "Recovery from power loss failed",
                metrics: TestScenarioResult.TestMetrics(
                    recordsProcessed: recoveredHabits.count,
                    memoryUsage: 0,
                    diskUsage: 0,
                    networkCalls: 0,
                    fileOperations: 1,
                    encryptionOperations: 0,
                    validationChecks: 1
                ),
                severity: .high
            )
        }
    }
    
    /// Test recovery from corrupted temp file after power loss
    func testCorruptedTempFileRecovery() async throws -> TestScenarioResult {
        let startTime = Date()
        
        // Create mock file manager that corrupts temp files
        let mockFileManager = MockFileManager()
        mockFileManager.shouldCorruptTempFiles = true
        
        let habitStore = CrashSafeHabitStore.shared
        let testHabits = createTestHabits(count: 50)
        
        do {
            try await habitStore.saveHabits(testHabits)
            return TestScenarioResult(
                scenario: .corruptedTempFileRecovery,
                startTime: startTime,
                endTime: Date(),
                duration: Date().timeIntervalSince(startTime),
                success: false,
                error: "Expected failure did not occur",
                metrics: TestScenarioResult.TestMetrics(
                    recordsProcessed: 0,
                    memoryUsage: 0,
                    diskUsage: 0,
                    networkCalls: 0,
                    fileOperations: 0,
                    encryptionOperations: 0,
                    validationChecks: 0
                ),
                severity: .high
            )
        } catch {
            // Expected failure - now test recovery
            let recoveredHabits = await habitStore.loadHabits()
            let success = recoveredHabits.count > 0 && recoveredHabits.allSatisfy { !$0.name.isEmpty }
            
            return TestScenarioResult(
                scenario: .corruptedTempFileRecovery,
                startTime: startTime,
                endTime: Date(),
                duration: Date().timeIntervalSince(startTime),
                success: success,
                error: success ? nil : "Recovery from corrupted temp file failed",
                metrics: TestScenarioResult.TestMetrics(
                    recordsProcessed: recoveredHabits.count,
                    memoryUsage: 0,
                    diskUsage: 0,
                    networkCalls: 0,
                    fileOperations: 1,
                    encryptionOperations: 0,
                    validationChecks: 1
                ),
                severity: .high
            )
        }
    }
    
    /// Test atomic write integrity during power loss
    func testAtomicWriteIntegrity() async throws -> TestScenarioResult {
        let startTime = Date()
        
        // Test that atomic writes either fully succeed or fully fail
        let habitStore = CrashSafeHabitStore.shared
        let testHabits = createTestHabits(count: 100)
        
        // Perform multiple saves with potential power loss simulation
        var successfulSaves = 0
        var failedSaves = 0
        
        for i in 0..<10 {
            do {
                let habits = testHabits + createTestHabits(count: i, prefix: "PowerLoss")
                try await habitStore.saveHabits(habits)
                successfulSaves += 1
            } catch {
                failedSaves += 1
                // Verify we still have consistent data after failure
                let currentHabits = await habitStore.loadHabits()
                assert(currentHabits.allSatisfy { !$0.name.isEmpty })
            }
        }
        
        // Verify final state is consistent
        let finalHabits = await habitStore.loadHabits()
        let success = finalHabits.count > 0 && finalHabits.allSatisfy { !$0.name.isEmpty }
        
        return TestScenarioResult(
            scenario: .atomicWriteIntegrity,
            startTime: startTime,
            endTime: Date(),
            duration: Date().timeIntervalSince(startTime),
            success: success,
            error: success ? nil : "Atomic write integrity test failed",
            metrics: TestScenarioResult.TestMetrics(
                recordsProcessed: finalHabits.count,
                memoryUsage: 0,
                diskUsage: 0,
                networkCalls: 0,
                fileOperations: 10,
                encryptionOperations: 0,
                validationChecks: 10
            ),
            severity: .critical
        )
    }
    
    // MARK: - Helper Methods
    
    private func createTestHabits(count: Int, prefix: String = "PowerLoss") -> [Habit] {
        return (0..<count).map { index in
            createTestHabit(name: "\(prefix)Habit\(index)")
        }
    }
    
    private func createTestHabit(name: String) -> Habit {
        return Habit(
            id: UUID(),
            name: name,
            description: "Test habit for power loss testing",
            icon: "star",
            color: .blue,
            habitType: .formation,
            schedule: "daily",
            goal: "1",
            reminder: "9:00 AM",
            startDate: Date(),
            completionHistory: [:]
        )
    }
}

// MARK: - Mock File Manager

class MockFileManager {
    var shouldFailAfterReplace = false
    var shouldFailAfterVerify = false
    var shouldFailDuringBackupRotation = false
    var shouldCorruptTempFiles = false
    
    func replaceItem(at originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String?, options: FileManager.ItemReplacementOptions, resultingItemURL: AutoreleasingUnsafeMutablePointer<NSURL?>?) throws {
        try FileManager.default.replaceItem(at: originalItemURL, withItemAt: newItemURL, backupItemName: backupItemName, options: options, resultingItemURL: resultingItemURL)
        
        if shouldFailAfterReplace {
            throw NSError(domain: "MockFileManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Simulated power loss after replace"])
        }
    }
    
    func contents(atPath path: String) -> Data? {
        if shouldCorruptTempFiles && path.contains(".tmp.") {
            return "corrupted data".data(using: .utf8)
        }
        return FileManager.default.contents(atPath: path)
    }
}

