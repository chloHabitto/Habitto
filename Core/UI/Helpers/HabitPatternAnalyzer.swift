import Foundation
import CoreData

// MARK: - Note: Core Data type aliases are defined in HabitRepository.swift

class HabitPatternAnalyzer {
    
    // MARK: - Success/Failure Correlations
    
    /// Analyzes what factors correlate with success for a specific habit
    static func analyzeSuccessCorrelations(for habit: Habit, completionRecords: [CompletionRecordEntity], difficultyLogs: [DifficultyLogEntity]) -> SuccessCorrelationInsight? {
        guard completionRecords.count >= 5 else { return nil } // Need sufficient data
        
        var correlations: [SuccessCorrelation] = []
        
        // 1. Day of Week Correlation
        if let dayCorrelation = analyzeDayOfWeekCorrelation(completionRecords: completionRecords) {
            correlations.append(dayCorrelation)
        }
        
        // 2. Time of Day Correlation
        if let timeCorrelation = analyzeTimeOfDayCorrelation(completionRecords: completionRecords) {
            correlations.append(timeCorrelation)
        }
        
        // 3. Difficulty Correlation
        if let difficultyCorrelation = analyzeDifficultyCorrelation(completionRecords: completionRecords, difficultyLogs: difficultyLogs) {
            correlations.append(difficultyCorrelation)
        }
        
        // 4. Streak Correlation
        if let streakCorrelation = analyzeStreakCorrelation(completionRecords: completionRecords) {
            correlations.append(streakCorrelation)
        }
        
        // 5. Weather/Seasonal Correlation (if available)
        if let seasonalCorrelation = analyzeSeasonalCorrelation(completionRecords: completionRecords) {
            correlations.append(seasonalCorrelation)
        }
        
        guard !correlations.isEmpty else { return nil }
        
        return SuccessCorrelationInsight(
            habit: habit,
            correlations: correlations,
            strongestCorrelation: correlations.max { $0.correlationStrength < $1.correlationStrength }
        )
    }
    
    // MARK: - Trend Analysis Over Time
    
    /// Analyzes how habit performance changes over time
    static func analyzePerformanceTrends(for habit: Habit, completionRecords: [CompletionRecordEntity]) -> PerformanceTrendInsight? {
        guard completionRecords.count >= 10 else { return nil } // Need sufficient data for trends
        
        // Group by week/month to see trends
        let weeklyTrends = analyzeWeeklyTrends(completionRecords: completionRecords)
        let monthlyTrends = analyzeMonthlyTrends(completionRecords: completionRecords)
        let seasonalTrends = analyzeSeasonalTrends(completionRecords: completionRecords)
        
        // Calculate overall trend direction
        let overallTrend = calculateOverallTrend(weeklyTrends: weeklyTrends, monthlyTrends: monthlyTrends)
        
        return PerformanceTrendInsight(
            habit: habit,
            weeklyTrends: weeklyTrends,
            monthlyTrends: monthlyTrends,
            seasonalTrends: seasonalTrends,
            overallTrend: overallTrend,
            trendStrength: calculateTrendStrength(overallTrend: overallTrend)
        )
    }
    
    // MARK: - Comparative Performance Analysis
    
    /// Compares performance across different habits and categories
    static func analyzeComparativePerformance(habits: [Habit], completionRecords: [CompletionRecordEntity]) -> ComparativePerformanceInsight? {
        guard habits.count >= 2 else { return nil }
        
        // 1. Performance Ranking
        let performanceRanking = calculatePerformanceRanking(habits: habits, completionRecords: completionRecords)
        
        // 2. Category Performance
        let categoryPerformance = analyzeCategoryPerformance(habits: habits, completionRecords: completionRecords)
        
        // 3. Difficulty vs Performance
        let difficultyPerformance = analyzeDifficultyPerformanceCorrelation(habits: habits, completionRecords: completionRecords)
        
        // 4. Goal Achievement Rates
        let goalAchievementRates = calculateGoalAchievementRates(habits: habits, completionRecords: completionRecords)
        
        return ComparativePerformanceInsight(
            performanceRanking: performanceRanking,
            categoryPerformance: categoryPerformance,
            difficultyPerformance: difficultyPerformance,
            goalAchievementRates: goalAchievementRates
        )
    }
    
    // MARK: - Risk Factor Identification
    
