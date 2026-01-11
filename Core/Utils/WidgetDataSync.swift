//
//  WidgetDataSync.swift
//  Habitto
//
//  Created by Chloe Lee on 2026-01-11.
//

import Foundation

/// Helper class to sync habit data to widgets via App Group UserDefaults
class WidgetDataSync {
    static let shared = WidgetDataSync()
    
    private let appGroupID = "group.com.habitto.widget"
    
    private init() {}
    
    /// Sync all habits data to widget storage
    /// This allows widgets to access habit information for display
    func syncHabitsToWidget(_ habits: [Habit]) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("⚠️ WIDGET_SYNC: Failed to access App Group UserDefaults")
            return
        }
        
        // Convert habits to widget-compatible format
        let widgetHabits = habits.map { habit in
            HabitWidgetData(
                id: habit.id,
                name: habit.name,
                icon: habit.icon,
                colorHex: habit.color.color.toHex(),
                completionHistory: habit.completionHistory,
                completionStatus: habit.completionStatus
            )
        }
        
        // Save all habits as an array
        if let encoded = try? JSONEncoder().encode(widgetHabits) {
            sharedDefaults.set(encoded, forKey: "widgetHabits")
        }
        
        // Also save each habit individually for faster lookup
        for habit in habits {
            let widgetData = HabitWidgetData(
                id: habit.id,
                name: habit.name,
                icon: habit.icon,
                colorHex: habit.color.color.toHex(),
                completionHistory: habit.completionHistory,
                completionStatus: habit.completionStatus
            )
            
            if let encoded = try? JSONEncoder().encode(widgetData) {
                sharedDefaults.set(encoded, forKey: "widgetHabit_\(habit.id.uuidString)")
            }
        }
        
        sharedDefaults.synchronize()
        print("📱 WIDGET_SYNC: Synced \(habits.count) habits to widget storage")
    }
    
    /// Sync a single habit to widget storage
    func syncHabitToWidget(_ habit: Habit) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("⚠️ WIDGET_SYNC: Failed to access App Group UserDefaults")
            return
        }
        
        let widgetData = HabitWidgetData(
            id: habit.id,
            name: habit.name,
            icon: habit.icon,
            colorHex: habit.color.color.toHex(),
            completionHistory: habit.completionHistory,
            completionStatus: habit.completionStatus
        )
        
        if let encoded = try? JSONEncoder().encode(widgetData) {
            sharedDefaults.set(encoded, forKey: "widgetHabit_\(habit.id.uuidString)")
            sharedDefaults.synchronize()
            print("📱 WIDGET_SYNC: Synced habit '\(habit.name)' to widget storage")
        }
    }
}
