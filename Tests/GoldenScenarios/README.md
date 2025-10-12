# Golden Test Scenarios

This directory contains golden test scenarios for time-travel testing of the Habitto app's temporal logic.

## Overview

Golden scenarios are pre-defined test scripts that execute a series of operations at specific timestamps and verify the expected outcomes. They are particularly useful for:

- **DST Transitions**: Testing behavior across daylight saving time changes
- **Complex Temporal Logic**: Verifying goal versioning, streaks, and XP calculations
- **Regression Prevention**: Ensuring changes don't break existing behavior
- **Time-Travel Testing**: Simulating days, weeks, or months of activity in seconds

## Scenario Format

Each scenario is a JSON file with the following structure:

```json
{
  "name": "Scenario Name",
  "timezone": "Europe/Amsterdam",
  "description": "What this scenario tests",
  "steps": [
    {
      "at": "2025-10-12T08:00:00+02:00",
      "op": "operation",
      "habit": "Habit Name",
      "params": {
        "key": "value"
      }
    }
  ]
}
```

### Supported Operations

#### 1. `createHabit`
Creates a new habit.

**Parameters**:
- `color`: Habit color (e.g., "green500")
- `type`: Habit type (e.g., "formation", "elimination")

**Example**:
```json
{
  "at": "2025-10-12T08:00:00+02:00",
  "op": "createHabit",
  "habit": "Morning Run",
  "params": {
    "color": "green500",
    "type": "formation"
  }
}
```

#### 2. `setGoal`
Sets a date-effective goal for a habit.

**Parameters**:
- `goal`: Goal value (integer, >= 0)
- `effective`: Effective date in "YYYY-MM-DD" format

**Example**:
```json
{
  "at": "2025-10-12T08:05:00+02:00",
  "op": "setGoal",
  "habit": "Morning Run",
  "params": {
    "goal": 2,
    "effective": "2025-10-12"
  }
}
```

#### 3. `complete`
Marks a habit as complete (increments completion count).

**Parameters**: None

**Example**:
```json
{
  "at": "2025-10-12T09:00:00+02:00",
  "op": "complete",
  "habit": "Morning Run",
  "params": {}
}
```

#### 4. `assert`
Asserts expected values for goal, progress, streak, and XP.

**Parameters**:
- `expect`: Object with expected values
  - `goal`: Expected goal value
  - `progress`: Expected completion count
  - `streak`: Expected current streak
  - `totalXP`: Expected total XP

**Example**:
```json
{
  "at": "2025-10-12T09:05:00+02:00",
  "op": "assert",
  "habit": "Morning Run",
  "params": {
    "expect": {
      "goal": 2,
      "progress": 1,
      "streak": 1,
      "totalXP": 10
    }
  }
}
```

## Included Scenarios

### 1. `dst_spring_forward.json`
Tests behavior across DST spring forward (2AM → 3AM).

**Key Assertions**:
- Goals apply correctly across DST boundary
- Completions are counted on the correct date
- Streaks continue across DST transition

### 2. `dst_fall_back.json`
Tests behavior across DST fall back (3AM → 2AM).

**Key Assertions**:
- Completions during the "repeated hour" are handled correctly
- Date calculations remain accurate after DST change

### 3. `multiple_goal_changes.json`
Tests multiple goal changes on the same day.

**Key Assertions**:
- Latest goal applies immediately
- Existing progress is preserved
- Assertions use the latest goal

### 4. `streak_break_and_recovery.json`
Tests streak break when a day is skipped.

**Key Assertions**:
- Streak increments on consecutive days
- Streak resets to 1 when a day is skipped
- Longest streak is preserved

### 5. `all_habits_complete_xp.json`
Tests XP gating when multiple habits exist.

**Key Assertions**:
- Individual habit XP awarded per completion (10 XP each)
- Daily completion bonus (50 XP) only awarded when ALL habits complete
- Total XP calculated correctly

