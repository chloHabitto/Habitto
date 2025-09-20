import Foundation
import SwiftUI

// MARK: - Notification Names
extension Notification.Name {
    static let vacationModeEnded = Notification.Name("vacationModeEnded")
}

// MARK: - Vacation Period Model
struct VacationPeriod: Codable, Hashable, Identifiable {
    let id: UUID
    var start: Date        // inclusive
    var end: Date?         // nil if active

    init(id: UUID = .init(), start: Date, end: Date? = nil) {
        self.id = id
        self.start = start
        self.end = end
    }

    var isActive: Bool { end == nil }
    var isValid: Bool { end == nil || end! > start }

    func overlapsOrTouches(_ other: VacationPeriod, tz: TimeZone) -> Bool {
        let aStart = start.startOfDay(in: tz)
        let aEnd = (end ?? .distantFuture).startOfDay(in: tz)
        let bStart = other.start.startOfDay(in: tz)
        let bEnd = (other.end ?? .distantFuture).startOfDay(in: tz)
        // [aStart, aEnd) touches/overlaps [bStart, bEnd) if aStart <= bEnd && bStart <= aEnd
        return aStart <= bEnd && bStart <= aEnd
    }

    func merged(with other: VacationPeriod, tz: TimeZone) -> VacationPeriod {
        VacationPeriod(
            id: id, // keep earliest id or generate new; either is fine
            start: min(start, other.start),
            end: max(end ?? .distantFuture, other.end ?? .distantFuture) == .distantFuture ? nil
                 : max(end ?? .distantFuture, other.end ?? .distantFuture)
        )
    }
}

// MARK: - Vacation Manager
final class VacationManager: ObservableObject {
    static let shared = VacationManager()
    
    @Published private(set) var current: VacationPeriod?
    @Published private(set) var history: [VacationPeriod] = []
    
    let tz: TimeZone
    
    // Computed properties for UI
    var isActive: Bool { current != nil }
    
    var activeVacationDuration: TimeInterval {
        guard let current = current else { return 0 }
        return Date().timeIntervalSince(current.start)
    }
    
    var totalVacationDays: Int {
        let allPeriods = history + (current.map { [$0] } ?? [])
        return allPeriods.reduce(0) { total, period in
            let end = period.end ?? Date()
            let days = Calendar.current.dateComponents([.day], from: period.start, to: end).day ?? 0
            return total + max(1, days) // At least 1 day
        }
    }

    private init(tz: TimeZone = .current) { 
        self.tz = tz
        loadVacationData()
        setupTimezoneChangeObserver()
    }

    // MARK: - Public Methods
    func startVacation(now: Date = .now, excludeToday: Bool = false) {
        let start = excludeToday ? now.addingTimeInterval(86400).startOfDay(in: tz) : now
        endVacationIfNeeded(now: now) // end dangling actives, then:
        current = VacationPeriod(start: start)
        muteNotifications()
        saveVacationData()
        print("🏖️ VACATION MODE DEBUG: Started vacation mode - isActive: \(isActive)")
    }

    func endVacation(now: Date = .now) {
        guard var cur = current else { return }
        cur.end = now
        current = nil
        appendAndCoalesce(cur)
        rescheduleNotifications()
        saveVacationData()
        print("🏖️ VACATION MODE DEBUG: Ended vacation mode - isActive: \(isActive)")
    }
    
    func cancelVacationForDate(_ date: Date) {
        let targetDate = date.startOfDay(in: tz)
        let today = Date().startOfDay(in: tz)
        
        print("🏖️ VACATION MODE DEBUG: cancelVacationForDate called for: \(targetDate)")
        print("🏖️ VACATION MODE DEBUG: Today is: \(today)")
        print("🏖️ VACATION MODE DEBUG: Current vacation active: \(isActive)")
        
        // If vacation is currently active, end it completely
        // This is the most user-friendly approach - when they click cancel, vacation ends now
        if isActive {
            endVacation(now: today)
            print("🏖️ VACATION MODE DEBUG: Ended vacation completely - vacation was active")
            return
        }
        
        // If no current vacation is active, just log it
        print("🏖️ VACATION MODE DEBUG: No active vacation to cancel")
    }

    func isVacationDay(_ day: Date) -> Bool {
        let d0 = day.startOfDay(in: tz)
        let d1 = day.endOfDay(in: tz)
        func contains(_ p: VacationPeriod) -> Bool {
            let s = p.start
            let e = p.end ?? .distantFuture
            return s <= d1 && e >= d0 // intersects day
        }
        
        let isCurrentVacationDay = current.map(contains) ?? false
        let isHistoricalVacationDay = history.contains(where: contains)
        let result = isCurrentVacationDay || isHistoricalVacationDay
        
        // Debug logging for vacation day detection
        let dateKey = ISO8601DateHelper.shared.string(from: day)
        if result {
            print("🏖️ VACATION DAY DEBUG: \(dateKey) is a vacation day - Current: \(isCurrentVacationDay), Historical: \(isHistoricalVacationDay)")
        }
        
        return result
    }
    
    // MARK: - Private Methods
    private func endVacationIfNeeded(now: Date) {
        guard var cur = current else { return }
        cur.end = now
        current = nil
        appendAndCoalesce(cur)
    }

