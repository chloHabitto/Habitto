import Foundation
import SwiftUI

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
    }

    // MARK: - Public Methods
    func startVacation(now: Date = .now, excludeToday: Bool = false) {
        let start = excludeToday ? now.addingTimeInterval(86400).startOfDay(in: tz) : now
        endVacationIfNeeded(now: now) // end dangling actives, then:
        current = VacationPeriod(start: start)
        muteNotifications()
        saveVacationData()
    }

    func endVacation(now: Date = .now) {
        guard var cur = current else { return }
        cur.end = now
        current = nil
        appendAndCoalesce(cur)
        rescheduleNotifications()
        saveVacationData()
    }

    func isVacationDay(_ day: Date) -> Bool {
        let d0 = day.startOfDay(in: tz)
        let d1 = day.endOfDay(in: tz)
        func contains(_ p: VacationPeriod) -> Bool {
            let s = p.start
            let e = p.end ?? .distantFuture
            return s <= d1 && e >= d0 // intersects day
        }
        return (current.map(contains) ?? false) || history.contains(where: contains)
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

    // MARK: - Notification Management (stubs for now)
    private func muteNotifications() {
        // TODO: Implement notification muting
        print("Vacation Mode: Muting all habit notifications")
    }
    
    private func rescheduleNotifications() {
        // TODO: Implement notification rescheduling
        print("Vacation Mode: Rescheduling all habit notifications")
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
            return
        }
        
        self.current = vacationData.current
        self.history = vacationData.history
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