    /// Identifies factors that increase the risk of habit failure
    static func identifyRiskFactors(for habit: Habit, completionRecords: [CompletionRecordEntity], difficultyLogs: [DifficultyLogEntity]) -> RiskFactorInsight? {
        guard completionRecords.count >= 5 else { return nil }
        
        var riskFactors: [RiskFactor] = []
        
        // 1. High-Risk Time Periods
        if let timeRisk = identifyTimeBasedRisk(completionRecords: completionRecords) {
            riskFactors.append(timeRisk)
        }
        
        // 2. High-Risk Days
        if let dayRisk = identifyDayBasedRisk(completionRecords: completionRecords) {
            riskFactors.append(dayRisk)
        }
        
        // 3. Difficulty Spikes
        if let difficultyRisk = identifyDifficultyBasedRisk(completionRecords: completionRecords, difficultyLogs: difficultyLogs) {
            riskFactors.append(difficultyRisk)
        }
        
        // 4. Streak Breaks
        if let streakRisk = identifyStreakBasedRisk(completionRecords: completionRecords) {
            riskFactors.append(streakRisk)
        }
        
        // 5. Environmental Risk Factors
        if let environmentalRisk = identifyEnvironmentalRisk(completionRecords: completionRecords) {
            riskFactors.append(environmentalRisk)
        }
        
        guard !riskFactors.isEmpty else { return nil }
        
        return RiskFactorInsight(
            habit: habit,
            riskFactors: riskFactors,
            overallRiskLevel: calculateOverallRiskLevel(riskFactors: riskFactors)
        )
    }
    
    // MARK: - Private Analysis Methods
    
    // MARK: - Success Correlation Analysis
    
    private static func analyzeDayOfWeekCorrelation(completionRecords: [CompletionRecordEntity]) -> SuccessCorrelation? {
        var daySuccessRates: [Int: (success: Int, total: Int)] = [:]
        
        for record in completionRecords {
            guard let timestamp = record.timestamp else { continue }
            let weekday = Calendar.current.component(.weekday, from: timestamp)
            let isSuccess = record.progress > 0
            
            if daySuccessRates[weekday] == nil {
                daySuccessRates[weekday] = (0, 0)
            }
            
            if isSuccess {
                daySuccessRates[weekday]?.success += 1
            }
            daySuccessRates[weekday]?.total += 1
        }
        
        // Find the day with highest success rate
        guard let bestDay = daySuccessRates.max(by: { 
            let rate1 = Double($0.value.success) / Double($0.value.total)
            let rate2 = Double($1.value.success) / Double($1.value.total)
            return rate1 < rate2
        }) else { return nil }
        
        let successRate = Double(bestDay.value.success) / Double(bestDay.value.total)
        let dayName = Calendar.current.weekdaySymbols[bestDay.key - 1]
        
        return SuccessCorrelation(
            factor: .dayOfWeek,
            value: dayName,
            correlationStrength: successRate,
            description: "You're most successful on \(dayName)s with a \(Int(successRate * 100))% success rate"
        )
    }
    
    private static func analyzeTimeOfDayCorrelation(completionRecords: [CompletionRecordEntity]) -> SuccessCorrelation? {
        var hourSuccessRates: [Int: (success: Int, total: Int)] = [:]
        
        for record in completionRecords {
            guard let timestamp = record.timestamp else { continue }
            let hour = Calendar.current.component(.hour, from: timestamp)
            let isSuccess = record.progress > 0
            
            if hourSuccessRates[hour] == nil {
                hourSuccessRates[hour] = (0, 0)
            }
            
            if isSuccess {
                hourSuccessRates[hour]?.success += 1
            }
            hourSuccessRates[hour]?.total += 1
        }
        
        // Find the hour with highest success rate
        guard let bestHour = hourSuccessRates.max(by: { 
            let rate1 = Double($0.value.success) / Double($0.value.total)
            let rate2 = Double($1.value.success) / Double($1.value.total)
            return rate1 < rate2
        }) else { return nil }
        
        let successRate = Double(bestHour.value.success) / Double(bestHour.value.total)
        let timeString = formatHour(bestHour.key)
        
        return SuccessCorrelation(
            factor: .timeOfDay,
            value: timeString,
            correlationStrength: successRate,
            description: "You're most successful around \(timeString) with a \(Int(successRate * 100))% success rate"
        )
    }
    
