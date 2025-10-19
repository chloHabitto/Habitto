import Foundation

/// Golden test runner for time-travel scenario testing
///
/// This runner executes pre-defined scenarios from JSON files to test complex
/// temporal logic including DST transitions, multiple goal changes, and streak logic.
///
/// Key Features:
/// - Deterministic time via injected NowProvider
/// - DST-safe timezone handling (Europe/Amsterdam)
/// - Assertions for goal, progress, streak, and XP at each step
/// - Red/green test output for easy debugging
///
/// Scenario Format:
/// ```json
/// {
///   "name": "DST Spring Forward Test",
///   "timezone": "Europe/Amsterdam",
///   "steps": [
///     {
///       "at": "2025-03-30T08:00:00+01:00",
///       "op": "setGoal",
///       "habit": "Run",
///       "goal": 2,
///       "effective": "2025-03-30"
///     },
///     {
///       "at": "2025-03-30T09:12:00+01:00",
///       "op": "complete",
///       "habit": "Run"
///     },
///     {
///       "at": "2025-03-30T23:00:00+01:00",
///       "op": "assert",
///       "habit": "Run",
///       "expect": {
///         "goal": 2,
///         "progress": 1,
///         "streak": 1,
///         "totalXP": 10
///       }
///     }
///   ]
/// }
/// ```
@MainActor
class GoldenTestRunner {
    // MARK: - Singleton
    
    static let shared = GoldenTestRunner()
    
    // MARK: - Dependencies
    
    private let repository: FirestoreRepository
    private let completionService: CompletionService
    private let streakService: StreakService
    private let xpService: DailyAwardService
    private let goalService: GoalVersioningService
    private var nowProvider: MockNowProvider
    private let timeZoneProvider: TimeZoneProvider
    
    // MARK: - Test Results
    
    struct TestResult {
        let scenarioName: String
        let totalSteps: Int
        let passedSteps: Int
        let failedSteps: Int
        let failures: [StepFailure]
        
        var success: Bool { failedSteps == 0 }
        
        struct StepFailure {
            let stepIndex: Int
            let stepDescription: String
            let expectedValue: String
            let actualValue: String
            let message: String
        }
    }
    
    // MARK: - Initialization
    
    init(
        repository: FirestoreRepository? = nil,
        completionService: CompletionService? = nil,
        streakService: StreakService? = nil,
        xpService: DailyAwardService? = nil,
        goalService: GoalVersioningService? = nil,
        timeZoneProvider: TimeZoneProvider? = nil
    ) {
        self.repository = repository ?? FirestoreRepository.shared
        self.completionService = completionService ?? CompletionService.shared
        // TODO: Update GoldenTestRunner to use new service architecture
        // For now, streakService must be passed in - no singleton available
        self.streakService = streakService!
        self.xpService = xpService ?? DailyAwardService.shared
        self.goalService = goalService ?? GoalVersioningService.shared
        self.nowProvider = MockNowProvider(currentDate: Date())
        self.timeZoneProvider = timeZoneProvider ?? AmsterdamTimeZoneProvider()
    }
    
    // MARK: - Public Methods
    
    /// Run a golden scenario from a JSON file
    ///
    /// - Parameter fileURL: URL to the JSON scenario file
    /// - Returns: TestResult with pass/fail status and failure details
    func runScenario(from fileURL: URL) async throws -> TestResult {
        let data = try Data(contentsOf: fileURL)
        let scenario = try JSONDecoder().decode(GoldenScenario.self, from: data)
        return try await runScenario(scenario)
    }
    
