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
    
    /// Retrieves habit data (placeholder implementation)
    /// TODO: Replace with App Groups data access when shared data is set up
    private func getHabitData() -> [HabitItem] {
        // For now, return sample data
        // Later: Read from UserDefaults/App Groups shared container
        return HabitItem.sampleHabits
    }
}