    private static func analyzeDifficultyCorrelation(completionRecords: [CompletionRecordEntity], difficultyLogs: [DifficultyLogEntity]) -> SuccessCorrelation? {
        // Match difficulty logs with completion records by date
        var difficultyByDate: [String: Double] = [:]
        
        for log in difficultyLogs {
            let dateKey = createDateKey(for: log.timestamp ?? Date())
            difficultyByDate[dateKey] = Double(log.difficultyLevel)
        }
        
        var successByDifficulty: [Int: (success: Int, total: Int)] = [:]
        
        for record in completionRecords {
            let dateKey = createDateKey(for: record.timestamp ?? Date())
            let difficulty = Int(difficultyByDate[dateKey] ?? 5) // Default to medium difficulty
            let isSuccess = record.progress > 0
            
            if successByDifficulty[difficulty] == nil {
                successByDifficulty[difficulty] = (0, 0)
            }
            
            if isSuccess {
                successByDifficulty[difficulty]?.success += 1
            }
            successByDifficulty[difficulty]?.total += 1
        }
        
        // Find the difficulty level with highest success rate
        guard let bestDifficulty = successByDifficulty.max(by: { 
            let rate1 = Double($0.value.success) / Double($0.value.total)
            let rate2 = Double($1.value.success) / Double($1.value.total)
            return rate1 < rate2
        }) else { return nil }
        
        let successRate = Double(bestDifficulty.value.success) / Double(bestDifficulty.value.total)
        let difficultyName = difficultyLevelName(bestDifficulty.key)
        
        return SuccessCorrelation(
            factor: .difficulty,
            value: difficultyName,
            correlationStrength: successRate,
            description: "You're most successful when the habit feels '\(difficultyName)' with a \(Int(successRate * 100))% success rate"
        )
    }
    
    private static func analyzeStreakCorrelation(completionRecords: [CompletionRecordEntity]) -> SuccessCorrelation? {
        // Calculate streak lengths and success rates
        var streakSuccessRates: [Int: (success: Int, total: Int)] = [:]
        
        let sortedRecords = completionRecords.sorted { 
            ($0.timestamp ?? Date()) < ($1.timestamp ?? Date())
        }
        
        var currentStreak = 0
        for record in sortedRecords {
            if record.progress > 0 {
                currentStreak += 1
            } else {
                if currentStreak > 0 {
                    if streakSuccessRates[currentStreak] == nil {
                        streakSuccessRates[currentStreak] = (0, 0)
                    }
                    streakSuccessRates[currentStreak]?.total += 1
                    
                    // Check if next day was successful (streak continuation)
                    if let nextIndex = sortedRecords.firstIndex(of: record)?.advanced(by: 1),
                       nextIndex < sortedRecords.count {
                        let nextRecord = sortedRecords[nextIndex]
                        if nextRecord.progress > 0 {
                            streakSuccessRates[currentStreak]?.success += 1
                        }
                    }
                }
                currentStreak = 0
            }
        }
        
        // Find the streak length with highest continuation rate
        guard let bestStreak = streakSuccessRates.max(by: { 
            let rate1 = Double($0.value.success) / Double($0.value.total)
            let rate2 = Double($1.value.success) / Double($1.value.total)
            return rate1 < rate2
        }) else { return nil }
        
        let continuationRate = Double(bestStreak.value.success) / Double(bestStreak.value.total)
        
        return SuccessCorrelation(
            factor: .streak,
            value: "\(bestStreak.key) days",
            correlationStrength: continuationRate,
            description: "After \(bestStreak.key) successful days, you're \(Int(continuationRate * 100))% likely to continue the streak"
        )
    }
    
