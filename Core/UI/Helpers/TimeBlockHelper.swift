import Foundation

// MARK: - Time Block Helper
struct TimeBlockHelper {
    
    // MARK: - Time Block Definitions
    enum TimeBlock: String, CaseIterable {
        case morning = "morning"      // 6:00 AM - 11:59 AM
        case afternoon = "afternoon"  // 12:00 PM - 5:59 PM  
        case evening = "evening"      // 6:00 PM - 11:59 PM
        case night = "night"          // 12:00 AM - 5:59 AM
        
        // MARK: - Time Block from Date
        static func fromTime(_ date: Date) -> TimeBlock {
            let hour = Calendar.current.component(.hour, from: date)
            switch hour {
            case 6..<12: return .morning
            case 12..<18: return .afternoon
            case 18..<24: return .evening
            default: return .night
            }
        }
        
        // MARK: - Display Name
        var displayName: String {
            switch self {
            case .morning: return "Morning"
            case .afternoon: return "Afternoon"
            case .evening: return "Evening"
            case .night: return "Night"
            }
        }
        
        // MARK: - Time Range Description
        var timeRange: String {
            switch self {
            case .morning: return "6:00 AM - 12:00 PM"
            case .afternoon: return "12:00 PM - 6:00 PM"
            case .evening: return "6:00 PM - 12:00 AM"
            case .night: return "12:00 AM - 6:00 AM"
            }
        }
        
        // MARK: - Icon
        var icon: String {
            switch self {
            case .morning: return "sunrise.fill"
            case .afternoon: return "sun.max.fill"
            case .evening: return "sunset.fill"
            case .night: return "moon.fill"
            }
        }
    }
    
    // MARK: - Time Block Analysis
    struct TimeBlockAnalysis {
        let timeBlock: TimeBlock
        let completionCount: Int
        let totalOpportunities: Int
        let successRate: Double
        
        var successRatePercentage: String {
            return "\(Int(successRate * 100))%"
        }
    }
    
    // MARK: - Analyze Time Patterns for a Habit
    static func analyzeTimePatterns(for habit: Habit, completionRecords: [CompletionRecordEntity]) -> [TimeBlockAnalysis] {
        var analysis: [TimeBlock: (completed: Int, total: Int)] = [:]
        
        // Initialize all time blocks
        for timeBlock in TimeBlock.allCases {
            analysis[timeBlock] = (completed: 0, total: 0)
        }
        
        // Analyze completion records
        for record in completionRecords {
            if let timestamp = record.timestamp {
                let timeBlock = TimeBlock.fromTime(timestamp)
                let current = analysis[timeBlock] ?? (completed: 0, total: 0)
                
                if record.progress > 0 {
                    analysis[timeBlock] = (completed: current.completed + 1, total: current.total + 1)
                } else {
                    analysis[timeBlock] = (completed: current.completed, total: current.total + 1)
                }
            }
        }
        
        // Convert to TimeBlockAnalysis array
        return analysis.map { timeBlock, data in
            let successRate = data.total > 0 ? Double(data.completed) / Double(data.total) : 0.0
            return TimeBlockAnalysis(
                timeBlock: timeBlock,
                completionCount: data.completed,
                totalOpportunities: data.total,
                successRate: successRate
            )
        }.sorted { $0.successRate > $1.successRate }
    }
    
    // MARK: - Get Optimal Time Block
    static func getOptimalTimeBlock(for habit: Habit, completionRecords: [CompletionRecordEntity]) -> TimeBlock? {
        let analysis = analyzeTimePatterns(for: habit, completionRecords: completionRecords)
        return analysis.first?.timeBlock
    }
    
    // MARK: - Get Time Block Insight
    static func getTimeBlockInsight(for habit: Habit, completionRecords: [CompletionRecordEntity]) -> String? {
        let analysis = analyzeTimePatterns(for: habit, completionRecords: completionRecords)
        
        guard let best = analysis.first, let worst = analysis.last else { return nil }
        
        if best.successRate > 0.7 && worst.successRate < 0.3 {
            let difference = Int((best.successRate - worst.successRate) * 100)
            return "This habit has \(difference)% higher completion rate in \(best.timeBlock.displayName.lowercased())s (\(best.successRatePercentage)) compared to \(worst.timeBlock.displayName.lowercased())s (\(worst.successRatePercentage))."
        }
        
        if best.successRate > 0.8 {
            return "Your best time for this habit is \(best.timeBlock.displayName.lowercased())s with \(best.successRatePercentage) success rate."
        }
        
        return nil
    }
}
