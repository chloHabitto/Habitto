import CoreData
import Foundation

// MARK: - TimePatternAnalyzer

class TimePatternAnalyzer {
  // MARK: Internal

  // MARK: - Time of Day Analysis

  /// Analyzes the time of day when a habit is most frequently completed
  static func analyzeOptimalTimeOfDay(
    for _: Habit,
    completionRecords: [CompletionRecordEntity]) -> TimeOfDayInsight?
  {
    let recordsWithTime = completionRecords.filter { $0.timestamp != nil && $0.progress > 0 }

    guard !recordsWithTime.isEmpty else { return nil }

    // Group completions by hour of day
    var hourlyCompletions: [Int: Int] = [:]
    for record in recordsWithTime {
      let hour = Calendar.current.component(.hour, from: record.timestamp!)
      hourlyCompletions[hour, default: 0] += 1
    }

    // Find the hour with most completions
    guard let optimalHour = hourlyCompletions.max(by: { $0.value < $1.value })?.key else { return nil }

    let totalCompletions = recordsWithTime.count
    let optimalHourCompletions = hourlyCompletions[optimalHour] ?? 0
    let successRate = Double(optimalHourCompletions) / Double(totalCompletions)

    return TimeOfDayInsight(
      optimalHour: optimalHour,
      successRate: successRate,
      totalCompletions: totalCompletions,
      hourlyBreakdown: hourlyCompletions)
  }

  /// Analyzes time patterns for all habits to find common optimal times
  static func analyzeGlobalTimePatterns(
    habits _: [Habit],
    completionRecords: [CompletionRecordEntity]) -> GlobalTimeInsight?
  {
    let recordsWithTime = completionRecords.filter { $0.timestamp != nil && $0.progress > 0 }

    guard !recordsWithTime.isEmpty else { return nil }

    // Group completions by hour of day across all habits
    var hourlyCompletions: [Int: Int] = [:]
    for record in recordsWithTime {
      let hour = Calendar.current.component(.hour, from: record.timestamp!)
      hourlyCompletions[hour, default: 0] += 1
    }

    // Find the most productive hours
    let sortedHours = hourlyCompletions.sorted { $0.value > $1.value }
    let topHours = Array(sortedHours.prefix(3))

    return GlobalTimeInsight(
      topProductiveHours: topHours,
      totalCompletions: recordsWithTime.count,
      hourlyBreakdown: hourlyCompletions)
  }

  /// Analyzes consistency of completion times for a specific habit
  static func analyzeTimeConsistency(
    for _: Habit,
    completionRecords: [CompletionRecordEntity]) -> TimeConsistencyInsight?
  {
    let recordsWithTime = completionRecords.filter { $0.timestamp != nil && $0.progress > 0 }

    guard recordsWithTime.count >= 3 else { return nil } // Need at least 3 records for consistency
    // analysis

    // Calculate standard deviation of completion times
    let completionHours = recordsWithTime.map { Calendar.current.component(
      .hour,
      from: $0.timestamp!) }
    let meanHour = Double(completionHours.reduce(0, +)) / Double(completionHours.count)

    let variance = completionHours.reduce(0.0) { sum, hour in
      let diff = Double(hour) - meanHour
      return sum + diff * diff
    } / Double(completionHours.count)

    let standardDeviation = sqrt(variance)

    // Determine consistency level
    let consistencyLevel: TimeConsistencyLevel = if standardDeviation < 2.0 {
      .veryConsistent
    } else if standardDeviation < 4.0 {
      .consistent
    } else if standardDeviation < 6.0 {
      .moderate
    } else {
      .inconsistent
    }

    return TimeConsistencyInsight(
      consistencyLevel: consistencyLevel,
      standardDeviation: standardDeviation,
      meanHour: meanHour,
      totalCompletions: recordsWithTime.count)
  }

  /// Generates actionable recommendations based on time analysis
  static func generateTimeBasedRecommendations(
    for habit: Habit,
    timeInsight: TimeOfDayInsight,
    consistencyInsight: TimeConsistencyInsight?) -> [TimeRecommendation]
  {
    var recommendations: [TimeRecommendation] = []

    // Recommendation based on optimal time
    let optimalTimeString = formatHour(timeInsight.optimalHour)
    recommendations.append(TimeRecommendation(
      type: .optimalTime,
      title: "Peak Performance Time",
      description: "You're most successful with '\(habit.name)' around \(optimalTimeString). Try to schedule this habit during this time window.",
      priority: .high))

    // Recommendation based on consistency
    if let consistency = consistencyInsight {
      switch consistency.consistencyLevel {
      case .veryConsistent:
        recommendations.append(TimeRecommendation(
          type: .consistency,
          title: "Excellent Time Consistency",
          description: "You're very consistent with when you do '\(habit.name)'. Keep up this routine!",
          priority: .low))

      case .consistent:
        recommendations.append(TimeRecommendation(
          type: .consistency,
          title: "Good Time Consistency",
          description: "You have a good routine for '\(habit.name)'. Consider making it even more consistent by setting a fixed time.",
          priority: .medium))

      case .moderate:
        recommendations.append(TimeRecommendation(
          type: .consistency,
          title: "Improve Time Consistency",
          description: "Try to do '\(habit.name)' at the same time each day. Your optimal time is \(optimalTimeString).",
          priority: .high))

      case .inconsistent:
        recommendations.append(TimeRecommendation(
          type: .consistency,
          title: "Establish a Routine",
          description: "You're most successful around \(optimalTimeString). Try to make this your regular time for '\(habit.name)'.",
          priority: .high))
      }
    }

    // Recommendation based on success rate
    if timeInsight.successRate < 0.5 {
      recommendations.append(TimeRecommendation(
        type: .successRate,
        title: "Optimize Your Timing",
        description: "Your success rate is low. Focus on doing '\(habit.name)' around \(optimalTimeString) when you're most likely to complete it.",
        priority: .high))
    }

    return recommendations
  }

  // MARK: Private

  // MARK: - Helper Methods

  private static func formatHour(_ hour: Int) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h a"

    let calendar = Calendar.current
    let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()

    return formatter.string(from: date)
  }
}

// MARK: - TimeOfDayInsight

struct TimeOfDayInsight {
  let optimalHour: Int
  let successRate: Double
  let totalCompletions: Int
  let hourlyBreakdown: [Int: Int]
}

// MARK: - GlobalTimeInsight

struct GlobalTimeInsight {
  let topProductiveHours: [(key: Int, value: Int)]
  let totalCompletions: Int
  let hourlyBreakdown: [Int: Int]
}

// MARK: - TimeConsistencyInsight

struct TimeConsistencyInsight {
  let consistencyLevel: TimeConsistencyLevel
  let standardDeviation: Double
  let meanHour: Double
  let totalCompletions: Int
}

// MARK: - TimeConsistencyLevel

enum TimeConsistencyLevel {
  case veryConsistent
  case consistent
  case moderate
  case inconsistent
}

// MARK: - TimeRecommendation

struct TimeRecommendation {
  let type: TimeRecommendationType
  let title: String
  let description: String
  let priority: RecommendationPriority
}

// MARK: - TimeRecommendationType

enum TimeRecommendationType {
  case optimalTime
  case consistency
  case successRate
}

// MARK: - RecommendationPriority

enum RecommendationPriority {
  case low
  case medium
  case high
}
