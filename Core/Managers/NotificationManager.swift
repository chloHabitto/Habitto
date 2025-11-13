import Foundation
import SwiftUI
import UserNotifications

// MARK: - FriendlyReminderType

// Suppress async warning for UNUserNotificationCenter.add - using callback-based approach for
// consistency
// swiftlint:disable:next async_warning

enum FriendlyReminderType {
  case oneHour
  case threeHour
}

// MARK: - LogLevel

enum LogLevel: String, CaseIterable {
  case debug = "🔍"
  case info = "ℹ️"
  case warning = "⚠️"
  case error = "❌"
  case success = "✅"
  case notification = "📱"
  case scheduling = "📅"
  case cleanup = "🧹"
  case permission = "🔐"
  case vacation = "🏖️"
  case snooze = "⏰"
  case test = "🧪"
}

// MARK: - LogEntry

struct LogEntry {
  // MARK: Lifecycle

  init(level: LogLevel, category: String, message: String, metadata: [String: Any]? = nil) {
    self.timestamp = Date()
    self.level = level
    self.category = category
    self.message = message
    self.metadata = metadata
  }

  // MARK: Internal

  let timestamp: Date
  let level: LogLevel
  let category: String
  let message: String
  let metadata: [String: Any]?

  var formattedMessage: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    let timeString = formatter.string(from: timestamp)

    var logMessage = "\(level.rawValue) [\(timeString)] \(category): \(message)"

    if let metadata, !metadata.isEmpty {
      let metadataString = metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
      logMessage += " | \(metadataString)"
    }

    return logMessage
  }
}

// MARK: - NotificationLogger

class NotificationLogger {
  // MARK: Lifecycle

  private init() { }

  // MARK: Internal

  static let shared = NotificationLogger()

  func log(_ level: LogLevel, category: String, message: String, metadata: [String: Any]? = nil) {
    let entry = LogEntry(level: level, category: category, message: message, metadata: metadata)

    queue.async {
      self.logEntries.append(entry)

      // Trim to max entries
      if self.logEntries.count > self.maxLogEntries {
        self.logEntries.removeFirst(self.logEntries.count - self.maxLogEntries)
      }

      // Print to console
      print(entry.formattedMessage)
    }
  }

  func getRecentLogs(count: Int = 50) -> [LogEntry] {
    queue.sync {
      Array(logEntries.suffix(count))
    }
  }

  func getLogsByLevel(_ level: LogLevel) -> [LogEntry] {
    queue.sync {
      logEntries.filter { $0.level == level }
    }
  }

  func getLogsByCategory(_ category: String) -> [LogEntry] {
    queue.sync {
      logEntries.filter { $0.category == category }
    }
  }

  func clearLogs() {
    queue.async {
      self.logEntries.removeAll()
    }
  }

  func exportLogs() -> String {
    queue.sync {
      logEntries.map { $0.formattedMessage }.joined(separator: "\n")
    }
  }

  // MARK: Private

  private var logEntries: [LogEntry] = []
  private let maxLogEntries = 1000 // Keep last 1000 entries
  private let queue = DispatchQueue(label: "notification.logger", qos: .utility)
}

// MARK: - NotificationPermissionTestResult

struct NotificationPermissionTestResult {
  let authorizationStatus: UNAuthorizationStatus
  let alertSetting: UNNotificationSetting
  let badgeSetting: UNNotificationSetting
  let soundSetting: UNNotificationSetting
  let notificationCenterSetting: UNNotificationSetting
  let lockScreenSetting: UNNotificationSetting
  let carPlaySetting: UNNotificationSetting
  let criticalAlertSetting: UNNotificationSetting
  let announcementSetting: UNNotificationSetting
  let isAuthorized: Bool
  let canScheduleNotifications: Bool
}

// MARK: - NotificationPermissionHistory

struct NotificationPermissionHistory {
  let wasGranted: Bool
  let grantedDate: Date?
  let deniedDate: Date?
  let errorMessage: String?
  let errorDate: Date?
}

// MARK: - NotificationValidationResult

struct NotificationValidationResult {
  var isAuthorized = false
  var canSchedule = false
  var canShowAlerts = false
  var canShowBadges = false
  var canPlaySounds = false
  var canShowInNotificationCenter = false
  var canShowOnLockScreen = false
  var canShowInCarPlay = false
  var canShowCriticalAlerts = false
  var canShowAnnouncements = false
  var overallCapability = false
  var statusMessage = ""
  var requiresUserAction = false
  var requiresPermissionRequest = false
}

// MARK: - NotificationManager

class NotificationManager: ObservableObject {
  // MARK: Lifecycle

  private init() {
    logger.log(.info, category: "NotificationManager", message: "Initializing NotificationManager")
    requestNotificationPermission()
  }

  // MARK: Internal

  // MARK: - Snooze Functionality

  /// SnoozeDuration enum to match the one in NotificationsView
  enum SnoozeDuration: String, CaseIterable {
    case none = "None"
    case tenMinutes = "10 min"
    case fifteenMinutes = "15 min"
    case thirtyMinutes = "30 min"

    // MARK: Internal

    var minutes: Int {
      switch self {
      case .none: 0
      case .tenMinutes: 10
      case .fifteenMinutes: 15
      case .thirtyMinutes: 30
      }
    }
  }

  static let shared = NotificationManager()

  // MARK: - Calendar/Locale Injection for Testing and Production

  func injectCalendar(_ calendar: Calendar?, timeZone: TimeZone? = nil, locale: Locale? = nil) {
    injectedCalendar = calendar
    injectedTimeZone = timeZone
    injectedLocale = locale
    logger.log(
      .info,
      category: "NotificationManager",
      message: "Injected calendar/timezone/locale for deterministic behavior")
  }

  /// Set deterministic calendar/locale for production DST handling
  func setDeterministicCalendarForDST() {
    // Use Gregorian calendar with UTC timezone for consistent behavior
    let gregorianCalendar = Calendar(identifier: .gregorian)
    let utcTimeZone = TimeZone(identifier: "UTC") ?? TimeZone.current
    let englishLocale = Locale(identifier: "en_US_POSIX") // POSIX for consistent formatting

    injectCalendar(gregorianCalendar, timeZone: utcTimeZone, locale: englishLocale)
    logger.log(
      .info,
      category: "NotificationManager",
      message: "Set deterministic calendar for DST handling (Gregorian/UTC/en_US_POSIX)")
  }

  /// Get recent logs for debugging
  func getRecentLogs(count: Int = 50) -> [LogEntry] {
    logger.getRecentLogs(count: count)
  }

  /// Get logs by level for debugging
  func getLogsByLevel(_ level: LogLevel) -> [LogEntry] {
    logger.getLogsByLevel(level)
  }

  /// Get logs by category for debugging
  func getLogsByCategory(_ category: String) -> [LogEntry] {
    logger.getLogsByCategory(category)
  }

  /// Export logs for debugging
  func exportLogs() -> String {
    logger.exportLogs()
  }

  /// Clear logs (useful for testing)
  func clearLogs() {
    logger.clearLogs()
  }

  /// Comprehensive debugging and monitoring method
  func performComprehensiveDebugging() {
    logDebug("Starting comprehensive debugging and monitoring")

    // 1. Check notification permissions
    checkNotificationPermissionStatus { status in
      self.logDebug("Notification permission status", metadata: ["status": status.rawValue])
    }

    // 2. Get pending notification count
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      DispatchQueue.main.async {
        self.logDebug("Pending notifications", metadata: ["count": requests.count])

        // Categorize notifications
        let planReminders = requests.filter { $0.identifier.hasPrefix("daily_plan_reminder_") }
        let completionReminders = requests
          .filter { $0.identifier.hasPrefix("daily_completion_reminder_") }
        let snoozeReminders = requests
          .filter { $0.identifier.hasPrefix("daily_completion_reminder_snooze_") }
        let habitReminders = requests.filter { $0.identifier.hasPrefix("habit_reminder_") }
        let friendlyReminders = requests.filter { $0.identifier.hasPrefix("friendly_reminder_") }

        self.logDebug("Notification breakdown", metadata: [
          "planReminders": planReminders.count,
          "completionReminders": completionReminders.count,
          "snoozeReminders": snoozeReminders.count,
          "habitReminders": habitReminders.count,
          "friendlyReminders": friendlyReminders.count
        ])
      }
    }

    // 3. Check UserDefaults settings
    let planReminderEnabled = UserDefaults.standard.bool(forKey: "planReminderEnabled")
    let completionReminderEnabled = UserDefaults.standard.bool(forKey: "completionReminderEnabled")
    let planReminderTime = UserDefaults.standard.object(forKey: "planReminderTime") as? Date
    let completionReminderTime = UserDefaults.standard
      .object(forKey: "completionReminderTime") as? Date
    let snoozeDuration = UserDefaults.standard.string(forKey: "snoozeDuration") ?? "none"

    logDebug("UserDefaults settings", metadata: [
      "planReminderEnabled": planReminderEnabled,
      "completionReminderEnabled": completionReminderEnabled,
      "planReminderTime": planReminderTime?.description ?? "nil",
      "completionReminderTime": completionReminderTime?.description ?? "nil",
      "snoozeDuration": snoozeDuration
    ])

