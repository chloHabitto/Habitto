import SwiftUI
import UserNotifications
import OSLog

/// Service for handling backup-related notifications and user feedback
@MainActor
class BackupNotificationService: ObservableObject {
    static let shared = BackupNotificationService()
    
    @Published var showingNotification = false
    @Published var notificationTitle = ""
    @Published var notificationMessage = ""
    @Published var notificationType: NotificationType = .info
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "BackupNotificationService")
    
    private init() {}
    
    /// Show a backup notification to the user
    func showNotification(
        title: String,
        message: String,
        type: NotificationType = .info,
        duration: TimeInterval = 3.0
    ) {
        notificationTitle = title
        notificationMessage = message
        notificationType = type
        showingNotification = true
        
        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.showingNotification = false
        }
    }
    
    /// Show backup success notification
    func showBackupSuccess(backupSize: String, habitCount: Int) {
        showNotification(
            title: "Backup Successful",
            message: "Created backup with \(habitCount) habits (\(backupSize))",
            type: .success
        )
    }
    
    /// Show backup failure notification
    func showBackupFailure(error: Error) {
        showNotification(
            title: "Backup Failed",
            message: "Failed to create backup: \(error.localizedDescription)",
            type: .error
        )
    }
    
    /// Show restore success notification
    func showRestoreSuccess(restoredCount: Int) {
        showNotification(
            title: "Restore Successful",
            message: "Successfully restored \(restoredCount) items",
            type: .success
        )
    }
    
    /// Show restore failure notification
    func showRestoreFailure(error: Error) {
        showNotification(
            title: "Restore Failed",
            message: "Failed to restore backup: \(error.localizedDescription)",
            type: .error
        )
    }
    
    /// Show scheduled backup notification
    func showScheduledBackupScheduled(frequency: String) {
        showNotification(
            title: "Backup Scheduled",
            message: "Automatic backups enabled for \(frequency)",
            type: .info
        )
    }
    
    /// Show backup settings changed notification
    func showSettingsChanged() {
        showNotification(
            title: "Settings Updated",
            message: "Backup settings have been saved",
            type: .info
        )
    }
    
    /// Request notification permissions for background backup notifications
    func requestNotificationPermissions() async {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                logger.info("Notification permissions granted")
            } else {
                logger.warning("Notification permissions denied")
            }
        } catch {
            logger.error("Failed to request notification permissions: \(error)")
        }
    }
    
    /// Schedule a local notification for backup completion
    func scheduleBackupCompletionNotification(backupSize: String, habitCount: Int) {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Backup Complete"
        content.body = "Your \(habitCount) habits have been backed up (\(backupSize))"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "backup-completion-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { [self] error in
            if let error = error {
                logger.error("Failed to schedule backup notification: \(error)")
            }
        }
    }
    
    /// Schedule a local notification for backup failure
    func scheduleBackupFailureNotification(error: Error) {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Backup Failed"
        content.body = "Failed to create backup: \(error.localizedDescription)"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "backup-failure-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { [self] error in
            if let error = error {
                logger.error("Failed to schedule backup failure notification: \(error)")
            }
        }
    }
    
    /// Cancel all backup-related notifications
    func cancelBackupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}

/// Types of notifications that can be shown
enum NotificationType {
    case success
    case error
    case warning
    case info
    
    var color: Color {
        switch self {
        case .success: return .green500
        case .error: return .red500
        case .warning: return .yellow500
        case .info: return .navy200
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

/// SwiftUI view for displaying backup notifications
struct BackupNotificationView: View {
    @ObservedObject var notificationService = BackupNotificationService.shared
    
    var body: some View {
        if notificationService.showingNotification {
            HStack(spacing: 12) {
                Image(systemName: notificationService.notificationType.icon)
                    .foregroundColor(notificationService.notificationType.color)
                    .font(.system(size: 20, weight: .medium))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(notificationService.notificationTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.text01)
                    
                    Text(notificationService.notificationMessage)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.text02)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button(action: {
                    notificationService.showingNotification = false
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.text03)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.surface)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 20)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: notificationService.showingNotification)
        }
    }
}

/// View modifier to add backup notifications to any view
struct BackupNotificationModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack {
                BackupNotificationView()
                    .frame(maxWidth: .infinity)
                    .zIndex(1000)
                
                Spacer()
            }
        }
    }
}

extension View {
    func backupNotifications() -> some View {
        modifier(BackupNotificationModifier())
    }
}
