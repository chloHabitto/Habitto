import SwiftUI

struct PatternInsightsSection: View {
    let habit: Habit?
    let completionRecords: [CompletionRecordEntity]
    let difficultyLogs: [DifficultyLogEntity]
    
    var body: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Text("Pattern Analysis")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            if let habit = habit {
                // Individual habit pattern insights
                IndividualHabitPatternInsights(
                    habit: habit,
                    completionRecords: completionRecords,
                    difficultyLogs: difficultyLogs
                )
            } else {
                // Overall pattern insights
                OverallPatternInsights(
                    completionRecords: completionRecords,
                    difficultyLogs: difficultyLogs
                )
            }
        }
    }
}

// MARK: - Individual Habit Pattern Insights
struct IndividualHabitPatternInsights: View {
    let habit: Habit
    let completionRecords: [CompletionRecordEntity]
    let difficultyLogs: [DifficultyLogEntity]
    
    var body: some View {
        VStack(spacing: 12) {
            // Success Correlations
            if let correlationInsight = HabitPatternAnalyzer.analyzeSuccessCorrelations(
                for: habit,
                completionRecords: completionRecords,
                difficultyLogs: difficultyLogs
            ) {
                SuccessCorrelationsCard(correlationInsight: correlationInsight)
            }
            
            // Performance Trends
            if let trendInsight = HabitPatternAnalyzer.analyzePerformanceTrends(
                for: habit,
                completionRecords: completionRecords
            ) {
                PerformanceTrendsCard(trendInsight: trendInsight)
            }
            
            // Risk Factors
            if let riskInsight = HabitPatternAnalyzer.identifyRiskFactors(
                for: habit,
                completionRecords: completionRecords,
                difficultyLogs: difficultyLogs
            ) {
                RiskFactorsCard(riskInsight: riskInsight)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Overall Pattern Insights
struct OverallPatternInsights: View {
    let completionRecords: [CompletionRecordEntity]
    let difficultyLogs: [DifficultyLogEntity]
    
    var body: some View {
        VStack(spacing: 12) {
            // This would show comparative performance across all habits
            // For now, show a placeholder
            Text("Overall pattern insights would appear here")
                .font(.appBodyMedium)
                .foregroundColor(.text03)
                .padding()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Success Correlations Card
struct SuccessCorrelationsCard: View {
    let correlationInsight: SuccessCorrelationInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                    .frame(width: 32, height: 32)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Success Correlations")
                        .font(.appBodyMedium)
                        .foregroundColor(.text01)
                    
                    Text("What helps you succeed")
                        .font(.appLabelSmall)
                        .foregroundColor(.text03)
                }
                
                Spacer()
            }
            
            // Show strongest correlation prominently
            if let strongest = correlationInsight.strongestCorrelation {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Strongest Factor")
                        .font(.appLabelSmall)
                        .foregroundColor(.text03)
                    
                    HStack {
                        Text(strongest.value)
                            .font(.appTitleSmallEmphasised)
                            .foregroundColor(.text01)
                        
                        Spacer()
                        
                        Text("\(Int(strongest.correlationStrength * 100))%")
                            .font(.appBodyMedium)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }
                    
                    Text(strongest.description)
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
                .background(Color.green.opacity(0.05))
                .cornerRadius(8)
            }
            
            // Show all correlations
            VStack(spacing: 8) {
                ForEach(Array(correlationInsight.correlations.enumerated()), id: \.offset) { index, correlation in
                    CorrelationRow(correlation: correlation)
                    
                    if index < correlationInsight.correlations.count - 1 {
                        Divider()
                            .background(Color.outline3)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.outline3, lineWidth: 1)
        )
    }
}

// MARK: - Correlation Row
struct CorrelationRow: View {
    let correlation: SuccessCorrelation
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(correlation.factor.displayName)
                    .font(.appLabelSmall)
                    .foregroundColor(.text03)
                
                Text(correlation.value)
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(correlation.correlationStrength * 100))%")
                    .font(.appBodyMedium)
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
                
                Text("success rate")
                    .font(.appLabelSmall)
                    .foregroundColor(.text03)
            }
        }
    }
}

// MARK: - Performance Trends Card
struct PerformanceTrendsCard: View {
    let trendInsight: PerformanceTrendInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: trendIcon)
                    .font(.system(size: 16))
                    .foregroundColor(trendColor)
                    .frame(width: 32, height: 32)
                    .background(trendColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance Trends")
                        .font(.appBodyMedium)
                        .foregroundColor(.text01)
                    
                    Text(trendDescription)
                        .font(.appLabelSmall)
                        .foregroundColor(.text03)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(trendStrengthText)
                        .font(.appLabelSmall)
                        .foregroundColor(.text03)
                    
                    Text(trendInsight.trendStrength.displayName)
                        .font(.appBodyMedium)
                        .foregroundColor(trendColor)
                        .fontWeight(.semibold)
                }
            }
            
            // Trend visualization
            if trendInsight.weeklyTrends.count >= 3 {
                WeeklyTrendChart(weeklyTrends: trendInsight.weeklyTrends)
            }
            
            // Monthly summary
            if !trendInsight.monthlyTrends.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monthly Performance")
                        .font(.appLabelSmall)
                        .foregroundColor(.text03)
                    
                    HStack(spacing: 16) {
                        ForEach(Array(trendInsight.monthlyTrends.prefix(3).enumerated()), id: \.offset) { index, trend in
                            VStack(spacing: 4) {
                                Text(monthName(trend.month))
                                    .font(.appLabelSmall)
                                    .foregroundColor(.text03)
                                
                                Text("\(Int(trend.successRate * 100))%")
                                    .font(.appBodyMedium)
                                    .foregroundColor(.text01)
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(Color.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.outline3, lineWidth: 1)
        )
    }
    
    private var trendIcon: String {
        switch trendInsight.overallTrend {
        case .improving:
            return "arrow.up.circle.fill"
        case .declining:
            return "arrow.down.circle.fill"
        case .stable:
            return "minus.circle.fill"
        }
    }
    
    private var trendColor: Color {
        switch trendInsight.overallTrend {
        case .improving:
            return .green
        case .declining:
            return .red
        case .stable:
            return .blue
        }
    }
    
    private var trendDescription: String {
        switch trendInsight.overallTrend {
        case .improving:
            return "Getting better over time"
        case .declining:
            return "Performance declining"
        case .stable:
            return "Consistent performance"
        }
    }
    
    private var trendStrengthText: String {
        "Strength"
    }
    
    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let date = Calendar.current.date(from: DateComponents(month: month)) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Risk Factors Card
struct RiskFactorsCard: View {
    let riskInsight: RiskFactorInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(riskColor)
                    .frame(width: 32, height: 32)
                    .background(riskColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Risk Factors")
                        .font(.appBodyMedium)
                        .foregroundColor(.text01)
                    
                    Text("What to watch out for")
                        .font(.appLabelSmall)
                        .foregroundColor(.text03)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Overall Risk")
                        .font(.appLabelSmall)
                        .foregroundColor(.text03)
                    
                    Text(riskInsight.overallRiskLevel.displayName)
                        .font(.appBodyMedium)
                        .foregroundColor(riskColor)
                        .fontWeight(.semibold)
                }
            }
            
            // Risk factors list
            VStack(spacing: 8) {
                ForEach(Array(riskInsight.riskFactors.enumerated()), id: \.offset) { index, riskFactor in
                    RiskFactorRow(riskFactor: riskFactor)
                    
                    if index < riskInsight.riskFactors.count - 1 {
                        Divider()
                            .background(Color.outline3)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.outline3, lineWidth: 1)
        )
    }
    
    private var riskColor: Color {
        switch riskInsight.overallRiskLevel {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}

// MARK: - Risk Factor Row
struct RiskFactorRow: View {
    let riskFactor: RiskFactor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(riskLevelColor)
                    .frame(width: 8, height: 8)
                
                Text(riskFactor.type.displayName)
                    .font(.appLabelSmall)
                    .foregroundColor(.text03)
                
                Spacer()
                
                Text(riskFactor.riskLevel.displayName)
                    .font(.appLabelSmall)
                    .foregroundColor(riskLevelColor)
                    .fontWeight(.semibold)
            }
            
            Text(riskFactor.description)
                .font(.appBodySmall)
                .foregroundColor(.text01)
                .multilineTextAlignment(.leading)
            
            Text(riskFactor.recommendation)
                .font(.appBodySmall)
                .foregroundColor(.blue)
                .multilineTextAlignment(.leading)
        }
    }
    
    private var riskLevelColor: Color {
        switch riskFactor.riskLevel {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}

// MARK: - Weekly Trend Chart
struct WeeklyTrendChart: View {
    let weeklyTrends: [WeeklyTrend]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Progress")
                .font(.appLabelSmall)
                .foregroundColor(.text03)
            
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(weeklyTrends.enumerated()), id: \.offset) { index, trend in
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(trend.successRate > 0.5 ? Color.green : Color.orange)
                            .frame(height: max(20, trend.successRate * 60))
                            .cornerRadius(2)
                        
                        Text("W\(trend.week)")
                            .font(.system(size: 10))
                            .foregroundColor(.text04)
                    }
                }
            }
            .frame(height: 80)
        }
    }
}

// MARK: - Extensions

extension CorrelationFactor {
    var displayName: String {
        switch self {
        case .dayOfWeek:
            return "Day of Week"
        case .timeOfDay:
            return "Time of Day"
        case .difficulty:
            return "Difficulty Level"
        case .streak:
            return "Streak Length"
        case .seasonal:
            return "Season"
        }
    }
}

extension TrendStrength {
    var displayName: String {
        switch self {
        case .weak:
            return "Weak"
        case .moderate:
            return "Moderate"
        case .strong:
            return "Strong"
        }
    }
}

extension RiskLevel {
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
}

extension RiskFactorType {
    var displayName: String {
        switch self {
        case .timeBased:
            return "Time-Based"
        case .dayBased:
            return "Day-Based"
        case .difficultyBased:
            return "Difficulty-Based"
        case .streakBased:
            return "Streak-Based"
        case .environmental:
            return "Environmental"
        }
    }
}

#Preview {
    PatternInsightsSection(habit: nil, completionRecords: [], difficultyLogs: [])
}
