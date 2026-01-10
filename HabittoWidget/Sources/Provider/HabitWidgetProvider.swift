//
//  HabitWidgetProvider.swift
//  HabittoWidget
//
//  Timeline provider that generates widget entries
//

import WidgetKit
import SwiftUI

/// Provides timeline entries for the habit widget
/// Currently uses placeholder data - will be updated to read from App Groups
struct HabitWidgetProvider: TimelineProvider {
    
    typealias Entry = HabitWidgetEntry
    
    /// Placeholder entry shown while widget loads
    func placeholder(in context: Context) -> HabitWidgetEntry {
        HabitWidgetEntry.placeholder
    }
    
    /// Snapshot entry for widget gallery previews
    func getSnapshot(in context: Context, completion: @escaping (HabitWidgetEntry) -> Void) {
        // For snapshots (preview in widget gallery), use current data
        let entry = HabitWidgetEntry(
            date: Date(),
            habits: getHabitData()
        )
        completion(entry)
    }
    
    /// Generates timeline entries for the widget
    /// Currently returns placeholder data - will be updated when App Groups are set up
    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitWidgetEntry>) -> Void) {
        // Generate timeline entries
        var entries: [HabitWidgetEntry] = []
        let currentDate = Date()
        
        // For now, create entries for the next 24 hours
        // Update every hour, or when habit data changes
        for hourOffset in 0..<24 {
            if let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate) {
                let entry = HabitWidgetEntry(
                    date: entryDate,
                    habits: getHabitData()
                )
                entries.append(entry)
            }
        }
        
        // Refresh policy: refresh at end of timeline (24 hours) or when habit data changes
        // TODO: Update refresh policy when App Groups are set up
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    // MARK: - Private Helpers
    
    /// Retrieves habit data from App Group UserDefaults
    /// Falls back to sample data if no real data is available
    private func getHabitData() -> [HabitItem] {
        guard let snapshot = WidgetDataService.shared.loadSnapshot() else {
            // Fallback to samples if no data available (first launch or error)
            return HabitItem.sampleHabits
        }
        
        // Convert WidgetHabitData to HabitItem for widget views
        return snapshot.habits.map { habit in
            HabitItem(
                id: habit.id,
                name: habit.name,
                icon: habit.icon,
                color: habit.colorHex, // Store as hex string, convert in view
                isCompleted: habit.isCompletedToday,
                streak: habit.currentStreak,
                goal: "\(habit.todayGoal) \(habit.todayGoal == 1 ? "time" : "times")"
            )
        }
    }
}