    private static func analyzeSeasonalCorrelation(completionRecords: [CompletionRecordEntity]) -> SuccessCorrelation? {
        var seasonalSuccessRates: [Int: (success: Int, total: Int)] = [:]
        
        for record in completionRecords {
            guard let timestamp = record.timestamp else { continue }
            let month = Calendar.current.component(.month, from: timestamp)
            let season = monthToSeason(month)
            let isSuccess = record.progress > 0
            
            if seasonalSuccessRates[season] == nil {
                seasonalSuccessRates[season] = (0, 0)
            }
            
            if isSuccess {
                seasonalSuccessRates[season]?.success += 1
            }
            seasonalSuccessRates[season]?.total += 1
        }
        
        // Find the season with highest success rate
        guard let bestSeason = seasonalSuccessRates.max(by: { 
            let rate1 = Double($0.value.success) / Double($0.value.total)
            let rate2 = Double($1.value.success) / Double($1.value.total)
            return rate1 < rate2
        }) else { return nil }
        
        let successRate = Double(bestSeason.value.success) / Double(bestSeason.value.total)
        let seasonName = seasonName(bestSeason.key)
        
        return SuccessCorrelation(
            factor: .seasonal,
            value: seasonName,
            correlationStrength: successRate,
            description: "You're most successful during \(seasonName) with a \(Int(successRate * 100))% success rate"
        )
    }
    
    // MARK: - Trend Analysis Methods
    
    private static func analyzeWeeklyTrends(completionRecords: [CompletionRecordEntity]) -> [WeeklyTrend] {
        var weeklyData: [String: (week: Int, success: Int, total: Int)] = [:]
        
        for record in completionRecords {
            guard let timestamp = record.timestamp else { continue }
            let weekOfYear = Calendar.current.component(.weekOfYear, from: timestamp)
            let year = Calendar.current.component(.year, from: timestamp)
            let weekKey = "\(year)-W\(weekOfYear)"
            let isSuccess = record.progress > 0
            
            if weeklyData[weekKey] == nil {
                weeklyData[weekKey] = (weekOfYear, 0, 0)
            }
            
            if isSuccess {
                weeklyData[weekKey]?.success += 1
            }
            weeklyData[weekKey]?.total += 1
        }
        
        return weeklyData.values.map { data in
            WeeklyTrend(
                week: data.week,
                successRate: Double(data.success) / Double(data.total),
                totalHabits: data.total
            )
        }.sorted { $0.week < $1.week }
    }
    
    private static func analyzeMonthlyTrends(completionRecords: [CompletionRecordEntity]) -> [MonthlyTrend] {
        var monthlyData: [String: (month: Int, success: Int, total: Int)] = [:]
        
        for record in completionRecords {
            guard let timestamp = record.timestamp else { continue }
            let month = Calendar.current.component(.month, from: timestamp)
            let year = Calendar.current.component(.year, from: timestamp)
            let monthKey = "\(year)-M\(month)"
            let isSuccess = record.progress > 0
            
            if monthlyData[monthKey] == nil {
                monthlyData[monthKey] = (month, 0, 0)
            }
            
            if isSuccess {
                monthlyData[monthKey]?.success += 1
            }
            monthlyData[monthKey]?.total += 1
        }
        
        return monthlyData.values.map { data in
            MonthlyTrend(
                month: data.month,
                successRate: Double(data.success) / Double(data.total),
                totalHabits: data.total
            )
        }.sorted { $0.month < $1.month }
    }
    
    private static func analyzeSeasonalTrends(completionRecords: [CompletionRecordEntity]) -> [SeasonalTrend] {
        var seasonalData: [Int: (success: Int, total: Int)] = [:]
        
        for record in completionRecords {
            guard let timestamp = record.timestamp else { continue }
            let month = Calendar.current.component(.month, from: timestamp)
            let season = monthToSeason(month)
            let isSuccess = record.progress > 0
            
            if seasonalData[season] == nil {
                seasonalData[season] = (0, 0)
            }
            
            if isSuccess {
                seasonalData[season]?.success += 1
            }
            seasonalData[season]?.total += 1
        }
        
        return seasonalData.map { season, data in
            SeasonalTrend(
                season: season,
                successRate: Double(data.success) / Double(data.total),
                totalHabits: data.total
            )
        }.sorted { $0.season < $1.season }
    }
    
    private static func calculateOverallTrend(weeklyTrends: [WeeklyTrend], monthlyTrends: [MonthlyTrend]) -> TrendDirection {
        // Calculate trend using linear regression on weekly data
        guard weeklyTrends.count >= 3 else { return .stable }
        
        let xValues = weeklyTrends.enumerated().map { Double($0.offset) }
        let yValues = weeklyTrends.map { $0.successRate }
        
        let slope = calculateLinearRegressionSlope(x: xValues, y: yValues)
        
        if slope > 0.01 {
            return .improving
        } else if slope < -0.01 {
            return .declining
        } else {
            return .stable
        }
    }
    
