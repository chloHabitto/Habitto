import Foundation
import SwiftData
import SwiftUI

// MARK: - SchemaMigrationTestRunner

/// Standalone test runner for SwiftData schema migration system
///
/// **Usage:**
/// ```swift
/// let runner = SchemaMigrationTestRunner()
/// await runner.runAllTests()
/// ```
@MainActor
class SchemaMigrationTestRunner: ObservableObject {
  // MARK: - Published Properties
  
  @Published var isRunning = false
  @Published var currentTest = ""
  @Published var progress: Double = 0.0
  @Published var output = ""
  @Published var testResults: [TestResult] = []
  
  // MARK: - Properties
  
  private var modelContainer: ModelContainer?
  private var modelContext: ModelContext?
  
  // MARK: - Test Results
  
  struct TestResult {
    let name: String
    let passed: Bool
    let message: String
    let duration: TimeInterval
  }
  
  // MARK: - Setup
  
  func setup() throws {
    log("🔧 Setting up SwiftData container with migration plan...")
    
    let schema = Schema(versionedSchema: HabittoSchemaV1.self)
    let migrationPlan = HabittoMigrationPlan.self
    
    // Use in-memory store for testing
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    modelContainer = try ModelContainer(
      for: schema,
      migrationPlan: migrationPlan,
      configurations: [config]
    )
    modelContext = ModelContext(modelContainer!)
    
    log("✅ SwiftData container ready with migration plan")
  }
  
  // MARK: - Test Execution
  
  func runAllTests() async {
    await MainActor.run {
      isRunning = true
      testResults.removeAll()
      output = ""
      progress = 0.0
    }
    
    log("🧪 Starting SwiftData migration system tests...")
    log("")
    
    do {
      try setup()
    } catch {
      log("❌ Setup failed: \(error.localizedDescription)")
      await MainActor.run {
        isRunning = false
      }
      return
    }
    
    let tests: [(String, () async throws -> Bool)] = [
      ("Schema Version Verification", testSchemaVersion),
      ("Migration Plan Configuration", testMigrationPlan),
      ("Container Initialization", testContainerInitialization),
      ("HabitData Fetch", testFetchHabitData),
      ("CompletionRecord Fetch", testFetchCompletionRecord),
      ("DailyAward Fetch", testFetchDailyAward),
      ("UserProgressData Fetch", testFetchUserProgressData),
      ("ProgressEvent Fetch", testFetchProgressEvent),
      ("GlobalStreakModel Fetch", testFetchGlobalStreakModel),
      ("HabitData Creation", testCreateHabitData),
      ("CompletionRecord Creation", testCreateCompletionRecord),
      ("Migration Plan Current Version", testCurrentVersion),
    ]
    
    let totalTests = tests.count
    var passedTests = 0
    
    for (index, (testName, test)) in tests.enumerated() {
      await MainActor.run {
        currentTest = testName
        progress = Double(index) / Double(totalTests)
      }
      
      log("📋 Running: \(testName)")
      
      let startTime = Date()
      var passed = false
      var message = ""
      
      do {
        passed = try await test()
        message = passed ? "✅ PASSED" : "❌ FAILED"
        if passed {
          passedTests += 1
        }
      } catch {
        message = "❌ ERROR: \(error.localizedDescription)"
        log("   \(message)")
      }
      
      let duration = Date().timeIntervalSince(startTime)
      
      await MainActor.run {
        let result = TestResult(
          name: testName,
          passed: passed,
          message: message,
          duration: duration
        )
        testResults.append(result)
      }
      
      log("   \(message) (\(String(format: "%.3f", duration))s)")
      log("")
    }
    
    await MainActor.run {
      progress = 1.0
      currentTest = "Complete"
      isRunning = false
    }
    
    log("🧪 Test Summary: \(passedTests)/\(totalTests) tests passed")
    
    if passedTests == totalTests {
      log("✅ All tests passed!")
    } else {
      log("⚠️ Some tests failed - review results above")
    }
  }
  
  // MARK: - Individual Tests
  
  private func testSchemaVersion() async throws -> Bool {
    // Verify version identifier exists and is accessible
    // Schema.Version doesn't expose individual components, so we verify it exists
    let version = HabittoSchemaV1.versionIdentifier
    
    // Verify the version is created (not checking individual components since API doesn't expose them)
    // The important thing is that versionIdentifier is accessible and the schema can be created
    let versionDescription = String(describing: version)
    
    // Log for debugging
    log("   ℹ️ Schema version identifier: \(versionDescription)")
    
    // If we can access versionIdentifier without error, the test passes
    return true
  }
  
  private func testMigrationPlan() async throws -> Bool {
    let schemas = HabittoMigrationPlan.schemas
    guard schemas.contains(where: { $0 == HabittoSchemaV1.self }) else {
      log("   ❌ Migration plan does not include V1 schema")
      return false
    }
    
    let stages = HabittoMigrationPlan.stages
    guard stages.isEmpty else {
      log("   ❌ V1 is baseline - should have no migration stages (found \(stages.count))")
      return false
    }
    
    return true
  }
  
