import SwiftUI

/// 🔍 Live debug overlay showing XP calculation inputs and output
/// Mount this in both Home and More tabs to verify XP stays consistent
///
/// Note: Uses simplified schedule filtering (date range only) for performance.
/// May show slightly different counts than main logic for complex schedules,
/// but should be accurate enough for debugging XP duplication issues.
struct XPDebugBadge: View {
  @EnvironmentObject var habitRepository: HabitRepository
  
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("🔍 XP Debug")
        .font(.caption2.bold())
      
      Divider()
      
      Text("todayKey: \(Habit.dateKey(for: Date()))")
        .font(.caption2.monospaced())
      
      Text("completedDays: \(completedDaysCount())")
        .font(.caption2.monospaced())
      
      Text("totalXP: \(XPManager.shared.userProgress.totalXP)")
        .font(.caption2.monospaced())
      
      Text("expected: \(completedDaysCount() * 50)")
        .font(.caption2.monospaced())
        .foregroundColor(
          XPManager.shared.userProgress.totalXP == completedDaysCount() * 50
            ? .green
            : .red
        )
    }
    .font(.caption2)
    .padding(8)
    .background(.ultraThinMaterial)
    .cornerRadius(8)
    .shadow(radius: 2)
  }
  
  /// Calculate completed days count (same logic as HomeTabView)
  private func completedDaysCount() -> Int {
    guard AuthenticationManager.shared.currentUser?.uid != nil else { return 0 }
    
    let habits = habitRepository.habits
    guard !habits.isEmpty else { return 0 }
    
    let calendar = Calendar.current
    let today = DateUtils.today()
    
    guard let earliestStartDate = habits.map({ $0.startDate }).min() else { return 0 }
    let startDate = DateUtils.startOfDay(for: earliestStartDate)
    
    var completedCount = 0
    var currentDate = startDate
    
    while currentDate <= today {
      let habitsForDate = habits.filter { habit in
        let selected = DateUtils.startOfDay(for: currentDate)
        let start = DateUtils.startOfDay(for: habit.startDate)
        let end = habit.endDate.map { DateUtils.startOfDay(for: $0) } ?? Date.distantFuture
        
        // Only check date range (schedule filtering is complex and handled in main logic)
        return selected >= start && selected <= end
      }
      
      // For debug purposes, check if habits exist and all are completed
      // Note: This may differ slightly from main logic due to complex schedule rules
      let allCompleted = !habitsForDate.isEmpty && habitsForDate.allSatisfy { $0.isCompleted(for: currentDate) }
      
      if allCompleted {
        completedCount += 1
      }
      
      guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
      currentDate = nextDate
    }
    
    return completedCount
  }
}