    private static func calculateTrendStrength(overallTrend: TrendDirection) -> TrendStrength {
        // This would be calculated based on R-squared value from regression
        // For now, return a default value
        return .moderate
    }
    
    // MARK: - Comparative Performance Methods
    
    private static func calculatePerformanceRanking(habits: [Habit], completionRecords: [CompletionRecordEntity]) -> [HabitPerformance] {
        var habitPerformances: [HabitPerformance] = []
        
        for habit in habits {
            let habitRecords = completionRecords.filter { record in
                // This would need to be filtered by habit ID in a real implementation
                true // Placeholder
            }
            
            let successRate = calculateSuccessRate(records: habitRecords)
            let totalCompletions = habitRecords.count
            
            habitPerformances.append(HabitPerformance(
                habit: habit,
                successRate: successRate,
                totalCompletions: totalCompletions,
                rank: 0 // Will be set after sorting
            ))
        }
        
        // Sort by success rate and assign ranks
        var sortedPerformances = habitPerformances.sorted { $0.successRate > $1.successRate }
        for index in sortedPerformances.indices {
            sortedPerformances[index].rank = index + 1
        }
        
        return sortedPerformances
    }
    
    private static func analyzeCategoryPerformance(habits: [Habit], completionRecords: [CompletionRecordEntity]) -> [CategoryPerformance] {
        var categoryData: [HabitType: (success: Int, total: Int)] = [:]
        
        for habit in habits {
            let habitRecords = completionRecords.filter { record in
                // This would need to be filtered by habit ID in a real implementation
                true // Placeholder
            }
            
            let success = habitRecords.filter { $0.progress > 0 }.count
            let total = habitRecords.count
            
            if categoryData[habit.habitType] == nil {
                categoryData[habit.habitType] = (0, 0)
            }
            
            categoryData[habit.habitType]?.success += success
            categoryData[habit.habitType]?.total += total
        }
        
        return categoryData.map { habitType, data in
            CategoryPerformance(
                category: habitType,
                successRate: Double(data.success) / Double(data.total),
                totalHabits: data.total
            )
        }
    }
    
    private static func analyzeDifficultyPerformanceCorrelation(habits: [Habit], completionRecords: [CompletionRecordEntity]) -> DifficultyPerformanceCorrelation? {
        // This would analyze how habit difficulty correlates with performance
        // Implementation would depend on difficulty data availability
        return nil
    }
    
    private static func calculateGoalAchievementRates(habits: [Habit], completionRecords: [CompletionRecordEntity]) -> [GoalAchievementRate] {
        var goalData: [String: (achieved: Int, total: Int)] = [:]
        
        for habit in habits {
            let habitRecords = completionRecords.filter { record in
                // This would need to be filtered by habit ID in a real implementation
                true // Placeholder
            }
            
            let goalAmount = parseGoalAmount(from: habit.goal)
            let achieved = habitRecords.filter { $0.progress >= Double(goalAmount) }.count
            let total = habitRecords.count
            
            let goalKey = habit.goal
            if goalData[goalKey] == nil {
                goalData[goalKey] = (0, 0)
            }
            
            goalData[goalKey]?.achieved += achieved
            goalData[goalKey]?.total += total
        }
        
        return goalData.map { goal, data in
            GoalAchievementRate(
                goal: goal,
                achievementRate: Double(data.achieved) / Double(data.total),
                totalAttempts: data.total
            )
        }
    }
    
    // MARK: - Risk Factor Methods
    
    private static func identifyTimeBasedRisk(completionRecords: [CompletionRecordEntity]) -> RiskFactor? {
        var hourFailureRates: [Int: (failure: Int, total: Int)] = [:]
        
        for record in completionRecords {
            guard let timestamp = record.timestamp else { continue }
            let hour = Calendar.current.component(.hour, from: timestamp)
            let isFailure = record.progress == 0
            
            if hourFailureRates[hour] == nil {
                hourFailureRates[hour] = (0, 0)
            }
            
            if isFailure {
                hourFailureRates[hour]?.failure += 1
            }
            hourFailureRates[hour]?.total += 1
        }
        
        // Find the hour with highest failure rate
        guard let riskiestHour = hourFailureRates.max(by: { 
            let rate1 = Double($0.value.failure) / Double($0.value.total)
            let rate2 = Double($1.value.failure) / Double($1.value.total)
            return rate1 < rate2
        }) else { return nil }
        
        let failureRate = Double(riskiestHour.value.failure) / Double(riskiestHour.value.total)
        let timeString = formatHour(riskiestHour.key)
        
        return RiskFactor(
            type: .timeBased,
            description: "High failure rate around \(timeString) (\(Int(failureRate * 100))%)",
            riskLevel: failureRate > 0.7 ? .high : failureRate > 0.5 ? .medium : .low,
            recommendation: "Avoid scheduling this habit around \(timeString) or prepare extra motivation"
        )
    }
    
