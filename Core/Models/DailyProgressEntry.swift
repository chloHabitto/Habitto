//
//  DailyProgressEntry.swift
//  Habitto
//
//  Represents a single entry in the daily activity timeline
//  Used to display chronological progress entries for a habit on a specific day
//

import Foundation

/// Represents a single entry in the daily activity timeline
struct DailyProgressEntry: Identifiable {
    let id: UUID
    let timestamp: Date              // When this progress was logged
    let progressDelta: Int           // +1, +2, -1, etc.
    let runningTotal: Int            // Cumulative progress after this entry
    let goalAmount: Int              // Goal for the day
    let difficulty: Int?             // Difficulty rating if recorded (1-5)
    let eventType: String            // INCREMENT, DECREMENT, SET, TOGGLE_COMPLETE
    
    // MARK: - Computed Properties
    
    /// Whether the goal was reached at this entry
    var isCompleted: Bool {
        runningTotal >= goalAmount
    }
    
    /// Progress percentage (0.0 to 1.0)
    var progressPercentage: Double {
        guard goalAmount > 0 else { return 0 }
        return min(Double(runningTotal) / Double(goalAmount), 1.0)
    }
    
    /// Formatted time string (e.g., "7:15")
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: timestamp)
    }
    
    /// AM/PM string
    var amPmString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter.string(from: timestamp)
    }
    
    /// Icon representing time of day
    var timePeriodIcon: String {
        let hour = Calendar.current.component(.hour, from: timestamp)
        switch hour {
        case 5..<12: return "☀️"   // Morning
        case 12..<14: return "☕"  // Lunch
        case 14..<20: return "🌅"  // Evening
        default: return "🌙"       // Night
        }
    }
    
    /// Display text for progress delta (e.g., "+1 session", "-2 (undone)")
    var deltaDisplayText: String {
        if progressDelta > 0 {
            return "+\(progressDelta) \(progressDelta == 1 ? "session" : "sessions")"
        } else if progressDelta < 0 {
            return "\(progressDelta) (undone)"
        }
        return "Set to \(runningTotal)"
    }
}
