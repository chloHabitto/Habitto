import Foundation
import UserNotifications
import SwiftUI

// MARK: - Friendly Reminder Types
enum FriendlyReminderType {
    case oneHour
    case threeHour
}

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {
        requestNotificationPermission()
    }
    
    // Request notification permission
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Notification permission granted")
                } else {
                    print("❌ Notification permission denied")
                }
            }
        }
    }
    
    // Schedule a notification for a habit reminder
    func scheduleHabitReminder(for habit: Habit, reminderTime: Date, reminderId: String) {
        let content = UNMutableNotificationContent()
        content.title = "Habit Reminder"
        content.body = "Time to complete: \(habit.name)"
        content.sound = .default
        content.badge = 1
        
        // Create date components for the reminder time
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        
        // Create trigger that does NOT repeat - one-time notification
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: reminderId,
            content: content,
            trigger: trigger
        )
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error)")
            } else {
                print("✅ Notification scheduled for habit: \(habit.name) at \(reminderTime)")
            }
        }
    }
    
    // Remove a specific notification
    func removeNotification(withId id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        print("🗑️ Removed notification with ID: \(id)")
    }
    
    // Remove all notifications for a habit
    func removeAllNotifications(for habit: Habit) {
        let habitNotificationIds = getNotificationIds(for: habit)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: habitNotificationIds)
        print("🗑️ Removed all notifications for habit: \(habit.name)")
    }
    
    // Get notification IDs for a habit
    private func getNotificationIds(for habit: Habit) -> [String] {
        // Generate IDs based on habit ID and reminder times
        var notificationIds: [String] = []
        
        // Generate IDs for all possible reminders (both active and inactive)
        // This ensures we can remove notifications even if reminders were deactivated
        for reminder in habit.reminders {
            let notificationId = "\(habit.id.uuidString)_\(reminder.id.uuidString)"
            notificationIds.append(notificationId)
        }
        
        return notificationIds
    }
    
    // Update notifications for a habit when reminders change
    func updateNotifications(for habit: Habit, reminders: [ReminderItem]) {
        // First, remove all existing notifications for this habit
        removeAllNotifications(for: habit)
        
        // Schedule notifications for the next 7 days for this specific habit
        let calendar = Calendar.current
        let today = Date()
        
        for dayOffset in 0..<7 {
            if let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                // Only schedule if habit should be shown on this date
                if shouldShowHabitOnDate(habit, date: targetDate) {
                    for reminder in reminders where reminder.isActive {
                        let notificationId = "\(habit.id.uuidString)_\(reminder.id.uuidString)_\(DateUtils.dateKey(for: targetDate))"
                        
                        // Create content
                        let content = UNMutableNotificationContent()
                        content.title = "Habit Reminder"
                        content.body = "Time to complete: \(habit.name)"
                        content.sound = .default
                        content.badge = 1
                        
                        // Create date components for the specific date and reminder time
                        let reminderComponents = calendar.dateComponents([.hour, .minute], from: reminder.time)
                        let dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
                        
                        // Combine date and time components
                        var combinedComponents = DateComponents()
                        combinedComponents.year = dateComponents.year
                        combinedComponents.month = dateComponents.month
                        combinedComponents.day = dateComponents.day
                        combinedComponents.hour = reminderComponents.hour
                        combinedComponents.minute = reminderComponents.minute
                        
                        // Create trigger for specific date
                        let trigger = UNCalendarNotificationTrigger(dateMatching: combinedComponents, repeats: false)
                        
                        // Create request
                        let request = UNNotificationRequest(
                            identifier: notificationId,
                            content: content,
                            trigger: trigger
                        )
                        
                        // Schedule the notification
                        UNUserNotificationCenter.current().add(request) { error in
                            if let error = error {
                                print("❌ Error scheduling notification for \(habit.name) on \(targetDate): \(error)")
                            } else {
                                print("✅ NotificationManager: Scheduled notification for habit '\(habit.name)' on \(targetDate) at \(reminder.time)")
                            }
                        }
                    }
                } else {
                    print("⚠️ NotificationManager: Habit '\(habit.name)' not scheduled for \(targetDate)")
                }
            }
        }
        
        // Note: Friendly reminders are handled by the main scheduling system
        // and will be updated when the entire notification system is refreshed
    }
    
    // Check if habit should be shown on a specific date
    private func shouldShowHabitOnDate(_ habit: Habit, date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let dateKey = calendar.startOfDay(for: date)
        
        // Check if the date is before the habit start date
        if dateKey < calendar.startOfDay(for: habit.startDate) {
            print("🔍 NOTIFICATION DEBUG - Habit '\(habit.name)' not scheduled on \(dateKey): Date before start date")
            return false
        }
        
        // Check if the date is after the habit end date (if set)
        if let endDate = habit.endDate, dateKey > calendar.startOfDay(for: endDate) {
            print("🔍 NOTIFICATION DEBUG - Habit '\(habit.name)' not scheduled on \(dateKey): Date after end date")
            return false
        }
        
        // Check if the habit is already completed for this date
        if habit.isCompleted(for: date) {
            print("🔍 NOTIFICATION DEBUG - Habit '\(habit.name)' not scheduled on \(dateKey): Already completed for this date")
            return false
        }
        
        // Check if the habit is scheduled for this weekday
        let isScheduledForWeekday = isHabitScheduledForWeekday(habit, weekday: weekday)
        
        print("🔍 NOTIFICATION DEBUG - Habit '\(habit.name)' | Date: \(dateKey) | Weekday: \(weekday) | Schedule: '\(habit.schedule)' | Scheduled for weekday: \(isScheduledForWeekday)")
        
        if !isScheduledForWeekday {
            print("🔍 NOTIFICATION DEBUG - Habit '\(habit.name)' not scheduled on \(dateKey): Not scheduled for weekday \(weekday)")
        }
        
        return isScheduledForWeekday
    }
    
    // Helper method to check if habit is scheduled for a specific weekday
    private func isHabitScheduledForWeekday(_ habit: Habit, weekday: Int) -> Bool {
        switch habit.schedule.lowercased() {
        case "daily", "everyday":
            return true
        case "weekdays":
            return weekday >= 2 && weekday <= 6 // Monday = 2, Friday = 6
        case "weekends":
            return weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
        case "monday", "mon":
            return weekday == 2
        case "tuesday", "tue":
            return weekday == 3
        case "wednesday", "wed":
            return weekday == 4
        case "thursday", "thu":
            return weekday == 5
        case "friday", "fri":
            return weekday == 6
        case "saturday", "sat":
            return weekday == 7
        case "sunday", "sun":
            return weekday == 1
        default:
            // For custom schedules, assume it's scheduled
            return true
        }
    }
    
    // Check notification permission status
    func checkNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
    
    // MARK: - Global Notification Management
    
    // Remove all pending notifications
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🗑️ NotificationManager: Removed all pending notifications")
    }
    
    // Remove all delivered notifications
    func removeAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("🗑️ NotificationManager: Removed all delivered notifications")
    }
    
    // Clear all notifications (both pending and delivered)
    func clearAllNotifications() {
        removeAllPendingNotifications()
        removeAllDeliveredNotifications()
        print("🗑️ NotificationManager: Cleared all notifications")
    }
    
    // Debug: List all pending notifications
    func debugPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("🔍 NOTIFICATION DEBUG - Pending notifications count: \(requests.count)")
            for (index, request) in requests.enumerated() {
                print("  \(index + 1). ID: \(request.identifier)")
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    print("     Trigger: \(trigger.dateComponents)")
                    print("     Repeats: \(trigger.repeats)")
                }
            }
        }
    }
    
    // Manual notification rescheduling for testing/debugging
    func manualRescheduleNotifications(for habits: [Habit]) {
        print("🔄 NotificationManager: Manual notification rescheduling triggered")
        rescheduleAllNotifications(for: habits)
        
        // Debug the results
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.debugPendingNotifications()
        }
    }
    
    // Debug: Check if a specific habit should receive notifications on a given date
    func debugHabitNotificationStatus(_ habit: Habit, for date: Date) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let dateKey = calendar.startOfDay(for: date)
        
        print("🔍 NOTIFICATION DEBUG - Habit: '\(habit.name)'")
        print("  Date: \(dateKey)")
        print("  Weekday: \(weekday)")
        print("  Schedule: '\(habit.schedule)'")
        print("  Start Date: \(habit.startDate)")
        print("  End Date: \(habit.endDate?.description ?? "None")")
        print("  Should Show: \(shouldShowHabitOnDate(habit, date: date))")
        print("  Active Reminders: \(habit.reminders.filter { $0.isActive }.count)")
        
        for (index, reminder) in habit.reminders.enumerated() {
            print("    Reminder \(index + 1): \(reminder.time) - Active: \(reminder.isActive)")
        }
    }
    
    // Reschedule all notifications for all habits
    func rescheduleAllNotifications(for habits: [Habit]) {
        print("🔄 NotificationManager: Rescheduling all notifications for \(habits.count) habits")
        
        // First, remove all existing notifications
        removeAllPendingNotifications()
        
        // Schedule notifications for the next 7 days to ensure users get reminders
        let calendar = Calendar.current
        let today = Date()
        
        for dayOffset in 0..<7 {
            if let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                scheduleNotificationsForDate(targetDate, habits: habits)
            }
        }
        
        print("✅ NotificationManager: Completed rescheduling all notifications for next 7 days")
    }
    
    // MARK: - Friendly Reminder System
    
    // Get incomplete scheduled habits for a specific date
    func getIncompleteScheduledHabits(for date: Date, habits: [Habit]) -> [Habit] {
        return habits.filter { habit in
            // Check if habit should be shown on this date
            guard shouldShowHabitOnDate(habit, date: date) else { return false }
            
            // Check if habit is not completed for this date
            return !habit.isCompleted(for: date)
        }
    }
    
    // Schedule friendly reminder notifications for incomplete habits
    func scheduleFriendlyReminders(for date: Date, habits: [Habit]) {
        let incompleteHabits = getIncompleteScheduledHabits(for: date, habits: habits)
        
        guard !incompleteHabits.isEmpty else {
            print("✅ NotificationManager: All habits completed for \(date), no friendly reminders needed")
            return
        }
        
        // Schedule 1-hour reminder
        scheduleFriendlyReminder(
            for: incompleteHabits,
            date: date,
            hoursBefore: 1,
            reminderType: .oneHour
        )
        
        // Schedule 3-hour reminder
        scheduleFriendlyReminder(
            for: incompleteHabits,
            date: date,
            hoursBefore: 3,
            reminderType: .threeHour
        )
    }
    
    // Schedule a specific friendly reminder
    private func scheduleFriendlyReminder(
        for habits: [Habit],
        date: Date,
        hoursBefore: Int,
        reminderType: FriendlyReminderType
    ) {
        let calendar = Calendar.current
        let currentTime = Date()
        let targetTime = calendar.date(byAdding: .hour, value: -hoursBefore, to: calendar.startOfDay(for: date).addingTimeInterval(24 * 60 * 60)) ?? currentTime
        
        // Only schedule if the reminder time is in the future
        guard targetTime > currentTime else {
            print("⏰ NotificationManager: Reminder time for \(hoursBefore)h before has passed, skipping")
            return
        }
        
        let notificationId = "friendly_reminder_\(hoursBefore)h_\(DateUtils.dateKey(for: date))"
        
        // Create friendly content
        let content = UNMutableNotificationContent()
        content.title = getFriendlyReminderTitle(for: habits, reminderType: reminderType)
        content.body = getFriendlyReminderMessage(for: habits, reminderType: reminderType)
        content.sound = .default
        content.badge = 1
        
        // Create date components for the reminder time
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: targetTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling friendly reminder: \(error)")
            } else {
                print("✅ Friendly reminder scheduled for \(hoursBefore)h before \(date) - \(habits.count) incomplete habits")
            }
        }
    }
    
    // Get friendly reminder title based on habits and reminder type
    private func getFriendlyReminderTitle(for habits: [Habit], reminderType: FriendlyReminderType) -> String {
        let count = habits.count
        
        switch reminderType {
        case .oneHour:
            if count == 1 {
                return "🌅 Almost there!"
            } else {
                return "🌅 You're doing great!"
            }
        case .threeHour:
            if count == 1 {
                return "💪 Keep going!"
            } else {
                return "💪 You've got this!"
            }
        }
    }
    
    // Get friendly reminder message based on habits and reminder type
    private func getFriendlyReminderMessage(for habits: [Habit], reminderType: FriendlyReminderType) -> String {
        let count = habits.count
        
        if count == 1 {
            let habit = habits[0]
            switch reminderType {
            case .oneHour:
                return "Just one more hour to complete '\(habit.name)'. You're so close to success! 🎯"
            case .threeHour:
                return "You still have time to complete '\(habit.name)'. Every step counts! ✨"
            }
        } else {
            let habitNames = habits.prefix(2).map { $0.name }.joined(separator: " and ")
            let remainingText = count > 2 ? " and \(count - 2) more" : ""
            
            switch reminderType {
            case .oneHour:
                return "Almost there! Complete \(habitNames)\(remainingText) to finish strong today! 🚀"
            case .threeHour:
                return "You still have time for \(habitNames)\(remainingText). Every habit completed is progress! 🌟"
            }
        }
    }
    
    // Schedule notifications for a specific date (for daily rescheduling)
    func scheduleNotificationsForDate(_ date: Date, habits: [Habit]) {
        print("🔄 NotificationManager: Scheduling notifications for date: \(date)")
        
        for habit in habits {
            // Only schedule if habit should be shown on this date
            if shouldShowHabitOnDate(habit, date: date) {
                let activeReminders = habit.reminders.filter { $0.isActive }
                
                for reminder in activeReminders {
                    let notificationId = "\(habit.id.uuidString)_\(reminder.id.uuidString)_\(DateUtils.dateKey(for: date))"
                    
                    // Create content
                    let content = UNMutableNotificationContent()
                    content.title = "Habit Reminder"
                    content.body = "Time to complete: \(habit.name)"
                    content.sound = .default
                    content.badge = 1
                    
                    // Create date components for the specific date and reminder time
                    let calendar = Calendar.current
                    let reminderComponents = calendar.dateComponents([.hour, .minute], from: reminder.time)
                    let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
                    
                    // Combine date and time components
                    var combinedComponents = DateComponents()
                    combinedComponents.year = dateComponents.year
                    combinedComponents.month = dateComponents.month
                    combinedComponents.day = dateComponents.day
                    combinedComponents.hour = reminderComponents.hour
                    combinedComponents.minute = reminderComponents.minute
                    
                    // Create trigger for specific date
                    let trigger = UNCalendarNotificationTrigger(dateMatching: combinedComponents, repeats: false)
                    
                    // Create request
                    let request = UNNotificationRequest(
                        identifier: notificationId,
                        content: content,
                        trigger: trigger
                    )
                    
                    // Schedule the notification
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            print("❌ Error scheduling notification for \(habit.name) on \(date): \(error)")
                        } else {
                            print("✅ Notification scheduled for habit '\(habit.name)' on \(date) at \(reminder.time)")
                        }
                    }
                }
            } else {
                print("⚠️ NotificationManager: Habit '\(habit.name)' not scheduled for \(date)")
            }
        }
        
        // Schedule friendly reminders for incomplete habits
        scheduleFriendlyReminders(for: date, habits: habits)
    }
} 