# This Week's Highlights Calculation Documentation

## Overview

The "This Week's Highlights" feature provides three key insights into weekly habit performance:
1. **Top Performer** - The habit performing best (but not perfect) this week
2. **Could Use a Nudge** - The habit that needs attention this week
3. **Weekly Trends** - Overall performance and consistency metrics

## Configuration Constants

```swift
private struct HighlightsConfig {
    static let minScheduledDays = 3                    // Minimum days to be considered
    static let needsAttentionHardFloor: Double = 0.5   // 50% - clearly struggling threshold
    static let needsAttentionSoftFloor: Double = 0.8   // 80% - soft floor for "needs attention"
    static let belowAvgDelta: Double = 0.20            // 20 percentage points below average
    static let greatAvgFloor: Double = 0.80            // 80% - "doing great" threshold
    static let floatingPointEpsilon: Double = 1e-9     // Floating-point comparison safety
}
```

## 1. Top Performer Calculation

### Purpose
Shows the habit that's performing best (but not perfect) this week, with fairness guards to prevent low-data habits from skewing results.

### Algorithm
```swift
// Step 1: Calculate performance data for each habit
for each habit {
    totalScheduled = count of days habit is scheduled this week
    totalCompleted = count of days habit was completed this week
    completionRate = totalCompleted / totalScheduled
    
    if totalScheduled > 0 {
        habitData.append((habit, scheduled, completed, rate))
    }
}

// Step 2: Filter out perfect habits (100% completion)
nonPerfectHabits = habitData.filter { rate < 1.0 }
candidatePool = nonPerfectHabits.isEmpty ? habitData : nonPerfectHabits

// Step 3: Apply minimum scheduled days filter
minScheduledCandidates = candidatePool.filter { scheduled >= 3 }
finalCandidates = minScheduledCandidates.isEmpty ? candidatePool : minScheduledCandidates

// Step 4: Sort with comprehensive tie-breaking
return finalCandidates.max { habit1, habit2 in
    // 1. Primary: completion rate (with floating-point safety)
    if abs(habit1.rate - habit2.rate) > epsilon {
        return habit1.rate < habit2.rate
    }
    // 2. Secondary: more scheduled days (more commitment)
    if habit1.scheduled != habit2.scheduled {
        return habit1.scheduled < habit2.scheduled
    }
    // 3. Tertiary: more completions (more actual progress)
    if habit1.completed != habit2.completed {
        return habit1.completed < habit2.completed
    }
    // 4. Quaternary: stable ID alphabetical (deterministic)
    return habit1.habit.id.uuidString < habit2.habit.id.uuidString
}
```

### Edge Cases
- **No habits**: Returns `nil` (shows empty state)
- **All habits perfect**: Shows the one with most scheduled days
- **All habits 0% completion**: Shows the one with most scheduled days
- **Insufficient data**: Habits with <3 scheduled days are deprioritized

### Example
- Habit A: 1/1 (100%) - excluded (perfect)
- Habit B: 6/7 (86%) - selected (highest rate, sufficient data)
- Habit C: 2/2 (100%) - excluded (perfect)
- Habit D: 1/3 (33%) - not selected (insufficient data)

## 2. Could Use a Nudge (Needs Attention) Calculation

### Purpose
Identifies habits that are struggling or significantly underperforming, with sensitivity to avoid false positives.

### Algorithm
```swift
// Step 1: Calculate performance data (same as Top Performer)
// Step 2: Filter out perfect habits
nonPerfectHabits = habitData.filter { rate < 1.0 }

// Step 3: Find habits clearly struggling (< 50% completion)
reallyStrugglingHabits = nonPerfectHabits.filter { 
    rate < 0.5 && scheduled >= 3 
}

if !reallyStrugglingHabits.isEmpty {
    // Return worst among clearly struggling habits
    return reallyStrugglingHabits.min { /* same tie-breaking as Top Performer */ }
}

// Step 4: Check for significant differences among non-struggling habits
averageRate = sum(completionRates) / count(completionRates)
worstHabit = nonPerfectHabits.min { rate }

// Only show "needs attention" if:
// 1. Significantly below average (≥20 percentage points)
// 2. Below soft floor (80%)
// 3. Sufficient data (≥3 scheduled days)
if worstHabit.rate < (averageRate - 0.20) && 
   worstHabit.rate < 0.8 && 
   worstHabit.scheduled >= 3 {
    return worstHabit
}

return nil // No habit needs attention
```

### Edge Cases
- **All habits perfect**: Returns `nil` (shows "All habits are doing great!")
- **All habits performing well**: Returns `nil` (shows "All habits are performing well!")
- **Single habit <50% with 1 day**: Returns `nil` (insufficient data)
- **All habits 80-95%**: Returns `nil` (no significant difference)

### Example
- Habit A: 90% (7 days) - not selected
- Habit B: 85% (6 days) - not selected  
- Habit C: 30% (5 days) - selected (clearly struggling)
- Average: 68%, Habit C is 38% below average (>20% threshold)

## 3. Weekly Trends Calculation

### Purpose
Shows overall performance and consistency metrics using micro-averaging for accuracy.

