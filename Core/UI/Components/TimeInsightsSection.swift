import SwiftUI

struct TimeInsightsSection: View {
    let habit: Habit?
    let completionRecords: [CompletionRecordEntity]
    
    var body: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Text("Time-Based Insights")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            if let habit = habit {
                // Individual habit time insights
                IndividualHabitTimeInsights(habit: habit, completionRecords: completionRecords)
            } else {
                // Overall time patterns
                OverallTimePatterns(completionRecords: completionRecords)
            }
        }
    }
}

// MARK: - Individual Habit Time Insights
struct IndividualHabitTimeInsights: View {
    let habit: Habit
    let completionRecords: [CompletionRecordEntity]
    
    var body: some View {
        VStack(spacing: 12) {
            // Time of day analysis
            if let timeInsight = TimePatternAnalyzer.analyzeOptimalTimeOfDay(for: habit, completionRecords: completionRecords) {
                TimeOfDayCard(timeInsight: timeInsight, habitName: habit.name)
            }
            
            // Time consistency analysis
            if let consistencyInsight = TimePatternAnalyzer.analyzeTimeConsistency(for: habit, completionRecords: completionRecords) {
                TimeConsistencyCard(consistencyInsight: consistencyInsight)
            }
            
            // Recommendations
            if let timeInsight = TimePatternAnalyzer.analyzeOptimalTimeOfDay(for: habit, completionRecords: completionRecords),
               let consistencyInsight = TimePatternAnalyzer.analyzeTimeConsistency(for: habit, completionRecords: completionRecords) {
                let recommendations = TimePatternAnalyzer.generateTimeBasedRecommendations(
                    for: habit,
                    timeInsight: timeInsight,
                    consistencyInsight: consistencyInsight
                )
                TimeRecommendationsCard(recommendations: recommendations)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Overall Time Patterns
struct OverallTimePatterns: View {
    let completionRecords: [CompletionRecordEntity]
    
    var body: some View {
        VStack(spacing: 12) {
            if let globalInsight = TimePatternAnalyzer.analyzeGlobalTimePatterns(habits: [], completionRecords: completionRecords) {
                GlobalTimePatternsCard(globalInsight: globalInsight)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Time of Day Card
struct TimeOfDayCard: View {
    let timeInsight: TimeOfDayInsight
    let habitName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Peak Performance Time")
                        .font(.appBodyMedium)
                        .foregroundColor(.text01)
                    
                    Text("\(formatHour(timeInsight.optimalHour))")
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(.text01)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Success Rate")
                        .font(.appLabelSmall)
                        .foregroundColor(.text03)
                    
                    Text("\(Int(timeInsight.successRate * 100))%")
                        .font(.appBodyMedium)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
            }
            
            // Hourly breakdown chart
            if timeInsight.totalCompletions >= 3 {
                HourlyBreakdownChart(hourlyBreakdown: timeInsight.hourlyBreakdown)
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
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        
        return formatter.string(from: date)
    }
}

// MARK: - Time Consistency Card
struct TimeConsistencyCard: View {
    let consistencyInsight: TimeConsistencyInsight
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: consistencyIcon)
                .font(.system(size: 16))
                .foregroundColor(consistencyColor)
                .frame(width: 32, height: 32)
                .background(consistencyColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Time Consistency")
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                
                Text(consistencyTitle)
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.text01)
                
                Text("Based on \(consistencyInsight.totalCompletions) completions")
                    .font(.appLabelSmall)
                    .foregroundColor(.text03)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.outline3, lineWidth: 1)
        )
    }
    
    private var consistencyIcon: String {
        switch consistencyInsight.consistencyLevel {
        case .veryConsistent:
            return "checkmark.circle.fill"
        case .consistent:
            return "checkmark.circle"
        case .moderate:
            return "exclamationmark.circle"
        case .inconsistent:
            return "xmark.circle"
        }
    }
    
    private var consistencyColor: Color {
        switch consistencyInsight.consistencyLevel {
        case .veryConsistent:
            return .green
        case .consistent:
            return .blue
        case .moderate:
            return .orange
        case .inconsistent:
            return .red
        }
    }
    
    private var consistencyTitle: String {
        switch consistencyInsight.consistencyLevel {
        case .veryConsistent:
            return "Very Consistent"
        case .consistent:
            return "Consistent"
        case .moderate:
            return "Moderate"
        case .inconsistent:
            return "Inconsistent"
        }
    }
}

// MARK: - Time Recommendations Card
struct TimeRecommendationsCard: View {
    let recommendations: [TimeRecommendation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)
                    .frame(width: 32, height: 32)
                    .background(Color.yellow.opacity(0.1))
                    .clipShape(Circle())
                
                Text("Recommendations")
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                    RecommendationRow(recommendation: recommendation)
                    
                    if index < recommendations.count - 1 {
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

// MARK: - Recommendation Row
struct RecommendationRow: View {
    let recommendation: TimeRecommendation
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                
                Text(recommendation.description)
                    .font(.appBodySmall)
                    .foregroundColor(.text02)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
    
    private var priorityColor: Color {
        switch recommendation.priority {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}

// MARK: - Global Time Patterns Card
struct GlobalTimePatternsCard: View {
    let globalInsight: GlobalTimeInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.purple)
                    .frame(width: 32, height: 32)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Most Productive Hours")
                        .font(.appBodyMedium)
                        .foregroundColor(.text01)
                    
                    Text("Across all habits")
                        .font(.appLabelSmall)
                        .foregroundColor(.text03)
                }
                
                Spacer()
            }
            
            // Top productive hours
            VStack(spacing: 8) {
                ForEach(Array(globalInsight.topProductiveHours.enumerated()), id: \.offset) { index, hourData in
                    HStack {
                        Text("\(index + 1).")
                            .font(.appLabelMedium)
                            .foregroundColor(.text03)
                            .frame(width: 20, alignment: .leading)
                        
                        Text(formatHour(hourData.key))
                            .font(.appBodyMedium)
                            .foregroundColor(.text01)
                        
                        Spacer()
                        
                        Text("\(hourData.value) completions")
                            .font(.appLabelSmall)
                            .foregroundColor(.text03)
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
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        
        return formatter.string(from: date)
    }
}

// MARK: - Hourly Breakdown Chart
struct HourlyBreakdownChart: View {
    let hourlyBreakdown: [Int: Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hourly Completion Pattern")
                .font(.appLabelSmall)
                .foregroundColor(.text03)
            
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    let completions = hourlyBreakdown[hour] ?? 0
                    let maxCompletions = hourlyBreakdown.values.max() ?? 1
                    let height = maxCompletions > 0 ? CGFloat(completions) / CGFloat(maxCompletions) : 0
                    
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(completions > 0 ? Color.blue : Color.outline3)
                            .frame(height: max(20, height * 60))
                            .cornerRadius(2)
                        
                        if hour % 3 == 0 {
                            Text("\(hour)")
                                .font(.system(size: 10))
                                .foregroundColor(.text04)
                        }
                    }
                }
            }
            .frame(height: 80)
        }
    }
}

#Preview {
    TimeInsightsSection(habit: nil, completionRecords: [])
}
