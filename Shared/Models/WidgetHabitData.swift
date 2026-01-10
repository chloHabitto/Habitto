//
//  WidgetHabitData.swift
//  Shared
//
//  Lightweight Codable model for sharing habit data between main app and widget
//  This file must be added to BOTH Habitto and HabittoWidget targets
//

import Foundation

/// Lightweight habit data for widget display
/// This model is shared between the main app and widget extension
struct WidgetHabitData: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let icon: String           // SF Symbol name
    let colorHex: String       // Hex color string (e.g., "#FF5733")
    let isCompletedToday: Bool
    let currentStreak: Int
    let todayProgress: Int     // Current progress count
    let todayGoal: Int         // Goal count (e.g., 3 for "3 times")
    let habitType: String      // "Habit Building" or "Habit Breaking"
}

/// Container for all widget data
/// Snapshot of the current state that the widget can display
struct WidgetDataSnapshot: Codable, Equatable {
    let habits: [WidgetHabitData]
    let totalHabitsToday: Int
    let completedHabitsToday: Int
    let lastUpdated: Date
    let userDisplayName: String?  // Optional user name
    let currentXP: Int
    let currentLevel: Int
    
    /// Empty snapshot for fallback/default state
    static var empty: WidgetDataSnapshot {
        WidgetDataSnapshot(
            habits: [],
            totalHabitsToday: 0,
            completedHabitsToday: 0,
            lastUpdated: Date(),
            userDisplayName: nil,
            currentXP: 0,
            currentLevel: 1
        )
    }
}
