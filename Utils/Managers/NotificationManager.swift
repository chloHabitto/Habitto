import Foundation
import UserNotifications
import SwiftUI

// Suppress async warning for UNUserNotificationCenter.add - using callback-based approach for consistency
// swiftlint:disable:next async_warning

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
        // Check if vacation mode is active - don't schedule notifications during vacation
        let vacationManager = VacationManager.shared
        if vacationManager.isVacationDay(reminderTime) {
            print("🔇 NotificationManager: Skipping notification for \(habit.name) - vacation day")
            return
        }
        
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
        // Using callback-based approach for consistency - async alternative available but requires refactoring
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
        // Check if vacation mode is active - don't schedule friendly reminders during vacation
        let vacationManager = VacationManager.shared
        if vacationManager.isVacationDay(date) {
            print("🔇 NotificationManager: Skipping friendly reminders for \(date) - vacation day")
            return
        }
        
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
        
        // Check if vacation mode is active - don't schedule notifications during vacation
        let vacationManager = VacationManager.shared
        if vacationManager.isVacationDay(date) {
            print("🔇 NotificationManager: Skipping all notifications for \(date) - vacation day")
            return
        }
        
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
    
    // MARK: - Daily Reminders System
    
    /// Schedule daily plan reminders based on user settings
    @MainActor
    func scheduleDailyPlanReminders() {
        print("📅 NotificationManager: Scheduling daily plan reminders...")
        
        // Check if plan reminders are enabled
        let planReminderEnabled = UserDefaults.standard.bool(forKey: "planReminderEnabled")
        guard planReminderEnabled else {
            print("ℹ️ NotificationManager: Plan reminders are disabled")
            return
        }
        
        // Get the reminder time from UserDefaults
        guard let planReminderTime = UserDefaults.standard.object(forKey: "planReminderTime") as? Date else {
            print("❌ NotificationManager: No plan reminder time set")
            return
        }
        
        // Get habits from HabitRepository
        let habits = HabitRepository.shared.habits
        print("📅 NotificationManager: Found \(habits.count) habits for plan reminders")
        
        // Schedule plan reminders for the next 7 days
        let calendar = Calendar.current
        let today = Date()
        
        for dayOffset in 0..<7 {
            if let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                schedulePlanReminderForDate(targetDate, reminderTime: planReminderTime, habits: habits)
            }
        }
        
        print("✅ NotificationManager: Daily plan reminders scheduled for next 7 days")
    }
    
    /// Schedule daily completion reminders based on user settings
    @MainActor
    func scheduleDailyCompletionReminders() {
        print("📅 NotificationManager: Scheduling daily completion reminders...")
        
        // Check if completion reminders are enabled
        let completionReminderEnabled = UserDefaults.standard.bool(forKey: "completionReminderEnabled")
        guard completionReminderEnabled else {
            print("ℹ️ NotificationManager: Completion reminders are disabled")
            return
        }
        
        // Get the reminder time from UserDefaults
        guard let completionReminderTime = UserDefaults.standard.object(forKey: "completionReminderTime") as? Date else {
            print("❌ NotificationManager: No completion reminder time set")
            return
        }
        
        // Setup notification categories for snooze functionality
        setupNotificationCategories()
        
        // Get habits from HabitRepository
        let habits = HabitRepository.shared.habits
        print("📅 NotificationManager: Found \(habits.count) habits for completion reminders")
        
        // Schedule completion reminders for the next 7 days
        let calendar = Calendar.current
        let today = Date()
        
        for dayOffset in 0..<7 {
            if let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                scheduleCompletionReminderForDate(targetDate, reminderTime: completionReminderTime, habits: habits)
            }
        }
        
        print("✅ NotificationManager: Daily completion reminders scheduled for next 7 days")
    }
    
    /// Schedule a plan reminder for a specific date
    private func schedulePlanReminderForDate(_ date: Date, reminderTime: Date, habits: [Habit]) {
        // Check if vacation mode is active - don't schedule notifications during vacation
        let vacationManager = VacationManager.shared
        if vacationManager.isVacationDay(date) {
            print("🔇 NotificationManager: Skipping plan reminder for \(date) - vacation day")
            return
        }
        
        // Count habits scheduled for this date
        let scheduledHabits = habits.filter { habit in
            StreakDataCalculator.shouldShowHabitOnDate(habit, date: date)
        }
        
        let habitCount = scheduledHabits.count
        
        // Don't schedule reminder if no habits are scheduled for this date
        guard habitCount > 0 else {
            print("ℹ️ NotificationManager: No habits scheduled for \(date), skipping plan reminder")
            return
        }
        
        let calendar = Calendar.current
        let dateKey = DateUtils.dateKey(for: date)
        let notificationId = "daily_plan_reminder_\(dateKey)"
        
        // Create dynamic notification content based on habit count
        let content = UNMutableNotificationContent()
        content.title = generatePlanReminderTitle(habitCount: habitCount)
        content.body = generatePlanReminderMessage(habitCount: habitCount)
        
        content.sound = .default
        content.badge = 1
        
        // Create date components for the reminder time on the specific date
        let reminderComponents = calendar.dateComponents([.hour, .minute], from: reminderTime)
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
                print("❌ Error scheduling plan reminder for \(date): \(error)")
            } else {
                print("✅ Plan reminder scheduled for \(date) at \(reminderTime) - \(habitCount) habits")
            }
        }
    }
    
    /// Schedule a completion reminder for a specific date
    private func scheduleCompletionReminderForDate(_ date: Date, reminderTime: Date, habits: [Habit]) {
        // Check if vacation mode is active - don't schedule notifications during vacation
        let vacationManager = VacationManager.shared
        if vacationManager.isVacationDay(date) {
            print("🔇 NotificationManager: Skipping completion reminder for \(date) - vacation day")
            return
        }
        
        // Get incomplete habits for this date
        let incompleteHabits = getIncompleteScheduledHabits(for: date, habits: habits)
        let incompleteCount = incompleteHabits.count
        
        // Don't schedule reminder if no incomplete habits for this date
        guard incompleteCount > 0 else {
            print("ℹ️ NotificationManager: No incomplete habits for \(date), skipping completion reminder")
            return
        }
        
        let calendar = Calendar.current
        let dateKey = DateUtils.dateKey(for: date)
        let notificationId = "daily_completion_reminder_\(dateKey)"
        
        // Create dynamic notification content based on incomplete habits
        let content = UNMutableNotificationContent()
        content.title = generateCompletionReminderTitle(incompleteCount: incompleteCount)
        content.body = generateCompletionReminderMessage(incompleteCount: incompleteCount)
        
        content.sound = .default
        content.badge = 1
        
        // Add snooze actions if snooze is enabled
        let snoozeDuration = getSnoozeDuration()
        if snoozeDuration != .none {
            content.categoryIdentifier = "COMPLETION_REMINDER_CATEGORY"
        }
        
        // Create date components for the reminder time on the specific date
        let reminderComponents = calendar.dateComponents([.hour, .minute], from: reminderTime)
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
                print("❌ Error scheduling completion reminder for \(date): \(error)")
            } else {
                print("✅ Completion reminder scheduled for \(date) at \(reminderTime) - \(incompleteCount) incomplete habits")
            }
        }
    }
    
    /// Remove all daily plan reminders
    func removeDailyPlanReminders() {
        print("🗑️ NotificationManager: Removing all daily plan reminders...")
        
        // Get all pending notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let planReminderIds = requests.compactMap { request in
                request.identifier.hasPrefix("daily_plan_reminder_") ? request.identifier : nil
            }
            
            if !planReminderIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: planReminderIds)
                print("✅ NotificationManager: Removed \(planReminderIds.count) daily plan reminders")
            } else {
                print("ℹ️ NotificationManager: No daily plan reminders to remove")
            }
        }
    }
    
    /// Remove all daily completion reminders
    func removeDailyCompletionReminders() {
        print("🗑️ NotificationManager: Removing all daily completion reminders...")
        
        // Get all pending notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let completionReminderIds = requests.compactMap { request in
                request.identifier.hasPrefix("daily_completion_reminder_") ? request.identifier : nil
            }
            
            if !completionReminderIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: completionReminderIds)
                print("✅ NotificationManager: Removed \(completionReminderIds.count) daily completion reminders")
            } else {
                print("ℹ️ NotificationManager: No daily completion reminders to remove")
            }
        }
    }
    
    /// Remove all daily reminders (both plan and completion, including snoozed)
    func removeAllDailyReminders() {
        removeDailyPlanReminders()
        removeDailyCompletionReminders()
        removeSnoozedCompletionReminders()
    }
    
    /// Reschedule all daily reminders (useful when settings change)
    @MainActor
    func rescheduleDailyReminders() {
        print("🔄 NotificationManager: Rescheduling all daily reminders...")
        
        // Remove existing daily reminders
        removeAllDailyReminders()
        
        // Schedule new ones based on current settings
        scheduleDailyPlanReminders()
        scheduleDailyCompletionReminders()
        
        print("✅ NotificationManager: Daily reminders rescheduled")
    }
    
    // MARK: - Snooze Functionality
    
    /// SnoozeDuration enum to match the one in DailyRemindersView
    enum SnoozeDuration: String, CaseIterable {
        case none = "None"
        case tenMinutes = "10 min"
        case fifteenMinutes = "15 min"
        case thirtyMinutes = "30 min"
        
        var minutes: Int {
            switch self {
            case .none: return 0
            case .tenMinutes: return 10
            case .fifteenMinutes: return 15
            case .thirtyMinutes: return 30
            }
        }
    }
    
    /// Get snooze duration from UserDefaults
    private func getSnoozeDuration() -> SnoozeDuration {
        if let snoozeRawValue = UserDefaults.standard.string(forKey: "snoozeDuration"),
           let snooze = SnoozeDuration(rawValue: snoozeRawValue) {
            return snooze
        }
        return .none
    }
    
    /// Setup notification categories for snooze functionality
    private func setupNotificationCategories() {
        let snoozeDuration = getSnoozeDuration()
        
        // Only create snooze category if snooze is enabled
        guard snoozeDuration != .none else {
            print("ℹ️ NotificationManager: Snooze disabled, skipping category setup")
            return
        }
        
        var actions: [UNNotificationAction] = []
        
        // Add snooze action based on selected duration
        switch snoozeDuration {
        case .tenMinutes:
            actions.append(UNNotificationAction(
                identifier: "SNOOZE_10_MIN",
                title: "Snooze 10 min",
                options: []
            ))
        case .fifteenMinutes:
            actions.append(UNNotificationAction(
                identifier: "SNOOZE_15_MIN",
                title: "Snooze 15 min",
                options: []
            ))
        case .thirtyMinutes:
            actions.append(UNNotificationAction(
                identifier: "SNOOZE_30_MIN",
                title: "Snooze 30 min",
                options: []
            ))
        case .none:
            break
        }
        
        // Add dismiss action
        actions.append(UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        ))
        
        // Create category
        let category = UNNotificationCategory(
            identifier: "COMPLETION_REMINDER_CATEGORY",
            actions: actions,
            intentIdentifiers: [],
            options: []
        )
        
        // Register category
        UNUserNotificationCenter.current().setNotificationCategories([category])
        print("✅ NotificationManager: Notification categories set up with snooze duration: \(snoozeDuration.rawValue)")
    }
    
    /// Handle snooze action for completion reminders
    func handleSnoozeAction(for notificationId: String, snoozeMinutes: Int) {
        print("⏰ NotificationManager: Handling snooze action for \(notificationId) - \(snoozeMinutes) minutes")
        
        // Extract date from notification ID
        let dateKey = notificationId.replacingOccurrences(of: "daily_completion_reminder_", with: "")
        
        // Parse date from dateKey (assuming format like "2024-01-15")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: dateKey) else {
            print("❌ NotificationManager: Could not parse date from notification ID: \(notificationId)")
            return
        }
        
        // Calculate snooze time
        let calendar = Calendar.current
        let snoozeTime = calendar.date(byAdding: .minute, value: snoozeMinutes, to: Date()) ?? Date()
        
        // Create snooze notification
        let snoozeNotificationId = "daily_completion_reminder_snooze_\(dateKey)_\(Int(snoozeTime.timeIntervalSince1970))"
        
        // Get habits from HabitRepository (need to do this on MainActor)
        Task { @MainActor in
            let habits = HabitRepository.shared.habits
            let incompleteHabits = getIncompleteScheduledHabits(for: date, habits: habits)
            let incompleteCount = incompleteHabits.count
            
            guard incompleteCount > 0 else {
                print("ℹ️ NotificationManager: No incomplete habits for snooze, skipping")
                return
            }
            
            // Create snooze notification content
            let content = UNMutableNotificationContent()
            content.title = generateSnoozeReminderTitle(incompleteCount: incompleteCount)
            content.body = generateSnoozeReminderMessage(incompleteCount: incompleteCount)
            
            content.sound = .default
            content.badge = 1
            
            // Add snooze actions if snooze is still enabled
            let snoozeDuration = getSnoozeDuration()
            if snoozeDuration != .none {
                content.categoryIdentifier = "COMPLETION_REMINDER_CATEGORY"
            }
            
            // Create trigger for snooze time
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(snoozeMinutes * 60), repeats: false)
            
            // Create request
            let request = UNNotificationRequest(
                identifier: snoozeNotificationId,
                content: content,
                trigger: trigger
            )
            
            // Schedule the snooze notification
            do {
                try await UNUserNotificationCenter.current().add(request)
                print("✅ Snooze notification scheduled for \(snoozeMinutes) minutes from now")
            } catch {
                print("❌ Error scheduling snooze notification: \(error)")
            }
        }
    }
    
    /// Remove snoozed completion reminders
    func removeSnoozedCompletionReminders() {
        print("🗑️ NotificationManager: Removing snoozed completion reminders...")
        
        // Get all pending notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let snoozeReminderIds = requests.compactMap { request in
                request.identifier.hasPrefix("daily_completion_reminder_snooze_") ? request.identifier : nil
            }
            
            if !snoozeReminderIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: snoozeReminderIds)
                print("✅ NotificationManager: Removed \(snoozeReminderIds.count) snoozed completion reminders")
            } else {
                print("ℹ️ NotificationManager: No snoozed completion reminders to remove")
            }
        }
    }
    
    // MARK: - Notification Content Generation
    
    /// Generate dynamic titles for plan reminders
    private func generatePlanReminderTitle(habitCount: Int) -> String {
        let titles = [
            "🌅 Good Morning!",
            "📋 Daily Plan",
            "🎯 Let's Get Started",
            "✨ Today's Goals",
            "🚀 Ready to Begin?",
            "💪 Time to Shine"
        ]
        
        // Use habit count to determine which title to use for variety
        let index = habitCount % titles.count
        return titles[index]
    }
    
    /// Generate personalized messages for plan reminders
    private func generatePlanReminderMessage(habitCount: Int) -> String {
        switch habitCount {
        case 1:
            let messages = [
                "You have 1 habit planned for today. Let's make it happen! 💪",
                "One habit today = one step closer to your goals! 🌟",
                "Your single habit is waiting for you. Time to shine! ✨",
                "One focused habit can change everything. You've got this! 🎯"
            ]
            return messages[habitCount % messages.count]
            
        case 2...3:
            let messages = [
                "You have \(habitCount) habits planned for today. Ready to tackle them? 🎯",
                "\(habitCount) habits = \(habitCount) opportunities to grow! 🌱",
                "Your \(habitCount) habits are calling. Let's answer! 📞",
                "Time to conquer your \(habitCount) daily habits! 💪"
            ]
            return messages[habitCount % messages.count]
            
        case 4...6:
            let messages = [
                "You have \(habitCount) habits planned for today. That's ambitious! 🚀",
                "\(habitCount) habits ahead - you're building something amazing! 🏗️",
                "Ready to tackle your \(habitCount) habits? You're unstoppable! ⚡",
                "\(habitCount) habits today = incredible progress! Keep going! 🌟"
            ]
            return messages[habitCount % messages.count]
            
        default:
            let messages = [
                "You have \(habitCount) habits planned for today. You're a habit champion! 🏆",
                "\(habitCount) habits? You're absolutely crushing it! 🔥",
                "Wow! \(habitCount) habits today. You're building an empire! 👑",
                "\(habitCount) habits planned - you're unstoppable! 💎"
            ]
            return messages[habitCount % messages.count]
        }
    }
    
    /// Generate dynamic titles for completion reminders
    private func generateCompletionReminderTitle(incompleteCount: Int) -> String {
        let titles = [
            "📝 Daily Check-in",
            "⏰ Time to Wrap Up",
            "🎯 Almost There!",
            "✨ Finish Strong",
            "💪 Keep Going!",
            "🌟 You're Close!"
        ]
        
        // Use incomplete count to determine which title to use for variety
        let index = incompleteCount % titles.count
        return titles[index]
    }
    
    /// Generate personalized messages for completion reminders
    private func generateCompletionReminderMessage(incompleteCount: Int) -> String {
        switch incompleteCount {
        case 1:
            let messages = [
                "You have 1 habit left to complete today. Almost there! 🌟",
                "Just 1 more habit to go! You're so close to victory! 🏆",
                "One final push - your last habit is waiting! 💪",
                "You're 99% there! Complete that last habit! ✨"
            ]
            return messages[incompleteCount % messages.count]
            
        case 2...3:
            let messages = [
                "You have \(incompleteCount) habits left to complete today. Keep going! 💪",
                "Just \(incompleteCount) more habits to finish strong! 🎯",
                "You're in the home stretch! \(incompleteCount) habits to go! 🏁",
                "Almost there! \(incompleteCount) habits left to complete your day! ⚡"
            ]
            return messages[incompleteCount % messages.count]
            
        case 4...6:
            let messages = [
                "You have \(incompleteCount) habits left to complete today. Don't give up! 🎯",
                "\(incompleteCount) habits remaining - you've got the power! 💥",
                "Keep pushing forward! \(incompleteCount) habits left to conquer! 🚀",
                "You're making progress! \(incompleteCount) habits to finish strong! 🌟"
            ]
            return messages[incompleteCount % messages.count]
            
        default:
            let messages = [
                "You have \(incompleteCount) habits left to complete today. Every step counts! 🎯",
                "\(incompleteCount) habits remaining - you're building momentum! 🌊",
                "Keep going! \(incompleteCount) habits left to complete your mission! 🎖️",
                "You've got this! \(incompleteCount) habits to finish what you started! ⭐"
            ]
            return messages[incompleteCount % messages.count]
        }
    }
    
    /// Generate dynamic titles for snooze reminders
    private func generateSnoozeReminderTitle(incompleteCount: Int) -> String {
        let titles = [
            "⏰ Reminder (Snoozed)",
            "📝 Check-in Time!",
            "🎯 Back to It!",
            "💪 Ready Again?",
            "✨ Let's Finish!",
            "🌟 One More Try!"
        ]
        
        // Use incomplete count to determine which title to use for variety
        let index = incompleteCount % titles.count
        return titles[index]
    }
    
    /// Generate personalized messages for snooze reminders
    private func generateSnoozeReminderMessage(incompleteCount: Int) -> String {
        switch incompleteCount {
        case 1:
            let messages = [
                "Time's up! You still have 1 habit left to complete today. Let's finish strong! 🌟",
                "Break time over! Your last habit is still waiting. Almost there! 💪",
                "Ready to complete that final habit? You're so close to victory! 🏆",
                "One more push! Your last habit is calling. You've got this! ✨"
            ]
            return messages[incompleteCount % messages.count]
            
        case 2...3:
            let messages = [
                "Break's over! You have \(incompleteCount) habits left to complete today. Keep going! 💪",
                "Time to get back to it! \(incompleteCount) habits are waiting for you! 🎯",
                "Ready to finish strong? \(incompleteCount) habits left to complete your day! ⚡",
                "Let's wrap this up! \(incompleteCount) habits to go and you're done! 🏁"
            ]
            return messages[incompleteCount % messages.count]
            
        case 4...6:
            let messages = [
                "Back to work! You have \(incompleteCount) habits left to complete today. Don't give up! 🎯",
                "Time to push through! \(incompleteCount) habits remaining - you've got this! 💥",
                "Let's finish what we started! \(incompleteCount) habits left to conquer! 🚀",
                "Ready to complete your mission? \(incompleteCount) habits to go! 🌟"
            ]
            return messages[incompleteCount % messages.count]
            
        default:
            let messages = [
                "Time to get back on track! You have \(incompleteCount) habits left to complete today! 🎯",
                "Let's build that momentum! \(incompleteCount) habits remaining - every step counts! 🌊",
                "Ready to finish strong? \(incompleteCount) habits left to complete your day! 🎖️",
                "You've got the power! \(incompleteCount) habits to finish what you started! ⭐"
            ]
            return messages[incompleteCount % messages.count]
        }
    }
} 