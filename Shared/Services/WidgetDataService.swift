//
//  WidgetDataService.swift
//  Shared
//
//  Service for sharing data between main app and widget via App Groups
//  This file must be added to BOTH Habitto and HabittoWidget targets
//

import Foundation
import WidgetKit

/// Service for sharing data between main app and widget via App Groups
/// Uses UserDefaults with App Group suite for cross-target data access
final class WidgetDataService {
    static let shared = WidgetDataService()
    
    private let appGroupIdentifier = "group.com.habitto.widget"
    private let widgetDataKey = "widgetHabitData"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    private init() {}
    
    // MARK: - Write (Main App)
    
    /// Save widget data snapshot (called from main app)
    /// This method is called when habit data changes in the main app
    func saveSnapshot(_ snapshot: WidgetDataSnapshot) {
        guard let defaults = sharedDefaults else {
            print("❌ WidgetDataService: Failed to access App Group UserDefaults with identifier '\(appGroupIdentifier)'")
            print("   Make sure both targets have the App Group capability enabled")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            defaults.set(data, forKey: widgetDataKey)
            print("✅ WidgetDataService: Saved \(snapshot.habits.count) habits to widget data")
            print("   - Total: \(snapshot.totalHabitsToday), Completed: \(snapshot.completedHabitsToday)")
            print("   - Last updated: \(snapshot.lastUpdated)")
            
            // Tell WidgetKit to refresh all widgets
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("❌ WidgetDataService: Failed to encode snapshot - \(error)")
        }
    }
    
    // MARK: - Read (Widget)
    
    /// Load widget data snapshot (called from widget)
    /// Returns nil if no data is available (e.g., first launch)
    func loadSnapshot() -> WidgetDataSnapshot? {
        guard let defaults = sharedDefaults else {
            print("⚠️ WidgetDataService: Failed to access App Group UserDefaults")
            return nil
        }
        
        guard let data = defaults.data(forKey: widgetDataKey) else {
            print("⚠️ WidgetDataService: No widget data found (first launch or no data saved yet)")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(WidgetDataSnapshot.self, from: data)
            print("✅ WidgetDataService: Loaded \(snapshot.habits.count) habits from widget data")
            return snapshot
        } catch {
            print("❌ WidgetDataService: Failed to decode snapshot - \(error)")
            print("   Error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Utility Methods
    
    /// Clear all widget data (useful for testing or reset)
    func clearData() {
        guard let defaults = sharedDefaults else { return }
        defaults.removeObject(forKey: widgetDataKey)
        WidgetCenter.shared.reloadAllTimelines()
        print("🗑️ WidgetDataService: Cleared widget data")
    }
    
    /// Check if App Group access is available
    var isAppGroupAvailable: Bool {
        sharedDefaults != nil
    }
}