### Algorithm
```swift
// Step 1: Calculate daily metrics
totalScheduled = 0
totalCompleted = 0
perfectDays = 0
activeDays = 0
dailyRatios = []

for each day in week {
    scheduledHabits = habits scheduled on this day
    if scheduledHabits.isEmpty { continue }
    
    completedCount = count of completed habits on this day
    dayRatio = completedCount / scheduledHabits.count
    
    totalScheduled += scheduledHabits.count
    totalCompleted += completedCount
    activeDays += 1
    dailyRatios.append(dayRatio)
    
    if dayRatio == 1.0 {
        perfectDays += 1
    }
}

// Step 2: Calculate metrics
overallCompletion = totalCompleted / totalScheduled  // Micro-average
perfectDayRate = perfectDays / activeDays            // % of perfect days
variability = standardDeviation(dailyRatios)         // Consistency measure
```

### Metrics Explained

#### Overall Completion (Micro-Average)
- **Formula**: `sum(completed) / sum(scheduled)`
- **Why**: Prevents quiet days from skewing results
- **Example**: 2 habits × 7 days = 14 total, completed 12 = 86%

#### Perfect Day Rate
- **Formula**: `perfectDays / activeDays`
- **Definition**: % of days where ALL scheduled habits were completed
- **Example**: 5 perfect days out of 7 = 71%

#### Variability (Standard Deviation)
- **Formula**: `sqrt(mean((dayRatio - mean)²))`
- **Purpose**: Measures consistency (lower = more consistent)
- **Future Use**: Could show "steady vs. up-and-down" insights

### Display Logic
```swift
if activeDays >= 3 {
    return "\(overallCompletion)% of scheduled actions completed, \(perfectDayRate)% perfect days"
} else {
    return "\(overallCompletion)% of scheduled actions completed"
}
```

### Edge Cases
- **No habits**: Shows "No habits scheduled this week"
- **No scheduled days**: Shows "No habits scheduled this week. Add schedules to see highlights!"
- **1 active day**: Shows "You've logged 1 active day. Track a bit more to see trends!"
- **<2 active days**: Shows empty state (insufficient data for trends)

## Data Flow

```
User Data
    ↓
HabitRepository.habits
    ↓
StreakDataCalculator.shouldShowHabitOnDate() (scheduling logic)
    ↓
habitRepository.getProgress() (completion data)
    ↓
parseGoalAmount() (goal parsing)
    ↓
HighlightsConfig (thresholds & constants)
    ↓
Top Performer | Could Use a Nudge | Weekly Trends
    ↓
UI Display (with empty states)
```

## Key Design Decisions

### 1. Micro-Average vs Macro-Average
- **Chosen**: Micro-average (`sum(completed) / sum(scheduled)`)
- **Why**: Prevents quiet days from skewing results
- **Alternative**: Macro-average would overweight days with fewer habits

### 2. Minimum Scheduled Days Threshold
- **Value**: 3 days
- **Why**: Prevents 1/1 (100%) from beating 6/7 (86%)
- **Applied**: Consistently across Top Performer and Needs Attention

### 3. Floating-Point Safety
- **Method**: Epsilon comparison (`abs(a-b) < 1e-9`)
- **Why**: Prevents floating-point precision issues in tie-breaking
- **Applied**: All rate comparisons

### 4. Deterministic Tie-Breaking
- **Order**: Rate → Scheduled Days → Completions → UUID
- **Why**: Ensures stable UI ordering across runs
- **UUID**: Alphabetical for deterministic final tie-break

### 5. Two-Step Needs Attention Logic
- **Step 1**: Clear struggling (<50% + sufficient data)
- **Step 2**: Significant difference (≥20pp below average + <80%)
- **Why**: Avoids false positives when all habits perform similarly well

## Testing Scenarios

### Unit Test Cases
1. `testTopPerformer_respectsMinScheduledDays` - 1/1 vs 6/7
2. `testNeedsAttention_usesHardFloorAndAvgDelta` - Threshold logic
3. `testWeeklyTrends_microAverageMatchesManualCalc` - Math verification
4. `testPerfectDayRate_multipleHabitsLowerThanOverall` - Multiple habits
5. `testDeterministicOrdering_onTies` - Stable ordering
6. `testEmptyStates_noSchedules_oneActiveDay_allPerfect` - Edge cases

### Edge Case Coverage
- ✅ No habits / no schedules / 1 day only
- ✅ All perfect (varied scheduled counts)
- ✅ Identical completion rates (tie-break order stable)
- ✅ One tiny habit (1/1) vs big habit (6/7)
- ✅ Single habit <50% with 1 scheduled day
- ✅ All high (80–95%) but slightly different
- ✅ Mixed days (overall vs perfect-day rates diverge)

## Performance Considerations

- **Precomputation**: Weekly metrics calculated once, reused across sections
- **Efficient Filtering**: Early returns for edge cases
- **Minimal Iterations**: Single pass through habits for data collection
- **Cached Results**: Avoid redundant calculations in UI updates

## Future Enhancements

1. **Streak Tracking**: Longest streak of completions and perfect days
2. **Momentum Detection**: Compare last 3 days vs prior 3 days
3. **Variability Insights**: "Steady vs. up-and-down" messaging
4. **Partial Credit**: Optional setting for Weekly Trends only
5. **Localization**: Proper pluralization and decimal formatting
6. **Telemetry**: Debug logging for "why did it pick X?" analysis