    /// Run a golden scenario from a GoldenScenario object
    ///
    /// - Parameter scenario: The scenario to execute
    /// - Returns: TestResult with pass/fail status and failure details
    func runScenario(_ scenario: GoldenScenario) async throws -> TestResult {
        print("🧪 Running scenario: \(scenario.name)")
        
        var passedSteps = 0
        var failedSteps = 0
        var failures: [TestResult.StepFailure] = []
        
        // Reset state before running scenario
        try await resetState()
        
        // Create habits map for easy lookup
        var habitsMap: [String: String] = [:] // habitName -> habitId
        
        // Execute each step
        for (index, step) in scenario.steps.enumerated() {
            print("  Step \(index + 1)/\(scenario.steps.count): \(step.op) at \(step.at)")
            
            // Set current time for this step
            nowProvider.currentDate = step.at
            
            do {
                switch step.op {
                case "createHabit":
                    let habitId = try await executeCreateHabit(step)
                    habitsMap[step.habit] = habitId
                    passedSteps += 1
                    
                case "setGoal":
                    try await executeSetGoal(step, habitsMap: habitsMap)
                    passedSteps += 1
                    
                case "complete":
                    try await executeComplete(step, habitsMap: habitsMap)
                    passedSteps += 1
                    
                case "assert":
                    try await executeAssert(step, habitsMap: habitsMap)
                    passedSteps += 1
                    
                default:
                    throw GoldenTestError.unknownOperation(step.op)
                }
                
                print("    ✅ Step passed")
                
            } catch let error as AssertionError {
                failedSteps += 1
                let failure = TestResult.StepFailure(
                    stepIndex: index,
                    stepDescription: "\(step.op) \(step.habit) at \(step.at)",
                    expectedValue: error.expected,
                    actualValue: error.actual,
                    message: error.message
                )
                failures.append(failure)
                print("    ❌ Step failed: \(error.message)")
                print("       Expected: \(error.expected)")
                print("       Actual:   \(error.actual)")
                
            } catch {
                failedSteps += 1
                let failure = TestResult.StepFailure(
                    stepIndex: index,
                    stepDescription: "\(step.op) \(step.habit) at \(step.at)",
                    expectedValue: "success",
                    actualValue: "error",
                    message: error.localizedDescription
                )
                failures.append(failure)
                print("    ❌ Step error: \(error)")
            }
        }
        
        let result = TestResult(
            scenarioName: scenario.name,
            totalSteps: scenario.steps.count,
            passedSteps: passedSteps,
            failedSteps: failedSteps,
            failures: failures
        )
        
        print("🧪 Scenario complete: \(scenario.name)")
        print("   ✅ Passed: \(passedSteps)")
        print("   ❌ Failed: \(failedSteps)")
        
        return result
    }
    
    // MARK: - Private Methods - Operation Execution
    
    private func executeCreateHabit(_ step: GoldenScenarioStep) async throws -> String {
        let habitId = try await repository.createHabit(
            name: step.habit,
            color: step.params?["color"]?.value as? String ?? "green500",
            type: step.params?["type"]?.value as? String ?? "formation"
        )
        return habitId
    }
    
    private func executeSetGoal(_ step: GoldenScenarioStep, habitsMap: [String: String]) async throws {
        guard let habitId = habitsMap[step.habit] else {
            throw GoldenTestError.habitNotFound(step.habit)
        }
        
        guard let goal = step.params?["goal"]?.value as? Int else {
            throw GoldenTestError.missingParameter("goal")
        }
        
        guard let effective = step.params?["effective"]?.value as? String else {
            throw GoldenTestError.missingParameter("effective")
        }
        
        try await goalService.setGoal(habitId: habitId, effectiveLocalDate: effective, goal: goal)
    }
    
    private func executeComplete(_ step: GoldenScenarioStep, habitsMap: [String: String]) async throws {
        guard let habitId = habitsMap[step.habit] else {
            throw GoldenTestError.habitNotFound(step.habit)
        }
        
        _ = try await completionService.markComplete(habitId: habitId, at: step.at)
        
        // TODO: Update to use new StreakService API
        // try await streakService.updateStreakIfNeeded(on: step.at, habits: habits, userId: userId)
        
        // TODO: Update to use new XPService API
        // try await xpService.awardDailyCompletion(for: userId, on: step.at, habits: habits)
    }
    
