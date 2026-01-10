//
//  HabitWidgetEntry.swift
//  HabittoWidget
//
//  Timeline entry model for widget data
//

import WidgetKit

/// Timeline entry containing habit data for the widget
struct HabitWidgetEntry: TimelineEntry {
    let date: Date
    
    // Habit data (placeholder for now, will be replaced with real data via App Groups)
    let habits: [HabitItem]
    
    /// Sample placeholder entry for previews and placeholder views
    static var placeholder: HabitWidgetEntry {
        HabitWidgetEntry(
            date: Date(),
            habits: HabitItem.sampleHabits
        )
    }
}

/// Represents a single habit item in the widget
/// This is a simplified version that matches the widget's needs
struct HabitItem: Identifiable {
    let id: UUID
    let name: String
    let icon: String // SF Symbol name
    let color: String // Hex color string (e.g., "#FF5733") or color name for samples
    let isCompleted: Bool
    let streak: Int
    let goal: String // e.g., "1 time", "2 times per day"
    
    /// Sample habits for placeholder/mock data
    static var sampleHabits: [HabitItem] {
        [
            HabitItem(
                id: UUID(),
                name: "Morning Meditation",
                icon: "leaf.fill",
                color: "green",
                isCompleted: true,
                streak: 7,
                goal: "1 time per day"
            ),
            HabitItem(
                id: UUID(),
                name: "Exercise",
                icon: "figure.run",
                color: "blue",
                isCompleted: false,
                streak: 5,
                goal: "30 minutes"
            ),
            HabitItem(
                id: UUID(),
                name: "Read 10 Pages",
                icon: "book.fill",
                color: "purple",
                isCompleted: true,
                streak: 12,
                goal: "10 pages"
            )
        ]
    }
}
