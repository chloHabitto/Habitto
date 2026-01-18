import SwiftUI

// MARK: - QuickStatsRow

struct QuickStatsRow: View {
  // MARK: Internal
  
  let currentStreak: Int
  let isScheduledToday: Bool
  let isCompletedToday: Bool
  let nextScheduledDate: Date?
  let habitColor: Color
  
  var body: some View {
    HStack(spacing: 16) {
      // Left: Streak
      HStack(spacing: 6) {
        Image("Icon-Fire_Outlined")
          .resizable()
          .renderingMode(.template)
          .frame(width: 16, height: 16)
          .foregroundColor(.orange)
        
        Text("\(currentStreak) \(currentStreak == 1 ? "day" : "days")")
          .font(.appBodySmallEmphasised)
          .foregroundColor(.text03)
      }
      
      Spacer()
      
      // Right: Next Due Status
      HStack(spacing: 6) {
        if isScheduledToday && isCompletedToday {
          Image(systemName: "checkmark")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(habitColor)
        } else {
          Image("Icon-CalendarMark_Outlined")
            .resizable()
            .renderingMode(.template)
            .frame(width: 16, height: 16)
            .foregroundColor(nextDueIconColor)
        }
        
        Text(nextDueText)
          .font(.appBodySmallEmphasised)
          .foregroundColor(nextDueColor)
      }
    }
    .frame(maxWidth: .infinity)
  }
  
  // MARK: Private
  
  private var nextDueText: String {
    if isScheduledToday {
      return isCompletedToday ? "Done today" : "Due today"
    }
    
    guard let nextDate = nextScheduledDate else {
      return "Not scheduled"
    }
    
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let next = calendar.startOfDay(for: nextDate)
    let daysDiff = calendar.dateComponents([.day], from: today, to: next).day ?? 0
    
    if daysDiff == 1 {
      return "Next: Tomorrow"
    } else if daysDiff <= 7 {
      let formatter = DateFormatter()
      formatter.dateFormat = "EEEE" // "Wednesday"
      return "Next: \(formatter.string(from: nextDate))"
    } else {
      let formatter = DateFormatter()
      formatter.dateFormat = "MMM d" // "Jan 25"
      return "Next: \(formatter.string(from: nextDate))"
    }
  }
  
  private var nextDueIconColor: Color {
    if !isScheduledToday && nextScheduledDate == nil {
      return .text05
    } else {
      return .text03
    }
  }
  
  private var nextDueColor: Color {
    if isScheduledToday && isCompletedToday {
      return habitColor
    } else if !isScheduledToday && nextScheduledDate == nil {
      return .text05
    } else {
      return .text03
    }
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 20) {
    // Due today
    QuickStatsRow(
      currentStreak: 12,
      isScheduledToday: true,
      isCompletedToday: false,
      nextScheduledDate: nil,
      habitColor: .blue
    )
    
    // Done today
    QuickStatsRow(
      currentStreak: 12,
      isScheduledToday: true,
      isCompletedToday: true,
      nextScheduledDate: nil,
      habitColor: .green
    )
    
    // Next tomorrow
    QuickStatsRow(
      currentStreak: 5,
      isScheduledToday: false,
      isCompletedToday: false,
      nextScheduledDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
      habitColor: .blue
    )
    
    // Next Wednesday
    QuickStatsRow(
      currentStreak: 5,
      isScheduledToday: false,
      isCompletedToday: false,
      nextScheduledDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
      habitColor: .blue
    )
    
    // Not scheduled
    QuickStatsRow(
      currentStreak: 0,
      isScheduledToday: false,
      isCompletedToday: false,
      nextScheduledDate: nil,
      habitColor: .gray
    )
  }
  .padding()
  .background(Color.appSurface01Variant)
}