    private func appendAndCoalesce(_ period: VacationPeriod) {
        var all = history
        all.append(period)
        history = coalesce(all)
    }

    private func coalesce(_ periods: [VacationPeriod]) -> [VacationPeriod] {
        let sorted = periods.sorted { $0.start < $1.start }
        var out: [VacationPeriod] = []
        for p in sorted {
            if let last = out.last, last.overlapsOrTouches(p, tz: tz) {
                _ = out.removeLast()
                out.append(last.merged(with: p, tz: tz))
            } else {
                out.append(p)
            }
        }
        return out
    }

    // MARK: - Notification Management
    private func muteNotifications() {
        print("🔇 Vacation Mode: Muting all habit notifications")
        NotificationManager.shared.removeAllPendingNotifications()
        print("✅ Vacation Mode: All notifications have been muted")
    }
    
    private func rescheduleNotifications() {
        print("🔔 Vacation Mode: Rescheduling all habit notifications")
        
        // Trigger notification rescheduling through the HabitRepository
        // This will be handled automatically when the app detects vacation mode has ended
        // and reloads habits, which will trigger notification rescheduling
        
        // For immediate rescheduling, we can also trigger it directly
        DispatchQueue.main.async {
            // Post notification to trigger habit reload and notification rescheduling
            NotificationCenter.default.post(name: .vacationModeEnded, object: nil)
        }
        
        print("✅ Vacation Mode: Notifications rescheduling triggered")
    }
    
    // MARK: - Data Persistence
    private func saveVacationData() {
        let data = VacationData(
            current: current,
            history: history
        )
        
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "VacationData")
        }
    }
    
    private func loadVacationData() {
        guard let data = UserDefaults.standard.data(forKey: "VacationData"),
              let vacationData = try? JSONDecoder().decode(VacationData.self, from: data) else {
            print("🏖️ VACATION MODE DEBUG: No vacation data found in UserDefaults")
            return
        }
        
        self.current = vacationData.current
        self.history = vacationData.history
        print("🏖️ VACATION MODE DEBUG: Loaded vacation data - isActive: \(isActive), History count: \(history.count)")
        if let current = current {
            print("🏖️ VACATION MODE DEBUG: Current vacation period: \(current.start) - \(current.end?.description ?? "ongoing")")
        }
    }
}

// MARK: - Data Persistence Model
struct VacationData: Codable {
    let current: VacationPeriod?
    let history: [VacationPeriod]
}

// MARK: - Date Extensions
extension Date {
    func startOfDay(in tz: TimeZone) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = tz
        return calendar.startOfDay(for: self)
    }
    
    func endOfDay(in tz: TimeZone) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = tz
        let startOfDay = calendar.startOfDay(for: self)
        return calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? self
    }
}

// MARK: - Vacation Mode Restrictions Extension
extension VacationManager {
    
    func canCreateHabits() -> Bool {
        return !isActive
    }
    
    func canEditHabits() -> Bool {
        return !isActive
    }
    
    func canScheduleReminders() -> Bool {
        return !isActive
    }
    
    func canExportData() -> Bool {
        return !isActive
    }
    
    func canModifySettings() -> Bool {
        return !isActive
    }
    
    func pauseAnalytics() {
        print("📊 VacationManager: Pausing analytics during vacation")
        // Analytics are already disabled in Firebase config
    }
    
    func pauseBackups() {
        print("💾 VacationManager: Pausing automatic backups during vacation")
        // Backup pausing would be implemented in the backup manager
    }
    
    func pauseCloudSync() {
        print("☁️ VacationManager: Pausing cloud sync during vacation")
        // Cloud sync is already disabled in the app
    }
    
    func pauseAchievements() {
        print("🏆 VacationManager: Pausing achievement tracking during vacation")
        // Achievement pausing would be implemented in the achievement manager
    }
    
    // MARK: - Timezone Change Handling
    private func setupTimezoneChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            print("🌍 VacationManager: Timezone changed, refreshing vacation data")
            // Vacation periods are stored in UTC, so timezone changes don't affect the data
            // But we should log this event for debugging
            self.debugVacationStatus()
        }
    }
    
    // MARK: - Debug Methods
    func debugVacationStatus() {
        print("🔍 VACATION DEBUG STATUS:")
        if let current = current {
            print("  - Current vacation: \(current.start) - \(current.end?.description ?? "ongoing")")
        } else {
            print("  - Current vacation: None")
        }
        print("  - History count: \(history.count)")
        for (index, period) in history.enumerated() {
            print("  - History[\(index)]: \(period.start) - \(period.end?.description ?? "ongoing")")
        }
        print("  - Is active: \(isActive)")
        print("  - Current timezone: \(tz.identifier)")
        print("  - Today is vacation day: \(isVacationDay(Date()))")
    }
    
    // MARK: - Debug Helper Methods
    func clearAllVacationData() {
        print("🏖️ VACATION MODE DEBUG: Clearing all vacation data")
        current = nil
        history = []
        saveVacationData()
        print("🏖️ VACATION MODE DEBUG: All vacation data cleared - isActive: \(isActive)")
    }
}
