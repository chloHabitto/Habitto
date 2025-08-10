import Foundation
import UserNotifications
import SwiftUI

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
        
        // Create trigger that repeats daily
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
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
        // This would need to be updated based on how reminders are stored
        return []
    }
    
    // Update notifications for a habit when reminders change
    func updateNotifications(for habit: Habit, reminders: [ReminderItem]) {
        // First, remove all existing notifications for this habit
        removeAllNotifications(for: habit)
        
        // Then schedule new notifications for active reminders
        for reminder in reminders where reminder.isActive {
            let notificationId = "\(habit.id.uuidString)_\(reminder.id.uuidString)"
            scheduleHabitReminder(for: habit, reminderTime: reminder.time, reminderId: notificationId)
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
} 