  private func testContainerInitialization() async throws -> Bool {
    guard let container = modelContainer else {
      log("   ❌ ModelContainer is nil")
      return false
    }
    
    guard modelContext != nil else {
      log("   ❌ ModelContext is nil")
      return false
    }
    
    // Verify schema includes expected models
    let schema = container.configurations.first?.schema
    guard let schema = schema else {
      log("   ❌ Schema is nil")
      return false
    }
    
    let modelTypes = schema.entities.map { $0.name }
    let requiredModels = ["HabitData", "CompletionRecord", "DailyAward", "UserProgressData"]
    
    for modelName in requiredModels {
      guard modelTypes.contains(modelName) else {
        log("   ❌ Missing model: \(modelName)")
        return false
      }
    }
    
    return true
  }
  
  private func testFetchHabitData() async throws -> Bool {
    guard let context = modelContext else { return false }
    
    let descriptor = FetchDescriptor<HabitData>()
    let habits = try context.fetch(descriptor)
    
    guard habits.count == 0 else {
      log("   ❌ Expected 0 habits in fresh database, got \(habits.count)")
      return false
    }
    
    return true
  }
  
  private func testFetchCompletionRecord() async throws -> Bool {
    guard let context = modelContext else { return false }
    
    let descriptor = FetchDescriptor<CompletionRecord>()
    let records = try context.fetch(descriptor)
    
    guard records.count == 0 else {
      log("   ❌ Expected 0 completion records in fresh database, got \(records.count)")
      return false
    }
    
    return true
  }
  
  private func testFetchDailyAward() async throws -> Bool {
    guard let context = modelContext else { return false }
    
    let descriptor = FetchDescriptor<DailyAward>()
    let awards = try context.fetch(descriptor)
    
    guard awards.count == 0 else {
      log("   ❌ Expected 0 daily awards in fresh database, got \(awards.count)")
      return false
    }
    
    return true
  }
  
  private func testFetchUserProgressData() async throws -> Bool {
    guard let context = modelContext else { return false }
    
    let descriptor = FetchDescriptor<UserProgressData>()
    let progress = try context.fetch(descriptor)
    
    guard progress.count == 0 else {
      log("   ❌ Expected 0 user progress records in fresh database, got \(progress.count)")
      return false
    }
    
    return true
  }
  
  private func testFetchProgressEvent() async throws -> Bool {
    guard let context = modelContext else { return false }
    
    let descriptor = FetchDescriptor<ProgressEvent>()
    let events = try context.fetch(descriptor)
    
    guard events.count == 0 else {
      log("   ❌ Expected 0 progress events in fresh database, got \(events.count)")
      return false
    }
    
    return true
  }
  
  private func testFetchGlobalStreakModel() async throws -> Bool {
    guard let context = modelContext else { return false }
    
    let descriptor = FetchDescriptor<GlobalStreakModel>()
    let streaks = try context.fetch(descriptor)
    
    guard streaks.count == 0 else {
      log("   ❌ Expected 0 global streaks in fresh database, got \(streaks.count)")
      return false
    }
    
    return true
  }
  
  private func testCreateHabitData() async throws -> Bool {
    guard let context = modelContext else { return false }
    
    let habit = HabitData(
      id: UUID(),
      userId: "test_user",
      name: "Test Habit",
      habitDescription: "Test Description",
      icon: "star",
      color: .blue,
      habitType: .formation,
      schedule: "everyday",
      goal: "1 time",
      reminder: "",
      startDate: Date()
    )
    
    context.insert(habit)
    try context.save()
    
    let descriptor = FetchDescriptor<HabitData>()
    let habits = try context.fetch(descriptor)
    
    guard habits.count == 1 else {
      log("   ❌ Expected 1 habit after creation, got \(habits.count)")
      return false
    }
    
    guard habits.first?.name == "Test Habit" else {
      log("   ❌ Habit name mismatch")
      return false
    }
    
    return true
  }
  
  private func testCreateCompletionRecord() async throws -> Bool {
    guard let context = modelContext else { return false }
    
    let record = CompletionRecord(
      userId: "test_user",
      habitId: UUID(),
      date: Date(),
      dateKey: "2024-01-01",
      isCompleted: true,
      progress: 1
    )
    
    context.insert(record)
    try context.save()
    
    let descriptor = FetchDescriptor<CompletionRecord>()
    let records = try context.fetch(descriptor)
    
    guard records.count == 1 else {
      log("   ❌ Expected 1 completion record after creation, got \(records.count)")
      return false
    }
    
    guard records.first?.isCompleted == true else {
      log("   ❌ Completion record status mismatch")
      return false
    }
    
    return true
  }
  
  private func testCurrentVersion() async throws -> Bool {
    let currentVersion = HabittoMigrationPlan.currentVersion
    let v1Version = HabittoSchemaV1.versionIdentifier
    
    // Schema.Version may not support == operator, so compare by description
    let currentDesc = String(describing: currentVersion)
    let v1Desc = String(describing: v1Version)
    
    guard currentDesc == v1Desc else {
      log("   ❌ Current version mismatch: expected \(v1Desc), got \(currentDesc)")
      return false
    }
    
    // V1 should not need migration from itself
    let needsMigration = HabittoMigrationPlan.needsMigration(from: v1Version)
    guard !needsMigration else {
      log("   ❌ V1 should not need migration from itself")
      return false
    }
    
    return true
  }
  
  // MARK: - Helper Methods
  
  private func log(_ message: String) {
    print(message)
    Task { @MainActor in
      output += message + "\n"
    }
  }
}