    // 4. Check habit count
    Task { @MainActor in
      let habits = HabitRepository.shared.habits
      self.logDebug("Habit repository status", metadata: ["habitCount": habits.count])
    }

    // 5. Check vacation mode status
    let vacationManager = VacationManager.shared
    let today = Date()
    let isVacationDay = vacationManager.isVacationDay(today)
    logDebug("Vacation mode status", metadata: [
      "today": today.description,
      "isVacationDay": isVacationDay
    ])

    // 6. Check snooze counts
    let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
    let snoozeKeys = allKeys.filter { $0.hasPrefix("snooze_count_") }
    logDebug("Snooze counts", metadata: ["snoozeKeys": snoozeKeys.count])

    // 7. Test notification delivery capability
    testNotificationDelivery { success in
      self.logDebug("Notification delivery test", metadata: ["success": success])
    }

    logDebug("Comprehensive debugging completed")
  }

  /// Generate debugging report
  func generateDebuggingReport() -> String {
    var report = "=== NOTIFICATION MANAGER DEBUG REPORT ===\n\n"

    // Add recent logs
    let recentLogs = getRecentLogs(count: 100)
    report += "=== RECENT LOGS (Last 100) ===\n"
    for log in recentLogs {
      report += "\(log.formattedMessage)\n"
    }

    report += "\n=== ERROR LOGS ===\n"
    let errorLogs = getLogsByLevel(.error)
    for log in errorLogs {
      report += "\(log.formattedMessage)\n"
    }

    report += "\n=== WARNING LOGS ===\n"
    let warningLogs = getLogsByLevel(.warning)
    for log in warningLogs {
      report += "\(log.formattedMessage)\n"
    }

    report += "\n=== SCHEDULING LOGS ===\n"
    let schedulingLogs = getLogsByCategory("NotificationManager")
      .filter { $0.message.contains("scheduling") || $0.message.contains("reminder") }
    for log in schedulingLogs {
      report += "\(log.formattedMessage)\n"
    }

    report += "\n=== REPORT END ===\n"
    return report
  }

  /// Request notification permission
  func requestNotificationPermission() {
    logPermission(
      "Requesting notification permission",
      metadata: ["options": ["alert", "badge", "sound"]])

    UNUserNotificationCenter.current().requestAuthorization(options: [
      .alert,
      .badge,
      .sound
    ]) { granted, error in
      DispatchQueue.main.async {
        if let error {
          self.logError("Notification permission request failed", metadata: [
            "error": error.localizedDescription,
            "errorCode": (error as NSError).code,
            "errorDomain": (error as NSError).domain
          ])
          self.handleNotificationPermissionError(error)
        } else if granted {
          self.logSuccess("Notification permission granted")
          self.handleNotificationPermissionGranted()
        } else {
          self.logWarning("Notification permission denied by user")
          self.handleNotificationPermissionDenied()
        }
      }
    }
  }

  /// Check current notification authorization status
  func checkNotificationPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        completion(settings.authorizationStatus)
      }
    }
  }

  /// Validate notification permissions before scheduling
  func validateNotificationPermissions(completion: @escaping (Bool) -> Void) {
    checkNotificationPermissionStatus { status in
      switch status {
      case .authorized:
        print("✅ NotificationManager: Permissions validated - authorized")
        completion(true)

      case .denied:
        print("❌ NotificationManager: Permissions validated - denied")
        completion(false)

      case .notDetermined:
        print("⚠️ NotificationManager: Permissions not determined - requesting permission")
        self.requestNotificationPermission()
        // Check again after requesting
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
          self.checkNotificationPermissionStatus { newStatus in
            completion(newStatus == .authorized)
          }
        }

      case .provisional:
        print("✅ NotificationManager: Permissions validated - provisional")
        completion(true)

      case .ephemeral:
        print("✅ NotificationManager: Permissions validated - ephemeral")
        completion(true)

      @unknown default:
        print("⚠️ NotificationManager: Unknown permission status: \(status.rawValue)")
        completion(false)
      }
    }
  }

  /// Test notification permissions and provide comprehensive status report
  func testNotificationPermissions(completion: @escaping (NotificationPermissionTestResult)
    -> Void)
  {
    print("🧪 NotificationManager: Testing notification permissions...")

    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        let result = NotificationPermissionTestResult(
          authorizationStatus: settings.authorizationStatus,
          alertSetting: settings.alertSetting,
          badgeSetting: settings.badgeSetting,
          soundSetting: settings.soundSetting,
          notificationCenterSetting: settings.notificationCenterSetting,
          lockScreenSetting: settings.lockScreenSetting,
          carPlaySetting: settings.carPlaySetting,
          criticalAlertSetting: settings.criticalAlertSetting,
          announcementSetting: settings.announcementSetting,
          isAuthorized: settings.authorizationStatus == .authorized,
          canScheduleNotifications: settings.authorizationStatus == .authorized || settings
            .authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral)

        print("🧪 NotificationManager: Permission test completed")
        print("🧪   Is Authorized: \(result.isAuthorized)")
        print("🧪   Can Schedule: \(result.canScheduleNotifications)")
        print("🧪   Status: \(result.authorizationStatus.rawValue)")

        completion(result)
      }
    }
  }

  /// Get notification permission history from UserDefaults
  func getNotificationPermissionHistory() -> NotificationPermissionHistory {
    let granted = UserDefaults.standard.bool(forKey: "notificationPermissionGranted")
    let grantedDate = UserDefaults.standard
      .object(forKey: "notificationPermissionGrantedDate") as? Date
    let deniedDate = UserDefaults.standard
      .object(forKey: "notificationPermissionDeniedDate") as? Date
    let errorMessage = UserDefaults.standard.string(forKey: "notificationPermissionError")
    let errorDate = UserDefaults.standard.object(forKey: "notificationPermissionErrorDate") as? Date

    return NotificationPermissionHistory(
      wasGranted: granted,
      grantedDate: grantedDate,
      deniedDate: deniedDate,
      errorMessage: errorMessage,
      errorDate: errorDate)
  }

  /// Request notification permission with user-friendly messaging
  func requestNotificationPermissionWithExplanation() {
    print("📱 NotificationManager: Requesting notification permission with explanation...")

    // First check current status
    checkNotificationPermissionStatus { status in
      switch status {
      case .authorized:
        print("✅ NotificationManager: Permission already granted")

      case .denied:
        print("🚫 NotificationManager: Permission previously denied - user must enable in Settings")

      // Could show alert to guide user to Settings
      case .notDetermined:
        print("❓ NotificationManager: Permission not determined - requesting now")
        self.requestNotificationPermission()

      case .provisional:
        print("✅ NotificationManager: Provisional permission granted")

      case .ephemeral:
        print("✅ NotificationManager: Ephemeral permission granted")

      @unknown default:
        print("⚠️ NotificationManager: Unknown permission status")
      }
    }
  }

  /// Validate notification scheduling with comprehensive error handling
  func validateNotificationScheduling(completion: @escaping (NotificationValidationResult)
    -> Void)
  {
    print("🔍 NotificationManager: Validating notification scheduling capabilities...")

    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        var validationResult = NotificationValidationResult()

        // Check authorization status
        switch settings.authorizationStatus {
        case .authorized:
          validationResult.isAuthorized = true
          validationResult.canSchedule = true
          validationResult.statusMessage = "Notifications are authorized"

        case .denied:
          validationResult.isAuthorized = false
          validationResult.canSchedule = false
          validationResult.statusMessage = "Notifications are denied - user must enable in Settings"
          validationResult.requiresUserAction = true

        case .notDetermined:
          validationResult.isAuthorized = false
          validationResult.canSchedule = false
          validationResult.statusMessage = "Notification permission not determined - requesting now"
          validationResult.requiresPermissionRequest = true

        case .provisional:
          validationResult.isAuthorized = true
          validationResult.canSchedule = true
          validationResult.statusMessage = "Provisional notification permission granted"

        case .ephemeral:
          validationResult.isAuthorized = true
          validationResult.canSchedule = true
          validationResult.statusMessage = "Ephemeral notification permission granted"

        @unknown default:
          validationResult.isAuthorized = false
          validationResult.canSchedule = false
          validationResult.statusMessage = "Unknown notification permission status"
        }

        // Check specific notification settings
        validationResult.canShowAlerts = settings.alertSetting == .enabled
        validationResult.canShowBadges = settings.badgeSetting == .enabled
        validationResult.canPlaySounds = settings.soundSetting == .enabled
        validationResult.canShowInNotificationCenter = settings
          .notificationCenterSetting == .enabled
        validationResult.canShowOnLockScreen = settings.lockScreenSetting == .enabled
        validationResult.canShowInCarPlay = settings.carPlaySetting == .enabled

        // Check iOS 14+ features
        if #available(iOS 14.0, *) {
          validationResult.canShowCriticalAlerts = settings.criticalAlertSetting == .enabled
          validationResult.canShowAnnouncements = settings.announcementSetting == .enabled
        }

        // Determine overall capability
        validationResult.overallCapability = validationResult.canSchedule &&
          validationResult.canShowAlerts &&
          validationResult.canShowBadges &&
          validationResult.canPlaySounds

        print("🔍 NotificationManager: Validation completed:")
        print("🔍   Can Schedule: \(validationResult.canSchedule)")
        print("🔍   Overall Capability: \(validationResult.overallCapability)")
        print("🔍   Status: \(validationResult.statusMessage)")

        completion(validationResult)
      }
    }
  }

  /// Test notification delivery with a test notification
  func testNotificationDelivery(completion: @escaping (Bool) -> Void) {
    print("🧪 NotificationManager: Testing notification delivery...")

    // Validate permissions first
    validateNotificationScheduling { validationResult in
      guard validationResult.canSchedule else {
        print("❌ NotificationManager: Cannot test notification delivery - scheduling not available")
        completion(false)
        return
      }

      // Create test notification
      let content = UNMutableNotificationContent()
      content.title = "Test Notification"
      content.body = "This is a test notification to verify delivery"
      content.sound = .default
      content.badge = 1

      // Schedule for 5 seconds from now
      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
      let request = UNNotificationRequest(
        identifier: "test_notification",
        content: content,
        trigger: trigger)

      UNUserNotificationCenter.current().add(request) { error in
        DispatchQueue.main.async {
          if let error {
            print("❌ NotificationManager: Test notification failed: \(error.localizedDescription)")
            completion(false)
          } else {
            print("✅ NotificationManager: Test notification scheduled successfully")
            completion(true)
          }
        }
      }
    }
  }

  /// Schedule a notification for a habit reminder
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
      trigger: trigger)

    // Schedule the notification
    // Using callback-based approach for consistency - async alternative available but requires
    // refactoring
    UNUserNotificationCenter.current().add(request) { error in
      if let error {
        print("❌ Error scheduling notification: \(error)")
      } else {
        print("✅ Notification scheduled for habit: \(habit.name) at \(reminderTime)")
      }
    }
  }

  /// Remove a specific notification
  func removeNotification(withId id: String) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    print("🗑️ Removed notification with ID: \(id)")
  }

  /// Remove all notifications for a habit
  func removeAllNotifications(for habit: Habit) {
    let habitNotificationIds = getNotificationIds(for: habit)
    UNUserNotificationCenter.current()
      .removePendingNotificationRequests(withIdentifiers: habitNotificationIds)
    print("🗑️ Removed all notifications for habit: \(habit.name)")
  }

  /// Update notifications for a habit when reminders change
  func updateNotifications(for habit: Habit, reminders: [ReminderItem]) {
    // First, remove all existing notifications for this habit
    removeAllNotifications(for: habit)

    // Check if habit reminders are globally enabled (default to true if not set)
    let habitReminderEnabled = UserDefaults.standard.object(forKey: "habitReminderEnabled") as? Bool ?? true
    if !habitReminderEnabled {
      print(
        "📅 NotificationManager: Habit reminders globally disabled, skipping individual habit notifications for '\(habit.name)'")
      return
    }

    // Schedule notifications for the next 7 days for this specific habit
    let calendar = Calendar.current
    let today = Date()

    for dayOffset in 0 ..< 7 {
      if let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
        // Only schedule if habit should be shown on this date
        if shouldShowHabitOnDate(habit, date: targetDate) {
          for reminder in reminders where reminder.isActive {
            let notificationId = "habit_reminder_\(habit.id.uuidString)_\(reminder.id.uuidString)_\(DateUtils.dateKey(for: targetDate))"

            // Create content
            let content = UNMutableNotificationContent()
            content.title = "Habit Reminder"
            content.body = "Time to complete: \(habit.name)"
            content.sound = .default
            content.badge = 1

            // Create date components for the specific date and reminder time
            // Use local timezone for both reminder time and target date
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
            let trigger = UNCalendarNotificationTrigger(
              dateMatching: combinedComponents,
              repeats: false)

            // Create request
            let request = UNNotificationRequest(
              identifier: notificationId,
              content: content,
              trigger: trigger)

            // Schedule the notification
            UNUserNotificationCenter.current().add(request) { error in
              if let error {
                print(
                  "❌ Error scheduling notification for \(habit.name) on \(targetDate): \(error)")
              } else {
                print(
                  "✅ NotificationManager: Scheduled notification for habit '\(habit.name)' on \(targetDate) at \(reminder.time)")
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

  /// Check notification permission status
  func checkNotificationPermission(completion: @escaping (Bool) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        completion(settings.authorizationStatus == .authorized)
      }
    }
  }

  // MARK: - Global Notification Management

  /// Remove all pending notifications
  func removeAllPendingNotifications() {
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    print("🗑️ NotificationManager: Removed all pending notifications")
  }

  /// Remove all delivered notifications
  func removeAllDeliveredNotifications() {
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    print("🗑️ NotificationManager: Removed all delivered notifications")
  }

  /// Clear all notifications (both pending and delivered)
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

  /// Manual notification rescheduling for testing/debugging
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

  /// Reschedule all notifications for all habits
  func rescheduleAllNotifications(for habits: [Habit]) {
    print("🔄 NotificationManager: Rescheduling all notifications for \(habits.count) habits")

    // First, remove all existing notifications
    removeAllPendingNotifications()

    // Schedule notifications for the next 7 days to ensure users get reminders
    let calendar = Calendar.current
    let today = Date()

    for dayOffset in 0 ..< 7 {
      if let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
        scheduleNotificationsForDate(targetDate, habits: habits)
      }
    }

    print("✅ NotificationManager: Completed rescheduling all notifications for next 7 days")
  }

  // MARK: - Friendly Reminder System

  /// Get incomplete scheduled habits for a specific date
  func getIncompleteScheduledHabits(for date: Date, habits: [Habit]) -> [Habit] {
    habits.filter { habit in
      // Check if habit should be shown on this date
      guard shouldShowHabitOnDate(habit, date: date) else { return false }

      // Check if habit is not completed for this date
      return !habit.isCompleted(for: date)
    }
  }

  /// Schedule friendly reminder notifications for incomplete habits
  func scheduleFriendlyReminders(for date: Date, habits: [Habit]) {
    // Check if completion reminders are globally enabled
    let completionReminderEnabled = UserDefaults.standard.bool(forKey: "completionReminderEnabled")
    if !completionReminderEnabled {
      print(
        "🔇 NotificationManager: Completion reminders are disabled, skipping friendly reminders for \(date)")
      return
    }

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
      reminderType: .oneHour)

    // Schedule 3-hour reminder
    scheduleFriendlyReminder(
      for: incompleteHabits,
      date: date,
      hoursBefore: 3,
      reminderType: .threeHour)
  }

  /// Schedule notifications for a specific date (for daily rescheduling)
  func scheduleNotificationsForDate(_ date: Date, habits: [Habit]) {
    print("🔄 NotificationManager: Scheduling notifications for date: \(date)")

    // Check if habit reminders are globally enabled (default to true if not set)
    let habitReminderEnabled = UserDefaults.standard.object(forKey: "habitReminderEnabled") as? Bool ?? true
    if !habitReminderEnabled {
      print(
        "🔇 NotificationManager: Habit reminders are disabled, skipping notifications for \(date)")
      return
    }

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
          let trigger = UNCalendarNotificationTrigger(
            dateMatching: combinedComponents,
            repeats: false)

          // Create request
          let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger)

          // Schedule the notification
          UNUserNotificationCenter.current().add(request) { error in
            if let error {
              print("❌ Error scheduling notification for \(habit.name) on \(date): \(error)")
            } else {
              print(
                "✅ Notification scheduled for habit '\(habit.name)' on \(date) at \(reminder.time)")
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
    logScheduling("Starting daily plan reminders scheduling")

    // Validate notification permissions first
    validateNotificationPermissions { [weak self] hasPermission in
      guard hasPermission else {
        self?.logError("Cannot schedule plan reminders - notification permission denied")
        return
      }

      DispatchQueue.main.async {
        self?.performDailyPlanRemindersScheduling()
      }
    }
  }

  /// Schedule daily completion reminders based on user settings
  @MainActor
  func scheduleDailyCompletionReminders() {
    logScheduling("Starting daily completion reminders scheduling")

    // Validate notification permissions first
    validateNotificationPermissions { [weak self] hasPermission in
      guard hasPermission else {
        self?.logError("Cannot schedule completion reminders - notification permission denied")
        return
      }

      DispatchQueue.main.async {
        self?.performDailyCompletionRemindersScheduling()
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
        UNUserNotificationCenter.current()
          .removePendingNotificationRequests(withIdentifiers: planReminderIds)
        print("✅ NotificationManager: Removed \(planReminderIds.count) daily plan reminders")

        // Log the specific reminders that were removed for debugging
        for id in planReminderIds {
          print("🗑️ NotificationManager: Removed plan reminder: \(id)")
        }
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
        UNUserNotificationCenter.current()
          .removePendingNotificationRequests(withIdentifiers: completionReminderIds)
        print(
          "✅ NotificationManager: Removed \(completionReminderIds.count) daily completion reminders")

        // Log the specific reminders that were removed for debugging
        for id in completionReminderIds {
          print("🗑️ NotificationManager: Removed completion reminder: \(id)")
        }
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
    removeAllHabitReminders()
  }

  /// Remove all habit reminders
  func removeAllHabitReminders() {
    print("🧹 NotificationManager: Removing all habit reminders...")

    // Get all pending notifications
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      // Filter for habit reminders
      let habitReminders = requests.filter { $0.identifier.hasPrefix("habit_reminder_") }

      let identifiersToRemove = habitReminders.map { $0.identifier }

      if !identifiersToRemove.isEmpty {
        UNUserNotificationCenter.current()
          .removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        print("🗑️ NotificationManager: Removed \(identifiersToRemove.count) habit reminders")
      } else {
        print("ℹ️ NotificationManager: No habit reminders found to remove")
      }
    }
  }

  /// Reschedule all daily reminders (useful when settings change)
  @MainActor
  func rescheduleDailyReminders() {
    print("🔄 NotificationManager: Rescheduling all daily reminders...")

    // Step 1: Setup notification categories first (for snooze functionality)
    setupNotificationCategories()

    // Step 2: Perform comprehensive cleanup
    performComprehensiveDailyRemindersCleanup()

    // Step 3: Remove existing daily reminders
    removeAllDailyReminders()

    // Step 4: Schedule new ones based on current settings
    // Only schedule if the user has enabled them
    let planReminderEnabled = UserDefaults.standard.bool(forKey: "planReminderEnabled")
    let completionReminderEnabled = UserDefaults.standard.bool(forKey: "completionReminderEnabled")

    if planReminderEnabled {
      print("📅 NotificationManager: Plan reminders are enabled, scheduling...")
      scheduleDailyPlanReminders()
    } else {
      print("📅 NotificationManager: Plan reminders are disabled, skipping...")
    }

    if completionReminderEnabled {
      print("📅 NotificationManager: Completion reminders are enabled, scheduling...")
      scheduleDailyCompletionReminders()
    } else {
      print("📅 NotificationManager: Completion reminders are disabled, skipping...")
    }

    // Step 5: Schedule habit reminders based on global setting (default to true if not set)
    let habitReminderEnabled = UserDefaults.standard.object(forKey: "habitReminderEnabled") as? Bool ?? true
    if habitReminderEnabled {
      print(
        "📅 NotificationManager: Habit reminders are enabled, rescheduling all existing habits...")
      rescheduleAllHabitReminders()
    } else {
      print("📅 NotificationManager: Habit reminders are disabled, skipping...")
    }

    // Step 6: Get final count for verification
    getPendingDailyRemindersCount { count in
      print("✅ NotificationManager: Daily reminders rescheduled. Total pending: \(count)")
    }

    // Step 7: Debug - List all pending notifications
    debugPendingNotifications()
  }

  /// Reschedule all existing habit reminders (useful when global toggle is turned on)
  @MainActor
  func rescheduleAllHabitReminders() {
    print("🔄 NotificationManager: Rescheduling all existing habit reminders...")

    // Get all habits and reschedule their notifications
    let habits = HabitRepository.shared.habits
    for habit in habits {
      if !habit.reminders.isEmpty {
        print("🔄 Rescheduling notifications for habit: \(habit.name)")
        updateNotifications(for: habit, reminders: habit.reminders)
      }
    }
  }

  /// Force reschedule all habit reminders (bypasses completion checks)
  @MainActor
  func forceRescheduleAllHabitReminders() {
    print("🔄 NotificationManager: Force rescheduling all habit reminders...")

    // Check if habit reminders are globally enabled (default to true if not set)
    let habitReminderEnabled = UserDefaults.standard.object(forKey: "habitReminderEnabled") as? Bool ?? true
    if !habitReminderEnabled {
      print("🔇 NotificationManager: Habit reminders are disabled, cannot force reschedule")
      return
    }

    // First, remove all existing habit reminders
    removeAllHabitReminders()

    // Get all habits and force schedule their notifications
    let habits = HabitRepository.shared.habits
    let calendar = Calendar.current
    let today = Date()

    for habit in habits {
      let activeReminders = habit.reminders.filter { $0.isActive }
      if !activeReminders.isEmpty {
        print(
          "🔄 Force rescheduling notifications for habit: \(habit.name) (\(activeReminders.count) active reminders)")

        // Schedule for the next 7 days
        for dayOffset in 0 ..< 7 {
          if let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
            for reminder in activeReminders {
              let notificationId = "habit_reminder_\(habit.id.uuidString)_\(reminder.id.uuidString)_\(DateUtils.dateKey(for: targetDate))"

              // Create content
              let content = UNMutableNotificationContent()
              content.title = "Habit Reminder"
              content.body = "Time to complete: \(habit.name)"
              content.sound = .default
              content.badge = 1

              // Create date components for the specific date and reminder time
              // Use local timezone for both reminder time and target date
              let reminderComponents = calendar.dateComponents(
                [.hour, .minute],
                from: reminder.time)
              let dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)

              // Combine date and time components
              var combinedComponents = DateComponents()
              combinedComponents.year = dateComponents.year
              combinedComponents.month = dateComponents.month
              combinedComponents.day = dateComponents.day
              combinedComponents.hour = reminderComponents.hour
              combinedComponents.minute = reminderComponents.minute

              // Create trigger for specific date
              let trigger = UNCalendarNotificationTrigger(
                dateMatching: combinedComponents,
                repeats: false)

              // Create request
              let request = UNNotificationRequest(
                identifier: notificationId,
                content: content,
                trigger: trigger)

              // Schedule the notification
              UNUserNotificationCenter.current().add(request) { error in
                if let error {
                  print(
                    "❌ Error force scheduling notification for \(habit.name) on \(targetDate): \(error)")
                } else {
                  print(
                    "✅ Force scheduled notification for habit '\(habit.name)' on \(targetDate) at \(reminder.time) - ID: \(notificationId)")
                }
              }
            }
          }
        }
      }
    }
  }

  /// Test method to immediately schedule a test notification
  @MainActor
  func scheduleTestHabitReminder() {
    print("🧪 NotificationManager: Scheduling test habit reminder...")

    // Check notification authorization
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      print("🔐 Test - Notification authorization status: \(settings.authorizationStatus.rawValue)")
      if settings.authorizationStatus != .authorized {
        print(
          "❌ Test - Notifications not authorized! Status: \(settings.authorizationStatus.rawValue)")
        return
      }

      // Schedule a test notification for 10 seconds from now
      let content = UNMutableNotificationContent()
      content.title = "🧪 TEST Habit Reminder"
      content.body = "This is a test notification to verify the system is working"
      content.sound = .default
      content.badge = 1

      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
      let request = UNNotificationRequest(
        identifier: "test_habit_reminder",
        content: content,
        trigger: trigger)

      UNUserNotificationCenter.current().add(request) { error in
        if let error {
          print("❌ Test - Error scheduling test notification: \(error)")
        } else {
          print("✅ Test - Test notification scheduled successfully!")
        }
      }
    }
  }

  /// Comprehensive debug method to check everything
  @MainActor
  func debugHabitRemindersStatus() {
    print("🔍 ===== COMPREHENSIVE HABIT REMINDERS DEBUG =====")

    // Check global toggle (default to true if not set)
    let habitReminderEnabled = UserDefaults.standard.object(forKey: "habitReminderEnabled") as? Bool ?? true
    print("🔍 Global habit reminder toggle: \(habitReminderEnabled)")

    // Check habits
    let habits = HabitRepository.shared.habits
    print("🔍 Total habits: \(habits.count)")

    var totalReminders = 0
    var activeReminders = 0

    for habit in habits {
      let habitReminders = habit.reminders
      let activeHabitReminders = habit.reminders.filter { $0.isActive }
      totalReminders += habitReminders.count
      activeReminders += activeHabitReminders.count

      print(
        "🔍 Habit '\(habit.name)': \(habitReminders.count) total, \(activeHabitReminders.count) active reminders")
      for (index, reminder) in habitReminders.enumerated() {
        print("  Reminder \(index + 1): \(reminder.time) - Active: \(reminder.isActive)")
      }
    }

    print("🔍 Total reminders across all habits: \(totalReminders) total, \(activeReminders) active")

    // Check notification authorization
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      print("🔍 Notification authorization: \(settings.authorizationStatus.rawValue)")
      print("🔍 Alert setting: \(settings.alertSetting.rawValue)")
      print("🔍 Badge setting: \(settings.badgeSetting.rawValue)")
      print("🔍 Sound setting: \(settings.soundSetting.rawValue)")

      // Check pending notifications
      UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
        print("🔍 Total pending notifications: \(requests.count)")

        let habitReminders = requests.filter { $0.identifier.hasPrefix("habit_reminder_") }
        print("🔍 Pending habit reminders: \(habitReminders.count)")

        for request in habitReminders {
          print("  - \(request.identifier)")
          print("    Title: \(request.content.title)")
          print("    Body: \(request.content.body)")
        }

        print("🔍 ===== END DEBUG =====")
      }
    }
  }

  /// Initialize notification categories at app startup
  func initializeNotificationCategories() {
    print("🔧 NotificationManager: Initializing notification categories...")
    setupNotificationCategories()
  }

  /// Handle vacation mode changes - reschedule daily reminders when vacation mode changes
  @MainActor
  func handleVacationModeChange() {
    print("🏖️ NotificationManager: Vacation mode changed, rescheduling daily reminders...")

    // Perform comprehensive cleanup to remove any vacation day reminders
    performComprehensiveDailyRemindersCleanup()

    // Reschedule daily reminders (this will respect current vacation mode settings)
    rescheduleDailyReminders()

    print("✅ NotificationManager: Daily reminders rescheduled for vacation mode change")
  }

  /// Handle snooze action for completion reminders
  func handleSnoozeAction(for notificationId: String, snoozeMinutes: Int) {
    logSnooze("Handling snooze action", metadata: [
      "notificationId": notificationId,
      "snoozeMinutes": snoozeMinutes
    ])

    // Validate snooze minutes
    guard snoozeMinutes > 0, snoozeMinutes <= 60 else {
      logError("Invalid snooze duration", metadata: [
        "snoozeMinutes": snoozeMinutes,
        "validRange": "1-60 minutes"
      ])
      return
    }

    // Extract date from notification ID
    let dateKey = notificationId.replacingOccurrences(of: "daily_completion_reminder_", with: "")

    // Parse date from dateKey (assuming format like "2024-01-15")
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    guard let date = dateFormatter.date(from: dateKey) else {
      print("❌ NotificationManager: Could not parse date from notification ID: \(notificationId)")
      return
    }

    // Check if vacation mode is active - don't schedule snoozed notifications during vacation
    let vacationManager = VacationManager.shared
    if vacationManager.isVacationDay(date) {
      logVacation("Skipping snooze for vacation day", metadata: [
        "date": date.description,
        "notificationId": notificationId
      ])
      return
    }

    // Check if this is already a snoozed notification to prevent infinite snoozing
    let isSnoozeNotification = notificationId.contains("snooze_")
    let snoozeCount = getSnoozeCount(for: dateKey)

    // Limit snooze attempts to prevent infinite snoozing (max 3 snoozes per day)
    if isSnoozeNotification, snoozeCount >= 3 {
      print("⚠️ NotificationManager: Maximum snooze limit reached for \(dateKey) (3 snoozes)")
      return
    }

    // Calculate snooze time
    let calendar = Calendar.current
    let snoozeTime = calendar.date(byAdding: .minute, value: snoozeMinutes, to: Date()) ?? Date()

    // Create snooze notification with unique identifier
    let snoozeNotificationId = "daily_completion_reminder_snooze_\(dateKey)_\(Int(snoozeTime.timeIntervalSince1970))"

    // Increment snooze count
    incrementSnoozeCount(for: dateKey)

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

      // Add snooze actions if snooze is still enabled and under limit
      let snoozeDuration = getSnoozeDuration()
      if snoozeDuration != .none, snoozeCount < 3 {
        content.categoryIdentifier = "COMPLETION_REMINDER_CATEGORY"
      }

      // Create trigger for snooze time
      let trigger = UNTimeIntervalNotificationTrigger(
        timeInterval: TimeInterval(snoozeMinutes * 60),
        repeats: false)

      // Create request
      let request = UNNotificationRequest(
        identifier: snoozeNotificationId,
        content: content,
        trigger: trigger)

      // Schedule the snooze notification
      do {
        try await UNUserNotificationCenter.current().add(request)
        print(
          "✅ Snooze notification scheduled for \(snoozeMinutes) minutes from now (snooze count: \(snoozeCount + 1))")
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
        UNUserNotificationCenter.current()
          .removePendingNotificationRequests(withIdentifiers: snoozeReminderIds)
        print(
          "✅ NotificationManager: Removed \(snoozeReminderIds.count) snoozed completion reminders")
      } else {
        print("ℹ️ NotificationManager: No snoozed completion reminders to remove")
      }
    }
  }

  // MARK: - Enhanced Notification Management

  /// Check for and remove duplicate daily reminders
  func removeDuplicateDailyReminders() {
    print("🔍 NotificationManager: Checking for duplicate daily reminders...")

    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      var seenIdentifiers: Set<String> = []
      var duplicateIds: [String] = []

      for request in requests {
        if request.identifier.hasPrefix("daily_plan_reminder_") ||
          request.identifier.hasPrefix("daily_completion_reminder_")
        {
          if seenIdentifiers.contains(request.identifier) {
            duplicateIds.append(request.identifier)
            print("⚠️ NotificationManager: Found duplicate reminder: \(request.identifier)")
          } else {
            seenIdentifiers.insert(request.identifier)
          }
        }
      }

      if !duplicateIds.isEmpty {
        UNUserNotificationCenter.current()
          .removePendingNotificationRequests(withIdentifiers: duplicateIds)
        print("✅ NotificationManager: Removed \(duplicateIds.count) duplicate daily reminders")
      } else {
        print("ℹ️ NotificationManager: No duplicate daily reminders found")
      }
    }
  }

  /// Remove expired daily reminders (older than 7 days)
  func removeExpiredDailyReminders() {
    print("🗑️ NotificationManager: Checking for expired daily reminders...")

    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      let calendar = Calendar.current
      let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
      var expiredIds: [String] = []

      for request in requests {
        if request.identifier.hasPrefix("daily_plan_reminder_") ||
          request.identifier.hasPrefix("daily_completion_reminder_")
        {
          // Extract date from identifier (format: daily_plan_reminder_YYYY-MM-DD)
          let components = request.identifier.components(separatedBy: "_")
          if components.count >= 4 {
            let dateString = components[3]
            // Parse date string back to Date using the same format as dateKey
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let requestDate = formatter.date(from: dateString) {
              if requestDate < sevenDaysAgo {
                expiredIds.append(request.identifier)
                print(
                  "🗑️ NotificationManager: Found expired reminder: \(request.identifier) (date: \(dateString))")
              }
            }
          }
        }
      }

      if !expiredIds.isEmpty {
        UNUserNotificationCenter.current()
          .removePendingNotificationRequests(withIdentifiers: expiredIds)
        print("✅ NotificationManager: Removed \(expiredIds.count) expired daily reminders")
      } else {
        print("ℹ️ NotificationManager: No expired daily reminders found")
      }
    }
  }

  /// Remove daily reminders for specific dates
  func removeDailyRemindersForDates(_ dates: [Date]) {
    print("🗑️ NotificationManager: Removing daily reminders for \(dates.count) specific dates...")

    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      var idsToRemove: [String] = []
      let dateKeys = Set(dates.map { DateUtils.dateKey(for: $0) })

      for request in requests {
        if request.identifier.hasPrefix("daily_plan_reminder_") ||
          request.identifier.hasPrefix("daily_completion_reminder_")
        {
          // Extract date from identifier
          let components = request.identifier.components(separatedBy: "_")
          if components.count >= 4 {
            let dateString = components[3]
            if dateKeys.contains(dateString) {
              idsToRemove.append(request.identifier)
            }
          }
        }
      }

      if !idsToRemove.isEmpty {
        UNUserNotificationCenter.current()
          .removePendingNotificationRequests(withIdentifiers: idsToRemove)
        print(
          "✅ NotificationManager: Removed \(idsToRemove.count) daily reminders for specified dates")

        for id in idsToRemove {
          print("🗑️ NotificationManager: Removed reminder: \(id)")
        }
      } else {
        print("ℹ️ NotificationManager: No daily reminders found for specified dates")
      }
    }
  }

  /// Get count of pending daily reminders
  func getPendingDailyRemindersCount(completion: @escaping (Int) -> Void) {
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      let dailyReminderCount = requests.filter { request in
        request.identifier.hasPrefix("daily_plan_reminder_") ||
          request.identifier.hasPrefix("daily_completion_reminder_")
      }.count

      DispatchQueue.main.async {
        completion(dailyReminderCount)
      }
    }
  }

  /// Get detailed information about pending daily reminders
  func getPendingDailyRemindersInfo(completion: @escaping ([(
    identifier: String,
    date: String,
    type: String)]) -> Void)
  {
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      var remindersInfo: [(identifier: String, date: String, type: String)] = []

      for request in requests {
        if request.identifier.hasPrefix("daily_plan_reminder_") ||
          request.identifier.hasPrefix("daily_completion_reminder_")
        {
          let components = request.identifier.components(separatedBy: "_")
          if components.count >= 4 {
            let dateString = components[3]
            let type = request.identifier.hasPrefix("daily_plan_reminder_") ? "Plan" : "Completion"
            remindersInfo.append((request.identifier, dateString, type))
          }
        }
      }

      DispatchQueue.main.async {
        completion(remindersInfo)
      }
    }
  }

  /// Check if any daily reminders are scheduled for vacation days
  func checkForVacationDayReminders(completion: @escaping (Int) -> Void) {
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      let vacationManager = VacationManager.shared
      var vacationReminderCount = 0

      for request in requests {
        if request.identifier.hasPrefix("daily_plan_reminder_") ||
          request.identifier.hasPrefix("daily_completion_reminder_") ||
          request.identifier.hasPrefix("daily_completion_reminder_snooze_")
        {
          // Extract date from identifier
          let components = request.identifier.components(separatedBy: "_")
          if components.count >= 4 {
            let dateString = components[3]

            // Parse date from dateString
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateString) {
              // Check if this date is a vacation day
              if vacationManager.isVacationDay(date) {
                vacationReminderCount += 1
              }
            }
          }
        }
      }

      DispatchQueue.main.async {
        completion(vacationReminderCount)
      }
    }
  }

  /// Comprehensive cleanup of all daily reminders with enhanced logging
  func performComprehensiveDailyRemindersCleanup() {
    logCleanup("Starting comprehensive daily reminders cleanup")

    // Step 1: Remove duplicates
    logCleanup("Step 1: Removing duplicate reminders")
    removeDuplicateDailyReminders()

    // Step 2: Remove expired reminders
    logCleanup("Step 2: Removing expired reminders")
    removeExpiredDailyReminders()

    // Step 3: Remove vacation day reminders
    logCleanup("Step 3: Removing vacation day reminders")
    removeVacationDayReminders()

    // Step 4: Clean up old snooze counts
    logCleanup("Step 4: Cleaning up old snooze counts")
    cleanupOldSnoozeCounts()

    // Step 5: Get final count
    getPendingDailyRemindersCount { count in
      self.logCleanup("Comprehensive cleanup completed", metadata: ["remainingReminders": count])
    }
  }

  // MARK: Private

  private let logger = NotificationLogger.shared

  // Calendar/Locale injection for deterministic behavior (especially DST)
  private var injectedCalendar: Calendar?
  private var injectedTimeZone: TimeZone?
  private var injectedLocale: Locale?

  private func getCalendar() -> Calendar {
    injectedCalendar ?? Calendar.current
  }

  private func getTimeZone() -> TimeZone {
    injectedTimeZone ?? TimeZone.current
  }

  private func getLocale() -> Locale {
    injectedLocale ?? Locale.current
  }

  // MARK: - Logging Methods

  /// Log debug information
  private func logDebug(
    _ message: String,
    category: String = "NotificationManager",
    metadata: [String: Any]? = nil)
  {
    logger.log(.debug, category: category, message: message, metadata: metadata)
  }

  /// Log informational messages
  private func logInfo(
    _ message: String,
    category: String = "NotificationManager",
    metadata: [String: Any]? = nil)
  {
    logger.log(.info, category: category, message: message, metadata: metadata)
  }

  /// Log warnings
  private func logWarning(
    _ message: String,
    category: String = "NotificationManager",
    metadata: [String: Any]? = nil)
  {
    logger.log(.warning, category: category, message: message, metadata: metadata)
  }

  /// Log errors
  private func logError(
    _ message: String,
    category: String = "NotificationManager",
    metadata: [String: Any]? = nil)
  {
    logger.log(.error, category: category, message: message, metadata: metadata)
  }

  /// Log success messages
  private func logSuccess(
    _ message: String,
    category: String = "NotificationManager",
    metadata: [String: Any]? = nil)
  {
    logger.log(.success, category: category, message: message, metadata: metadata)
  }

  /// Log notification-related messages
  private func logNotification(
    _ message: String,
    category: String = "NotificationManager",
    metadata: [String: Any]? = nil)
  {
    logger.log(.notification, category: category, message: message, metadata: metadata)
  }

  /// Log scheduling-related messages
  private func logScheduling(
    _ message: String,
    category: String = "NotificationManager",
    metadata: [String: Any]? = nil)
  {
    logger.log(.scheduling, category: category, message: message, metadata: metadata)
  }

  /// Log cleanup-related messages
  private func logCleanup(
    _ message: String,
    category: String = "NotificationManager",
    metadata: [String: Any]? = nil)
  {
    logger.log(.cleanup, category: category, message: message, metadata: metadata)
  }

  /// Log permission-related messages
  private func logPermission(
    _ message: String,
    category: String = "NotificationManager",
    metadata: [String: Any]? = nil)
  {
    logger.log(.permission, category: category, message: message, metadata: metadata)
  }

  /// Log vacation-related messages
  private func logVacation(
    _ message: String,
    category: String = "NotificationManager",
    metadata: [String: Any]? = nil)
  {
    logger.log(.vacation, category: category, message: message, metadata: metadata)
  }

  /// Log snooze-related messages
  private func logSnooze(
    _ message: String,
    category: String = "NotificationManager",
    metadata: [String: Any]? = nil)
  {
    logger.log(.snooze, category: category, message: message, metadata: metadata)
  }

  /// Log test-related messages
  private func logTest(
    _ message: String,
    category: String = "NotificationManager",
    metadata: [String: Any]? = nil)
  {
    logger.log(.test, category: category, message: message, metadata: metadata)
  }

  /// Handle notification permission granted
  private func handleNotificationPermissionGranted() {
    print(
      "🎉 NotificationManager: Notification permission granted - enabling all notification features")

    // Setup notification categories for snooze functionality
    setupNotificationCategories()

    // Store permission granted state
    UserDefaults.standard.set(true, forKey: "notificationPermissionGranted")
    UserDefaults.standard.set(Date(), forKey: "notificationPermissionGrantedDate")

    // Log permission details
    logNotificationPermissionDetails()
  }

  /// Handle notification permission denied
  private func handleNotificationPermissionDenied() {
    print("🚫 NotificationManager: Notification permission denied - disabling notification features")

    // Clear any existing notification categories
    UNUserNotificationCenter.current().setNotificationCategories([])

    // Store permission denied state
    UserDefaults.standard.set(false, forKey: "notificationPermissionGranted")
    UserDefaults.standard.set(Date(), forKey: "notificationPermissionDeniedDate")

    // Cancel all pending notifications
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

    print("🧹 NotificationManager: Cleared all pending notifications due to permission denial")
  }

  /// Handle notification permission error
  private func handleNotificationPermissionError(_ error: Error) {
    print("💥 NotificationManager: Notification permission error: \(error.localizedDescription)")

    // Store error state
    UserDefaults.standard.set(false, forKey: "notificationPermissionGranted")
    UserDefaults.standard.set(error.localizedDescription, forKey: "notificationPermissionError")
    UserDefaults.standard.set(Date(), forKey: "notificationPermissionErrorDate")

    // Log additional error details
    if let nsError = error as NSError? {
      print("💥 NotificationManager: Error domain: \(nsError.domain)")
      print("💥 NotificationManager: Error code: \(nsError.code)")
      print("💥 NotificationManager: Error userInfo: \(nsError.userInfo)")
    }
  }

  /// Log detailed notification permission information
  private func logNotificationPermissionDetails() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        print("📊 NotificationManager: Permission Details:")
        print("📊   Authorization Status: \(settings.authorizationStatus.rawValue)")
        print("📊   Alert Setting: \(settings.alertSetting.rawValue)")
        print("📊   Badge Setting: \(settings.badgeSetting.rawValue)")
        print("📊   Sound Setting: \(settings.soundSetting.rawValue)")
        print("📊   Notification Center Setting: \(settings.notificationCenterSetting.rawValue)")
        print("📊   Lock Screen Setting: \(settings.lockScreenSetting.rawValue)")
        print("📊   Car Play Setting: \(settings.carPlaySetting.rawValue)")

        if #available(iOS 14.0, *) {
          print("📊   Critical Alert Setting: \(settings.criticalAlertSetting.rawValue)")
          print("📊   Announcement Setting: \(settings.announcementSetting.rawValue)")
        }
      }
    }
  }

  /// Get notification IDs for a habit
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

  /// Check if habit should be shown on a specific date
  private func shouldShowHabitOnDate(_ habit: Habit, date: Date) -> Bool {
    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: date)
    let dateKey = calendar.startOfDay(for: date)

    // Check if the date is before the habit start date
    if dateKey < calendar.startOfDay(for: habit.startDate) {
      print(
        "🔍 NOTIFICATION DEBUG - Habit '\(habit.name)' not scheduled on \(dateKey): Date before start date")
      return false
    }

    // Check if the date is after the habit end date (if set)
    if let endDate = habit.endDate, dateKey > calendar.startOfDay(for: endDate) {
      print(
        "🔍 NOTIFICATION DEBUG - Habit '\(habit.name)' not scheduled on \(dateKey): Date after end date")
      return false
    }

    // Check if the habit is already completed for this date (only for today, not future dates)
    let today = calendar.startOfDay(for: Date())
    if dateKey == today, habit.isCompleted(for: date) {
      print(
        "🔍 NOTIFICATION DEBUG - Habit '\(habit.name)' not scheduled on \(dateKey): Already completed for today")
      return false
    }

    // Check if the habit is scheduled for this weekday
    let isScheduledForWeekday = isHabitScheduledForWeekday(habit, weekday: weekday)

    print(
      "🔍 NOTIFICATION DEBUG - Habit '\(habit.name)' | Date: \(dateKey) | Weekday: \(weekday) | Schedule: '\(habit.schedule)' | Scheduled for weekday: \(isScheduledForWeekday)")

    if !isScheduledForWeekday {
      print(
        "🔍 NOTIFICATION DEBUG - Habit '\(habit.name)' not scheduled on \(dateKey): Not scheduled for weekday \(weekday)")
    }

    return isScheduledForWeekday
  }

  /// Helper method to check if habit is scheduled for a specific weekday
  private func isHabitScheduledForWeekday(_ habit: Habit, weekday: Int) -> Bool {
    switch habit.schedule.lowercased() {
    case "daily",
         "everyday":
      true
    case "weekdays":
      weekday >= 2 && weekday <= 6 // Monday = 2, Friday = 6
    case "weekends":
      weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
    case "mon",
         "monday":
      weekday == 2
    case "tue",
         "tuesday":
      weekday == 3
    case "wed",
         "wednesday":
      weekday == 4
    case "thu",
         "thursday":
      weekday == 5
    case "fri",
         "friday":
      weekday == 6
    case "sat",
         "saturday":
      weekday == 7
    case "sun",
         "sunday":
      weekday == 1
    default:
      // For custom schedules, assume it's scheduled
      true
    }
  }

  /// Schedule a specific friendly reminder
  private func scheduleFriendlyReminder(
    for habits: [Habit],
    date: Date,
    hoursBefore: Int,
    reminderType: FriendlyReminderType)
  {
    let calendar = Calendar.current
    let currentTime = Date()
    let targetTime = calendar.date(
      byAdding: .hour,
      value: -hoursBefore,
      to: calendar.startOfDay(for: date).addingTimeInterval(24 * 60 * 60)) ?? currentTime

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
    let components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute],
      from: targetTime)
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

    // Create request
    let request = UNNotificationRequest(
      identifier: notificationId,
      content: content,
      trigger: trigger)

    // Schedule the notification
    UNUserNotificationCenter.current().add(request) { error in
      if let error {
        print("❌ Error scheduling friendly reminder: \(error)")
      } else {
        print(
          "✅ Friendly reminder scheduled for \(hoursBefore)h before \(date) - \(habits.count) incomplete habits")
      }
    }
  }

  /// Get friendly reminder title based on habits and reminder type
  private func getFriendlyReminderTitle(
    for habits: [Habit],
    reminderType: FriendlyReminderType) -> String
  {
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

  /// Get friendly reminder message based on habits and reminder type
  private func getFriendlyReminderMessage(
    for habits: [Habit],
    reminderType: FriendlyReminderType) -> String
  {
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

  /// Perform the actual daily plan reminders scheduling (after permission validation)
  @MainActor
  private func performDailyPlanRemindersScheduling() {
    // Check if plan reminders are enabled
    let planReminderEnabled = UserDefaults.standard.bool(forKey: "planReminderEnabled")
    guard planReminderEnabled else {
      logInfo(
        "Plan reminders are disabled",
        metadata: ["setting": "planReminderEnabled", "value": false])
      return
    }

    // Get the reminder time from UserDefaults
    guard let planReminderTime = UserDefaults.standard.object(forKey: "planReminderTime") as? Date else {
      logError("No plan reminder time set", metadata: ["setting": "planReminderTime"])
      return
    }

    logScheduling("Plan reminders enabled", metadata: [
      "enabled": true,
      "reminderTime": planReminderTime.description
    ])

    // Get habits from HabitRepository
    let habits = HabitRepository.shared.habits
    logScheduling("Found habits for plan reminders", metadata: ["habitCount": habits.count])

    // Schedule plan reminders for the next 7 days
    let calendar = Calendar.current
    let today = Date()

    for dayOffset in 0 ..< 7 {
      if let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
        schedulePlanReminderForDate(targetDate, reminderTime: planReminderTime, habits: habits)
      }
    }

    print("✅ NotificationManager: Daily plan reminders scheduled for next 7 days")
  }

  /// Perform the actual daily completion reminders scheduling (after permission validation)
  @MainActor
  private func performDailyCompletionRemindersScheduling() {
    // Check if completion reminders are enabled
    let completionReminderEnabled = UserDefaults.standard.bool(forKey: "completionReminderEnabled")
    guard completionReminderEnabled else {
      logInfo(
        "Completion reminders are disabled",
        metadata: ["setting": "completionReminderEnabled", "value": false])
      return
    }

    // Get the reminder time from UserDefaults
    guard let completionReminderTime = UserDefaults.standard
      .object(forKey: "completionReminderTime") as? Date else
    {
      logError("No completion reminder time set", metadata: ["setting": "completionReminderTime"])
      return
    }

    logScheduling("Completion reminders enabled", metadata: [
      "enabled": true,
      "reminderTime": completionReminderTime.description
    ])

    // Setup notification categories for snooze functionality
    setupNotificationCategories()

    // Get habits from HabitRepository
    let habits = HabitRepository.shared.habits
    print("📅 NotificationManager: Found \(habits.count) habits for completion reminders")

    // Schedule completion reminders for the next 7 days
    let calendar = Calendar.current
    let today = Date()

    for dayOffset in 0 ..< 7 {
      if let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
        scheduleCompletionReminderForDate(
          targetDate,
          reminderTime: completionReminderTime,
          habits: habits)
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

    // Check if this reminder already exists to prevent duplicates
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      let existingReminder = requests.first { $0.identifier == notificationId }
      if existingReminder != nil {
        print("⚠️ NotificationManager: Plan reminder already exists for \(date), skipping duplicate")
        return
      }

      // Create dynamic notification content based on habit count
      let content = UNMutableNotificationContent()
      content.title = self.generatePlanReminderTitle(habitCount: habitCount)
      content.body = self.generatePlanReminderMessage(habitCount: habitCount)
      content.sound = .default
      content.badge = 1

      // Create date components for the reminder time on the specific date
      // Use the same timezone for both reminder time and target date
      let reminderComponents = calendar.dateComponents(in: .current, from: reminderTime)
      let dateComponents = calendar.dateComponents(in: .current, from: date)

      // Debug logging
      print("🔍 NotificationManager: Plan reminder scheduling debug:")
      print("  - Target date: \(date)")
      print("  - Reminder time: \(reminderTime)")
      print("  - Reminder components: \(reminderComponents)")
      print("  - Date components: \(dateComponents)")

      // Combine date and time components
      var combinedComponents = DateComponents()
      combinedComponents.year = dateComponents.year
      combinedComponents.month = dateComponents.month
      combinedComponents.day = dateComponents.day
      combinedComponents.hour = reminderComponents.hour
      combinedComponents.minute = reminderComponents.minute

      print("  - Combined components: \(combinedComponents)")

      // Create trigger for specific date
      let trigger = UNCalendarNotificationTrigger(dateMatching: combinedComponents, repeats: false)

      // Create request
      let request = UNNotificationRequest(
        identifier: notificationId,
        content: content,
        trigger: trigger)

      // Schedule the notification
      UNUserNotificationCenter.current().add(request) { error in
        if let error {
          print("❌ Error scheduling plan reminder for \(date): \(error)")
        } else {
          print("✅ Plan reminder scheduled for \(date) at \(reminderTime) - \(habitCount) habits")
        }
      }
    }
  }

  /// Schedule a completion reminder for a specific date
  private func scheduleCompletionReminderForDate(
    _ date: Date,
    reminderTime: Date,
    habits: [Habit])
  {
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

    // Check if this reminder already exists to prevent duplicates
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      let existingReminder = requests.first { $0.identifier == notificationId }
      if existingReminder != nil {
        print(
          "⚠️ NotificationManager: Completion reminder already exists for \(date), skipping duplicate")
        return
      }

      // Create dynamic notification content based on incomplete habits
      let content = UNMutableNotificationContent()
      content.title = self.generateCompletionReminderTitle(incompleteCount: incompleteCount)
      content.body = self.generateCompletionReminderMessage(incompleteCount: incompleteCount)
      content.sound = .default
      content.badge = 1

      // Add snooze actions if snooze is enabled
      let snoozeDuration = self.getSnoozeDuration()
      if snoozeDuration != .none {
        content.categoryIdentifier = "COMPLETION_REMINDER_CATEGORY"
      }

      // Create date components for the reminder time on the specific date
      // Use the same timezone for both reminder time and target date
      let reminderComponents = calendar.dateComponents(in: .current, from: reminderTime)
      let dateComponents = calendar.dateComponents(in: .current, from: date)

      // Debug logging
      print("🔍 NotificationManager: Completion reminder scheduling debug:")
      print("  - Target date: \(date)")
      print("  - Reminder time: \(reminderTime)")
      print("  - Reminder components: \(reminderComponents)")
      print("  - Date components: \(dateComponents)")

      // Combine date and time components
      var combinedComponents = DateComponents()
      combinedComponents.year = dateComponents.year
      combinedComponents.month = dateComponents.month
      combinedComponents.day = dateComponents.day
      combinedComponents.hour = reminderComponents.hour
      combinedComponents.minute = reminderComponents.minute

      print("  - Combined components: \(combinedComponents)")

      // Create trigger for specific date
      let trigger = UNCalendarNotificationTrigger(dateMatching: combinedComponents, repeats: false)

      // Create request
      let request = UNNotificationRequest(
        identifier: notificationId,
        content: content,
        trigger: trigger)

      // Schedule the notification
      UNUserNotificationCenter.current().add(request) { error in
        if let error {
          print("❌ Error scheduling completion reminder for \(date): \(error)")
        } else {
          print(
            "✅ Completion reminder scheduled for \(date) at \(reminderTime) - \(incompleteCount) incomplete habits")
        }
      }
    }
  }

  /// Schedule all habit reminders for the next 7 days
  @MainActor
  private func scheduleAllHabitReminders() {
    print("📅 NotificationManager: Scheduling all habit reminders...")

    // Check notification authorization first
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      print("🔐 Notification authorization status: \(settings.authorizationStatus.rawValue)")
      if settings.authorizationStatus != .authorized {
        print("⚠️ Notifications not authorized! Status: \(settings.authorizationStatus.rawValue)")
      }
    }

    // Get habits from HabitRepository
    let habits = HabitRepository.shared.habits
    print("📅 NotificationManager: Found \(habits.count) habits for habit reminders")

    // Debug: Check each habit's reminders
    var totalActiveReminders = 0
    for habit in habits {
      let activeReminders = habit.reminders.filter { $0.isActive }
      totalActiveReminders += activeReminders.count
      print(
        "🔍 Habit '\(habit.name)': \(habit.reminders.count) total reminders, \(activeReminders.count) active")
      for (index, reminder) in habit.reminders.enumerated() {
        print("  Reminder \(index + 1): \(reminder.time) - Active: \(reminder.isActive)")
      }
    }

    if totalActiveReminders == 0 {
      print(
        "⚠️ NotificationManager: No active habit reminders found! Users need to add reminders to individual habits first.")
    }

    // Schedule habit reminders for the next 7 days
    let calendar = Calendar.current
    let today = Date()

    for dayOffset in 0 ..< 7 {
      if let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
        scheduleHabitRemindersForDate(targetDate, habits: habits)
      }
    }
  }

  /// Schedule habit reminders for a specific date
  private func scheduleHabitRemindersForDate(_ date: Date, habits: [Habit]) {
    let calendar = Calendar.current

    for habit in habits {
      // Only schedule if habit should be shown on this date
      if shouldShowHabitOnDate(habit, date: date) {
        let activeReminders = habit.reminders.filter { $0.isActive }
        print("🔍 Habit '\(habit.name)' on \(date): \(activeReminders.count) active reminders")

        for reminder in activeReminders {
          let notificationId = "habit_reminder_\(habit.id.uuidString)_\(reminder.id.uuidString)_\(DateUtils.dateKey(for: date))"
          print(
            "🔔 Scheduling notification for habit '\(habit.name)' at \(reminder.time) on \(date) - ID: \(notificationId)")

          // Create content
          let content = UNMutableNotificationContent()
          content.title = "Habit Reminder"
          content.body = "Time to complete: \(habit.name)"
          content.sound = .default
          content.badge = 1

          // Create date components for the reminder time
          let reminderTime = reminder.time
          let reminderComponents = calendar.dateComponents([.hour, .minute], from: reminderTime)
          let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)

          // Combine date and time components
          var combinedComponents = DateComponents()
          combinedComponents.year = dateComponents.year
          combinedComponents.month = dateComponents.month
          combinedComponents.day = dateComponents.day
          combinedComponents.hour = reminderComponents.hour
          combinedComponents.minute = reminderComponents.minute

          // Create trigger
          let trigger = UNCalendarNotificationTrigger(
            dateMatching: combinedComponents,
            repeats: false)

          // Create request
          let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger)

          // Schedule the notification
          UNUserNotificationCenter.current().add(request) { error in
            if let error {
              print("❌ Error scheduling notification for \(habit.name) on \(date): \(error)")
            } else {
              print(
                "✅ Notification scheduled for habit '\(habit.name)' on \(date) at \(reminder.time) - ID: \(notificationId)")
            }
          }
        }
      }
    }
  }

  /// Get snooze duration from UserDefaults
  private func getSnoozeDuration() -> SnoozeDuration {
    if let snoozeRawValue = UserDefaults.standard.string(forKey: "snoozeDuration"),
       let snooze = SnoozeDuration(rawValue: snoozeRawValue)
    {
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
      // Clear any existing categories when snooze is disabled
      UNUserNotificationCenter.current().setNotificationCategories([])
      return
    }

    var actions: [UNNotificationAction] = []

    // Add snooze action based on selected duration
    switch snoozeDuration {
    case .tenMinutes:
      actions.append(UNNotificationAction(
        identifier: "SNOOZE_10_MIN",
        title: "Snooze 10 min",
        options: []))

    case .fifteenMinutes:
      actions.append(UNNotificationAction(
        identifier: "SNOOZE_15_MIN",
        title: "Snooze 15 min",
        options: []))

    case .thirtyMinutes:
      actions.append(UNNotificationAction(
        identifier: "SNOOZE_30_MIN",
        title: "Snooze 30 min",
        options: []))

    case .none:
      break
    }

    // Add dismiss action
    actions.append(UNNotificationAction(
      identifier: "DISMISS",
      title: "Dismiss",
      options: [.destructive]))

    // Create category
    let category = UNNotificationCategory(
      identifier: "COMPLETION_REMINDER_CATEGORY",
      actions: actions,
      intentIdentifiers: [],
      options: [])

    // Register category
    UNUserNotificationCenter.current().setNotificationCategories([category])
    print(
      "✅ NotificationManager: Notification categories set up with snooze duration: \(snoozeDuration.rawValue)")
  }

  /// Get snooze count for a specific date
  private func getSnoozeCount(for dateKey: String) -> Int {
    let key = "snooze_count_\(dateKey)"
    return UserDefaults.standard.integer(forKey: key)
  }

  /// Increment snooze count for a specific date
  private func incrementSnoozeCount(for dateKey: String) {
    let key = "snooze_count_\(dateKey)"
    let currentCount = UserDefaults.standard.integer(forKey: key)
    UserDefaults.standard.set(currentCount + 1, forKey: key)
    print("📊 NotificationManager: Snooze count for \(dateKey): \(currentCount + 1)")
  }

  /// Reset snooze count for a specific date (call when day changes)
  private func resetSnoozeCount(for dateKey: String) {
    let key = "snooze_count_\(dateKey)"
    UserDefaults.standard.removeObject(forKey: key)
    print("🔄 NotificationManager: Reset snooze count for \(dateKey)")
  }

  /// Clean up old snooze counts (older than 7 days)
  private func cleanupOldSnoozeCounts() {
    let calendar = Calendar.current
    let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

    // Get all UserDefaults keys
    let allKeys = UserDefaults.standard.dictionaryRepresentation().keys

    for key in allKeys {
      if key.hasPrefix("snooze_count_") {
        let dateString = String(key.dropFirst("snooze_count_".count))

        // Parse date from key
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString), date < sevenDaysAgo {
          UserDefaults.standard.removeObject(forKey: key)
          print("🗑️ NotificationManager: Cleaned up old snooze count: \(key)")
        }
      }
    }
  }

  /// Remove daily reminders for vacation days
  private func removeVacationDayReminders() {
    print("🗑️ NotificationManager: Checking for vacation day reminders to remove...")

    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      let vacationManager = VacationManager.shared
      var vacationDayIds: [String] = []

      for request in requests {
        if request.identifier.hasPrefix("daily_plan_reminder_") ||
          request.identifier.hasPrefix("daily_completion_reminder_") ||
          request.identifier.hasPrefix("daily_completion_reminder_snooze_")
        {
          // Extract date from identifier
          let components = request.identifier.components(separatedBy: "_")
          if components.count >= 4 {
            let dateString = components[3]

            // Parse date from dateString
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateString) {
              // Check if this date is a vacation day
              if vacationManager.isVacationDay(date) {
                vacationDayIds.append(request.identifier)
                print(
                  "🗑️ NotificationManager: Found vacation day reminder: \(request.identifier) (date: \(dateString))")
              }
            }
          }
        }
      }

      if !vacationDayIds.isEmpty {
        UNUserNotificationCenter.current()
          .removePendingNotificationRequests(withIdentifiers: vacationDayIds)
        print("✅ NotificationManager: Removed \(vacationDayIds.count) vacation day reminders")

        for id in vacationDayIds {
          print("🗑️ NotificationManager: Removed vacation reminder: \(id)")
        }
      } else {
        print("ℹ️ NotificationManager: No vacation day reminders found")
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

    case 2 ... 3:
      let messages = [
        "You have \(habitCount) habits planned for today. Ready to tackle them? 🎯",
        "\(habitCount) habits = \(habitCount) opportunities to grow! 🌱",
        "Your \(habitCount) habits are calling. Let's answer! 📞",
        "Time to conquer your \(habitCount) daily habits! 💪"
      ]
      return messages[habitCount % messages.count]

    case 4 ... 6:
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

    case 2 ... 3:
      let messages = [
        "You have \(incompleteCount) habits left to complete today. Keep going! 💪",
        "Just \(incompleteCount) more habits to finish strong! 🎯",
        "You're in the home stretch! \(incompleteCount) habits to go! 🏁",
        "Almost there! \(incompleteCount) habits left to complete your day! ⚡"
      ]
      return messages[incompleteCount % messages.count]

    case 4 ... 6:
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

    case 2 ... 3:
      let messages = [
        "Break's over! You have \(incompleteCount) habits left to complete today. Keep going! 💪",
        "Time to get back to it! \(incompleteCount) habits are waiting for you! 🎯",
        "Ready to finish strong? \(incompleteCount) habits left to complete your day! ⚡",
        "Let's wrap this up! \(incompleteCount) habits to go and you're done! 🏁"
      ]
      return messages[incompleteCount % messages.count]

    case 4 ... 6:
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
