import Foundation
import SwiftData

/// ReminderModel stores notification reminders for habits
///
/// **Design Philosophy:**
/// - One reminder = one notification time
/// - Can be enabled/disabled without deletion
/// - Stores notification identifier for cancellation
@Model
final class ReminderModel {
    // MARK: - Identity
    
    @Attribute(.unique) var id: UUID
    
    // MARK: - Reminder Data
    
    /// Time of day for reminder (date components used: hour, minute)
    var time: Date
    
    /// Is reminder currently active?
    var isActive: Bool
    
    /// System notification identifier (for cancellation)
    var notificationIdentifier: String?
    
    // MARK: - Metadata
    
    /// When reminder was created
    var createdAt: Date
    
    /// Last time reminder was modified
    var updatedAt: Date
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        time: Date,
        isActive: Bool = true,
        notificationIdentifier: String? = nil
    ) {
        self.id = id
        self.time = time
        self.isActive = isActive
        self.notificationIdentifier = notificationIdentifier
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Helper Methods
    
    /// Get hour component (0-23)
    var hour: Int {
        Calendar.current.component(.hour, from: time)
    }
    
    /// Get minute component (0-59)
    var minute: Int {
        Calendar.current.component(.minute, from: time)
    }
    
    /// Format time as string (e.g., "8:30 AM")
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    /// Toggle active state
    func toggle() {
        isActive.toggle()
        updatedAt = Date()
    }
    
    /// Set notification identifier
    func setNotificationIdentifier(_ identifier: String) {
        notificationIdentifier = identifier
        updatedAt = Date()
    }
}

