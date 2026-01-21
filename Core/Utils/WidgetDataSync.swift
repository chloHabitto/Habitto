//
//  WidgetDataSync.swift
//  Habitto
//
//  Created by Chloe Lee on 2026-01-11.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

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
            return HabitWidgetData(
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
        } else {
            print("❌ WIDGET SYNC: Failed to encode widgetHabits array")
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
                let key = "widgetHabit_\(habit.id.uuidString)"
                sharedDefaults.set(encoded, forKey: key)
            } else {
                print("❌ WIDGET SYNC: Failed to encode habit '\(habit.name)'")
            }
        }
        
        sharedDefaults.synchronize()
        
        // Reload widget timelines to force immediate update
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
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
            let key = "widgetHabit_\(habit.id.uuidString)"
            sharedDefaults.set(encoded, forKey: key)
            sharedDefaults.synchronize()
            
            // Reload widget timelines to force immediate update
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } else {
            print("❌ WIDGET SYNC: Failed to encode habit '\(habit.name)'")
        }
    }
    
    /// Update the selected habit ID for the monthly progress widget
    /// This is used as a fallback when the widget configuration doesn't have a habit selected
    func updateSelectedMonthlyWidgetHabit(id: UUID) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("⚠️ WIDGET_SYNC: Failed to access App Group UserDefaults")
            return
        }
        
        sharedDefaults.set(id.uuidString, forKey: "selectedMonthlyWidgetHabitId")
        sharedDefaults.synchronize()
        
        // Reload widget timelines to force immediate update
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "MonthlyProgressWidget")
        #endif
    }
    
    /// Remove the selected habit ID for the monthly progress widget
    func removeSelectedMonthlyWidgetHabit() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("⚠️ WIDGET_SYNC: Failed to access App Group UserDefaults")
            return
        }
        
        sharedDefaults.removeObject(forKey: "selectedMonthlyWidgetHabitId")
        sharedDefaults.synchronize()
        
        // Reload widget timelines to force immediate update
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "MonthlyProgressWidget")
        #endif
    }
}