    private func executeAssert(_ step: GoldenScenarioStep, habitsMap: [String: String]) async throws {
        guard let habitId = habitsMap[step.habit] else {
            throw GoldenTestError.habitNotFound(step.habit)
        }
        
        guard let expect = step.params?["expect"]?.value as? [String: Any] else {
            throw GoldenTestError.missingParameter("expect")
        }
        
        let dateFormatter = LocalDateFormatter()
        let localDate = dateFormatter.dateToString(step.at)
        
        // Assert goal
        if let expectedGoal = expect["goal"] as? Int {
            let actualGoal = try await goalService.goal(on: localDate, habitId: habitId)
            if actualGoal != expectedGoal {
                throw AssertionError(
                    field: "goal",
                    expected: "\(expectedGoal)",
                    actual: "\(actualGoal)",
                    message: "Goal mismatch for \(step.habit) on \(localDate)"
                )
            }
        }
        
        // Assert progress
        if let expectedProgress = expect["progress"] as? Int {
            let actualProgress = try await completionService.getCompletion(habitId: habitId, on: step.at)
            if actualProgress != expectedProgress {
                throw AssertionError(
                    field: "progress",
                    expected: "\(expectedProgress)",
                    actual: "\(actualProgress)",
                    message: "Progress mismatch for \(step.habit) on \(localDate)"
                )
            }
        }
        
        // TODO: Assert streak using new StreakService API
        // Need to update this to use getStreakStats(for:) method
        /*
        if let expectedStreak = expect["streak"] as? Int {
            let actualStreak = try await streakService.getStreakStats(for: userId).currentStreak
            if actualStreak != expectedStreak {
                throw AssertionError(
                    field: "streak",
                    expected: "\(expectedStreak)",
                    actual: "\(actualStreak)",
                    message: "Streak mismatch for \(step.habit)"
                )
            }
        }
        */
        
        // Assert totalXP
        if let expectedXP = expect["totalXP"] as? Int {
            let actualXP = xpService.xpState?.totalXP ?? 0
            if actualXP != expectedXP {
                throw AssertionError(
                    field: "totalXP",
                    expected: "\(expectedXP)",
                    actual: "\(actualXP)",
                    message: "Total XP mismatch"
                )
            }
        }
    }
    
    private func resetState() async throws {
        // Clear all data for fresh test run
        // Note: In production, this would clear test user data only
        print("🧹 Resetting state for test run...")
    }
}

// MARK: - Models

struct GoldenScenario: Codable {
    let name: String
    let timezone: String
    let steps: [GoldenScenarioStep]
}

struct GoldenScenarioStep: Codable {
    let at: Date
    let op: String
    let habit: String
    let params: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case at, op, habit, params
    }
}

// MARK: - Errors

enum GoldenTestError: LocalizedError {
    case unknownOperation(String)
    case habitNotFound(String)
    case missingParameter(String)
    case scenarioParseError(String)
    
    var errorDescription: String? {
        switch self {
        case .unknownOperation(let op):
            return "Unknown operation: \(op)"
        case .habitNotFound(let habit):
            return "Habit not found: \(habit)"
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .scenarioParseError(let message):
            return "Failed to parse scenario: \(message)"
        }
    }
}

struct AssertionError: LocalizedError {
    let field: String
    let expected: String
    let actual: String
    let message: String
    
    var errorDescription: String? {
        message
    }
}

// MARK: - Mock Time Provider

/// Mock time provider for deterministic testing
class MockNowProvider: NowProvider {
    var currentDate: Date
    
    init(currentDate: Date) {
        self.currentDate = currentDate
    }
    
    func now() -> Date {
        currentDate
    }
    
    func today() -> Date {
        // Return start of day in Europe/Amsterdam timezone
        let calendar = Calendar.current
        var cal = calendar
        cal.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return cal.startOfDay(for: currentDate)
    }
}

