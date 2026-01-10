//
//  WidgetUpdateService.swift
//  Habitto
//
//  Service that prepares and pushes data to the widget
//  Main app only - NOT shared with widget extension
//

import Foundation
import WidgetKit
import SwiftUI

/// Service that prepares and pushes data to the widget
/// Call this whenever habits change (create, update, complete, delete)
@MainActor
final class WidgetUpdateService {
    static let shared = WidgetUpdateService()
    
    private init() {}
    
    /// Convert main app habits to widget format and save to App Group
    /// Call this whenever habits change (create, update, complete, delete)
    /// - Parameters:
    ///   - habits: Array of all habits from the main app
    ///   - userProgress: Optional user progress data (for XP and level display)
    func updateWidgetData(habits: [Habit], userProgress: UserProgress? = nil) {
        let today = Calendar.current.startOfDay(for: Date())
        let todayKey = Habit.dateKey(for: today)
        
        // Filter to today's scheduled habits and convert to widget format
        let widgetHabits: [WidgetHabitData] = habits
            .filter { habit in
                // Use HabitSchedulingLogic to determine if habit is scheduled for today
                HabitSchedulingLogic.shouldShowHabitOnDate(habit, date: today, habits: habits)
            }
            .map { habit in
                // Get progress for today
                let progress = habit.getProgress(for: today)
                
                // Get goal amount for today (uses historical goal if applicable)
                let goalAmount = habit.goalAmount(for: today)
                
                // Check if completed today
                let isCompleted = habit.isCompleted(for: today)
                
                // Calculate current streak
                let streak = habit.calculateTrueStreak()
                
                // Get color as hex string
                // CodableColor has a hexString extension defined in FirestoreService.swift
                let colorHex = habit.color.hexString
                
                return WidgetHabitData(
                    id: habit.id,
                    name: habit.name,
                    icon: habit.icon,
                    colorHex: colorHex,
                    isCompletedToday: isCompleted,
                    currentStreak: streak,
                    todayProgress: progress,
                    todayGoal: goalAmount,
                    habitType: habit.habitType.rawValue
                )
            }
        
        // Calculate completion stats
        let completedCount = widgetHabits.filter { $0.isCompletedToday }.count
        let totalCount = widgetHabits.count
        
        // Create snapshot
        let snapshot = WidgetDataSnapshot(
            habits: widgetHabits,
            totalHabitsToday: totalCount,
            completedHabitsToday: completedCount,
            lastUpdated: Date(),
            userDisplayName: nil,  // TODO: Add user display name if available
            currentXP: userProgress?.totalXP ?? 0,
            currentLevel: userProgress?.currentLevel ?? 1
        )
        
        // Save to App Group UserDefaults
        WidgetDataService.shared.saveSnapshot(snapshot)
    }
    
    /// Force widget refresh without updating data
    /// Useful when you want to trigger a reload without changing data
    func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 WidgetUpdateService: Forced widget refresh")
    }
    
    /// Clear widget data (useful for testing or logout)
    func clearWidgetData() {
        WidgetDataService.shared.clearData()
    }
}