## Running Scenarios

### Via Unit Tests

```swift
import XCTest
@testable import Habitto

class MyTests: XCTestCase {
    func testDSTSpringForward() async throws {
        let runner = GoldenTestRunner.shared
        let fileURL = Bundle.main.url(forResource: "dst_spring_forward", withExtension: "json")!
        let result = try await runner.runScenario(from: fileURL)
        
        XCTAssertTrue(result.success)
    }
}
```

### Via Swift REPL or Playground

```swift
let runner = GoldenTestRunner.shared
let fileURL = URL(fileURLWithPath: "/path/to/dst_spring_forward.json")
let result = try await runner.runScenario(from: fileURL)

if result.success {
    print("✅ All \(result.passedSteps) steps passed!")
} else {
    print("❌ \(result.failedSteps) steps failed")
    for failure in result.failures {
        print("   Step \(failure.stepIndex): \(failure.message)")
    }
}
```

## Creating New Scenarios

1. **Identify the Test Case**: What temporal logic are you testing?
2. **Define the Steps**: What operations need to happen, and at what times?
3. **Add Assertions**: What should the state be at each checkpoint?
4. **Test Edge Cases**: Include boundary conditions (midnight, DST, month/year changes)

### Example: Testing Monthly Goal Changes

```json
{
  "name": "Monthly Goal Increases",
  "timezone": "Europe/Amsterdam",
  "description": "Test that goals can increase each month while preserving history",
  "steps": [
    {
      "at": "2025-10-01T08:00:00+02:00",
      "op": "createHabit",
      "habit": "Reading",
      "params": {"color": "yellow500", "type": "formation"}
    },
    {
      "at": "2025-10-01T08:05:00+02:00",
      "op": "setGoal",
      "habit": "Reading",
      "params": {"goal": 1, "effective": "2025-10-01"}
    },
    {
      "at": "2025-11-01T08:00:00+01:00",
      "op": "setGoal",
      "habit": "Reading",
      "params": {"goal": 2, "effective": "2025-11-01"}
    },
    {
      "at": "2025-10-15T10:00:00+02:00",
      "op": "assert",
      "habit": "Reading",
      "params": {
        "expect": {"goal": 1}
      }
    },
    {
      "at": "2025-11-15T10:00:00+01:00",
      "op": "assert",
      "habit": "Reading",
      "params": {
        "expect": {"goal": 2}
      }
    }
  ]
}
```

## Best Practices

1. **Use Realistic Timestamps**: Include timezone offsets and account for DST
2. **Test Boundaries**: Midnight, month/year changes, DST transitions
3. **Include Negative Cases**: Test what happens when expectations aren't met
4. **Document Intent**: Use clear names and descriptions
5. **Keep Scenarios Focused**: One scenario per logical test case
6. **Run Regularly**: Include in CI/CD pipeline to catch regressions early

## Troubleshooting

### Scenario Won't Load

- Check JSON syntax with a validator
- Verify timestamps include timezone offsets
- Ensure all required parameters are present

### Assertions Failing

- Check expected vs. actual values in test output
- Verify timezone handling for date calculations
- Confirm habit names match between create and complete operations

### Time Provider Issues

- Ensure `MockNowProvider` is injected correctly
- Verify timestamps are in Europe/Amsterdam timezone
- Check for DST transitions affecting date calculations

## Resources

- [GoldenTestRunner.swift](/Core/Services/GoldenTestRunner.swift) - Runner implementation
- [GoldenTestRunnerTests.swift.template](/Documentation/TestsReadyToAdd/GoldenTestRunnerTests.swift.template) - Unit tests
- [ISO 8601 Date Format](https://en.wikipedia.org/wiki/ISO_8601) - Timestamp format reference
- [Europe/Amsterdam Timezone](https://www.timeanddate.com/time/zone/netherlands/amsterdam) - DST transition dates

