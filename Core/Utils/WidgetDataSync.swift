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
        print("🔵 WIDGET SYNC: Syncing \(habits.count) habits to widget")
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("⚠️ WIDGET_SYNC: Failed to access App Group UserDefaults")
            return
        }
        
        // Convert habits to widget-compatible format
        let widgetHabits = habits.map { habit in
            let historyCount = habit.completionHistory.count
            let statusCount = habit.completionStatus.count
            print("   Habit: \(habit.name)")
            print("      completionHistory: \(historyCount) entries")
            print("      completionStatus: \(statusCount) entries")
            
            // Print recent completion data
            let recentKeys = habit.completionStatus.keys.sorted().suffix(7)
            for key in recentKeys {
                let status = habit.completionStatus[key] ?? false
                print("      \(key): \(status ? "✅ completed" : "❌ not completed")")
            }
            
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
            print("✅ WIDGET SYNC: Saved \(encoded.count) bytes to App Group (key: 'widgetHabits')")
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
                print("✅ WIDGET SYNC: Saved habit '\(habit.name)' (\(encoded.count) bytes) to key '\(key)'")
            } else {
                print("❌ WIDGET SYNC: Failed to encode habit '\(habit.name)'")
            }
        }
        
        sharedDefaults.synchronize()
        
        // Verify data was saved
        let keys = sharedDefaults.dictionaryRepresentation().keys.filter { $0.contains("widget") }
        print("🔍 WIDGET SYNC: App Group keys after save: \(Array(keys).sorted())")
        if let savedData = sharedDefaults.data(forKey: "widgetHabits") {
            print("🔍 WIDGET SYNC: Verified 'widgetHabits' key exists (\(savedData.count) bytes)")
        }
        
        print("📱 WIDGET_SYNC: Synced \(habits.count) habits to widget storage")
        
        // Reload widget timelines to force immediate update
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    /// Sync a single habit to widget storage
    func syncHabitToWidget(_ habit: Habit) {
        print("🔵 WIDGET SYNC: Syncing single habit '\(habit.name)' to widget")
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("⚠️ WIDGET_SYNC: Failed to access App Group UserDefaults")
            return
        }
        
        let historyCount = habit.completionHistory.count
        let statusCount = habit.completionStatus.count
        print("   Habit: \(habit.name)")
        print("      completionHistory: \(historyCount) entries")
        print("      completionStatus: \(statusCount) entries")
        
        // Print recent completion data
        let recentKeys = habit.completionStatus.keys.sorted().suffix(7)
        for key in recentKeys {
            let status = habit.completionStatus[key] ?? false
            print("      \(key): \(status ? "✅ completed" : "❌ not completed")")
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
            print("✅ WIDGET SYNC: Saved habit '\(habit.name)' (\(encoded.count) bytes) to key '\(key)'")
            
            // Reload widget timelines to force immediate update
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } else {
            print("❌ WIDGET SYNC: Failed to encode habit '\(habit.name)'")
        }
    }
}