    private static func identifyDayBasedRisk(completionRecords: [CompletionRecordEntity]) -> RiskFactor? {
        var dayFailureRates: [Int: (failure: Int, total: Int)] = [:]
        
        for record in completionRecords {
            guard let timestamp = record.timestamp else { continue }
            let weekday = Calendar.current.component(.weekday, from: timestamp)
            let isFailure = record.progress == 0
            
            if dayFailureRates[weekday] == nil {
                dayFailureRates[weekday] = (0, 0)
            }
            
            if isFailure {
                dayFailureRates[weekday]?.failure += 1
            }
            dayFailureRates[weekday]?.total += 1
        }
        
        // Find the day with highest failure rate
        guard let riskiestDay = dayFailureRates.max(by: { 
            let rate1 = Double($0.value.failure) / Double($0.value.total)
            let rate2 = Double($1.value.failure) / Double($1.value.total)
            return rate1 < rate2
        }) else { return nil }
        
        let failureRate = Double(riskiestDay.value.failure) / Double(riskiestDay.value.total)
        let dayName = Calendar.current.weekdaySymbols[riskiestDay.key - 1]
        
        return RiskFactor(
            type: .dayBased,
            description: "High failure rate on \(dayName)s (\(Int(failureRate * 100))%)",
            riskLevel: failureRate > 0.7 ? .high : failureRate > 0.5 ? .medium : .low,
            recommendation: "Plan extra support and motivation for \(dayName)s"
        )
    }
    
    private static func identifyDifficultyBasedRisk(completionRecords: [CompletionRecordEntity], difficultyLogs: [DifficultyLogEntity]) -> RiskFactor? {
        // This would identify when difficulty spikes correlate with failures
        // Implementation would depend on difficulty data availability
        return nil
    }
    
    private static func identifyStreakBasedRisk(completionRecords: [CompletionRecordEntity]) -> RiskFactor? {
        // Identify patterns around streak breaks
        let sortedRecords = completionRecords.sorted { 
            ($0.timestamp ?? Date()) < ($1.timestamp ?? Date())
        }
        
        var streakBreaks: [Int] = []
        var currentStreak = 0
        
        for record in sortedRecords {
            if record.progress > 0 {
                currentStreak += 1
            } else {
                if currentStreak > 0 {
                    streakBreaks.append(currentStreak)
                }
                currentStreak = 0
            }
        }
        
        // Find the most common streak length before breaks
        guard let mostCommonStreak = streakBreaks.mostFrequent() else { return nil }
        
        return RiskFactor(
            type: .streakBased,
            description: "Streaks often break after \(mostCommonStreak) days",
            riskLevel: .medium,
            recommendation: "Prepare extra motivation around day \(mostCommonStreak) to maintain momentum"
        )
    }
    
    private static func identifyEnvironmentalRisk(completionRecords: [CompletionRecordEntity]) -> RiskFactor? {
        // This would identify environmental factors like location, weather, etc.
        // Implementation would depend on additional data sources
        return nil
    }
    
    private static func calculateOverallRiskLevel(riskFactors: [RiskFactor]) -> RiskLevel {
        let highRiskCount = riskFactors.filter { $0.riskLevel == .high }.count
        let mediumRiskCount = riskFactors.filter { $0.riskLevel == .medium }.count
        
        if highRiskCount >= 2 {
            return .high
        } else if highRiskCount >= 1 || mediumRiskCount >= 2 {
            return .medium
        } else {
            return .low
        }
    }
    
    // MARK: - Helper Methods
    
