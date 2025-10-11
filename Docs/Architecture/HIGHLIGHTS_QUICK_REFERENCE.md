# This Week's Highlights - Quick Reference

## 🎯 **What It Does**
Shows three key insights about weekly habit performance:
1. **Top Performer** - Best performing habit (not perfect)
2. **Could Use a Nudge** - Habit needing attention
3. **Weekly Trends** - Overall performance and consistency

## ⚙️ **Key Configuration**
```swift
minScheduledDays = 3           // Minimum data required
needsAttentionHardFloor = 0.5  // 50% - clearly struggling
needsAttentionSoftFloor = 0.8  // 80% - performing well
belowAvgDelta = 0.20           // 20pp below average
floatingPointEpsilon = 1e-9    // Comparison safety
```

## 📊 **Calculation Methods**

### Top Performer
- **Input**: All habits with completion rates
- **Filter**: Exclude perfect habits (100%)
- **Requirement**: ≥3 scheduled days
- **Sort**: Rate → Scheduled Days → Completions → UUID
- **Output**: Best performing non-perfect habit

### Could Use a Nudge
- **Step 1**: Find habits <50% with ≥3 days
- **Step 2**: Among others, flag if ≥20pp below average AND <80%
- **Output**: Struggling habit or `nil`

### Weekly Trends
- **Overall**: Micro-average = sum(completed) / sum(scheduled)
- **Perfect Days**: % of days where ALL habits completed
- **Requirement**: ≥2 active days to show trends

## 🔍 **Edge Cases Handled**

| Scenario | Top Performer | Needs Attention | Weekly Trends |
|----------|---------------|-----------------|---------------|
| No habits | Empty state | Empty state | Empty state |
| No schedules | Empty state | Empty state | Empty state |
| 1/1 (100%) vs 6/7 (86%) | Shows 6/7 | Shows nothing | Shows 86% overall |
| All 80-95% | Shows best | Shows nothing | Shows metrics |
| Single habit <50% (1 day) | Shows nothing | Shows nothing | Shows "track more" |
| All perfect | Shows most scheduled | Shows nothing | Shows metrics |

## 🧮 **Math Examples**

### Micro-Average vs Macro-Average
```
Day 1: 2 habits, 2 completed = 100%
Day 2: 1 habit, 0 completed = 0%
Day 3: 1 habit, 1 completed = 100%

Macro-average: (100% + 0% + 100%) / 3 = 67%
Micro-average: (2 + 0 + 1) / (2 + 1 + 1) = 75%
```

### Perfect Day Rate
```
7 days total, 5 perfect days = 71% perfect days
Perfect day = ALL scheduled habits completed on that day
```

## 🎨 **UI Messages**

### Top Performer
- **Has data**: Shows habit name and completion rate
- **No data**: "No habits to highlight yet" + contextual message

### Could Use a Nudge
- **Has data**: Shows habit name and completion rate
- **No data**: "All habits are doing great!" + contextual message

### Weekly Trends
- **Has data**: "86% of scheduled actions completed, 71% perfect days"
- **No data**: "No trends to show yet" + contextual message

## 🚨 **Common Pitfalls**

1. **Don't use macro-average** - It overweights quiet days
2. **Always check minScheduledDays** - Prevents 1/1 beating 6/7
3. **Use floating-point safety** - Prevents precision issues
4. **Two-step needs attention** - Prevents false positives
5. **Perfect days ≠ overall completion** - They measure different things

## 🧪 **Test Cases**

```swift
// Essential test scenarios
testTopPerformer_respectsMinScheduledDays()
testNeedsAttention_usesHardFloorAndAvgDelta()
testWeeklyTrends_microAverageMatchesManualCalc()
testPerfectDayRate_multipleHabitsLowerThanOverall()
testDeterministicOrdering_onTies()
testEmptyStates_noSchedules_oneActiveDay_allPerfect()
```

## 🔧 **Debugging Tips**

1. **Check thresholds** - Are they appropriate for your data?
2. **Verify micro-average** - Does it match manual calculation?
3. **Test edge cases** - What happens with 0, 1, or 2 days?
4. **Check tie-breaking** - Is ordering stable across runs?
5. **Validate empty states** - Are messages contextual and helpful?

## 📈 **Future Enhancements**

- **Streak tracking**: Longest completion and perfect day streaks
- **Momentum detection**: Compare recent vs. earlier performance
- **Variability insights**: "Steady vs. up-and-down" messaging
- **Partial credit**: Optional setting for Weekly Trends
- **Localization**: Proper pluralization and decimal formatting