    private static func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        
        return formatter.string(from: date)
    }
    
    private static func difficultyLevelName(_ level: Int) -> String {
        switch level {
        case 1: return "Very Easy"
        case 2: return "Easy"
        case 3: return "Medium"
        case 4: return "Hard"
        case 5: return "Very Hard"
        default: return "Unknown"
        }
    }
    
    private static func monthToSeason(_ month: Int) -> Int {
        switch month {
        case 12, 1, 2: return 0 // Winter
        case 3, 4, 5: return 1 // Spring
        case 6, 7, 8: return 2 // Summer
        case 9, 10, 11: return 3 // Fall
        default: return 0
        }
    }
    
    private static func seasonName(_ season: Int) -> String {
        switch season {
        case 0: return "Winter"
        case 1: return "Spring"
        case 2: return "Summer"
        case 3: return "Fall"
        default: return "Unknown"
        }
    }
    
    private static func calculateLinearRegressionSlope(x: [Double], y: [Double]) -> Double {
        guard x.count == y.count && x.count > 1 else { return 0.0 }
        
        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        
        let numerator = n * sumXY - sumX * sumY
        let denominator = n * sumX2 - sumX * sumX
        
        return denominator != 0 ? numerator / denominator : 0.0
    }
    
    private static func calculateSuccessRate(records: [CompletionRecordEntity]) -> Double {
        guard !records.isEmpty else { return 0.0 }
        let successCount = records.filter { $0.progress > 0 }.count
        return Double(successCount) / Double(records.count)
    }
    
    private static func parseGoalAmount(from goalString: String) -> Int {
        // Simple goal parsing - extract number from strings like "5 times", "3 reps", etc.
        let components = goalString.components(separatedBy: CharacterSet.decimalDigits.inverted)
        return components.compactMap { Int($0) }.first ?? 1
    }
    
    // MARK: - Helper Methods
    
    private static func createDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Data Models

struct SuccessCorrelationInsight {
    let habit: Habit
    let correlations: [SuccessCorrelation]
    let strongestCorrelation: SuccessCorrelation?
}

struct SuccessCorrelation {
    let factor: CorrelationFactor
    let value: String
    let correlationStrength: Double
    let description: String
}

enum CorrelationFactor {
    case dayOfWeek
    case timeOfDay
    case difficulty
    case streak
    case seasonal
}

struct PerformanceTrendInsight {
    let habit: Habit
    let weeklyTrends: [WeeklyTrend]
    let monthlyTrends: [MonthlyTrend]
    let seasonalTrends: [SeasonalTrend]
    let overallTrend: TrendDirection
    let trendStrength: TrendStrength
}

struct WeeklyTrend {
    let week: Int
    let successRate: Double
    let totalHabits: Int
}

struct MonthlyTrend {
    let month: Int
    let successRate: Double
    let totalHabits: Int
}

struct SeasonalTrend {
    let season: Int
    let successRate: Double
    let totalHabits: Int
}



enum TrendStrength {
    case weak
    case moderate
    case strong
}

struct ComparativePerformanceInsight {
    let performanceRanking: [HabitPerformance]
    let categoryPerformance: [CategoryPerformance]
    let difficultyPerformance: DifficultyPerformanceCorrelation?
    let goalAchievementRates: [GoalAchievementRate]
}

struct HabitPerformance {
    let habit: Habit
    let successRate: Double
    let totalCompletions: Int
    var rank: Int
}

struct CategoryPerformance {
    let category: HabitType
    let successRate: Double
    let totalHabits: Int
}

struct DifficultyPerformanceCorrelation {
    let correlation: Double
    let description: String
}

struct GoalAchievementRate {
    let goal: String
    let achievementRate: Double
    let totalAttempts: Int
}

struct RiskFactorInsight {
    let habit: Habit
    let riskFactors: [RiskFactor]
    let overallRiskLevel: RiskLevel
}

struct RiskFactor {
    let type: RiskFactorType
    let description: String
    let riskLevel: RiskLevel
    let recommendation: String
}

enum RiskFactorType {
    case timeBased
    case dayBased
    case difficultyBased
    case streakBased
    case environmental
}

enum RiskLevel {
    case low
    case medium
    case high
}

// MARK: - Extensions

extension Array where Element == Int {
    func mostFrequent() -> Int? {
        let counts = self.reduce(into: [:]) { counts, element in
            counts[element, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}
