import SwiftUI

// MARK: - QuickStatsRow

struct QuickStatsRow: View {
  // MARK: Internal
  
  let currentStreak: Int
  let schedule: String
  
  var body: some View {
    HStack(spacing: 16) {
      // Left: Streak
      HStack(spacing: 6) {
        Text("🔥")
          .font(.system(size: 16))
        
        Text("\(currentStreak) \(currentStreak == 1 ? "day" : "days")")
          .font(.appBodySmallEmphasised)
          .foregroundColor(.text03)
      }
      
      Spacer()
      
      // Right: Schedule
      HStack(spacing: 6) {
        Text("📅")
          .font(.system(size: 16))
        
        Text(formattedSchedule)
          .font(.appBodySmallEmphasised)
          .foregroundColor(.text03)
      }
    }
    .frame(maxWidth: .infinity)
  }
  
  // MARK: Private
  
  private var formattedSchedule: String {
    let lowerSchedule = schedule.lowercased()
    
    // Handle common schedule formats and shorten for display
    if lowerSchedule.contains("everyday") || lowerSchedule == "daily" {
      return "Daily"
    }
    
    if lowerSchedule.contains("once a week") {
      return "Weekly"
    }
    
    if lowerSchedule.contains("twice a week") {
      return "2x/week"
    }
    
    if lowerSchedule.contains("once a month") {
      return "Monthly"
    }
    
    // Extract day count patterns like "3 days a week" or "5 days a month"
    if let regex = try? NSRegularExpression(pattern: #"(\d+)\s*days?\s*a\s*(week|month)"#, options: .caseInsensitive),
       let match = regex.firstMatch(in: schedule, options: [], range: NSRange(location: 0, length: schedule.count)) {
      let numberRange = match.range(at: 1)
      let periodRange = match.range(at: 2)
      
      if let numRange = Range(numberRange, in: schedule),
         let perRange = Range(periodRange, in: schedule) {
        let number = String(schedule[numRange])
        let period = String(schedule[perRange])
        
        if period.lowercased() == "week" {
          return "\(number)x/week"
        } else {
          return "\(number)x/month"
        }
      }
    }
    
    // Handle specific weekdays - show first day if multiple
    let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    for (index, weekday) in weekdays.enumerated() {
      if lowerSchedule.contains(weekday) {
        // Check if there are multiple days (contains comma)
        if lowerSchedule.contains(",") {
          // Count how many days
          let dayCount = weekdays.filter { lowerSchedule.contains($0) }.count
          if dayCount > 1 {
            return "\(dayCount) days/week"
          }
        }
        return dayNames[index]
      }
    }
    
    // Fallback: return truncated original schedule
    if schedule.count > 20 {
      return String(schedule.prefix(17)) + "..."
    }
    
    return schedule
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 24) {
    QuickStatsRow(
      currentStreak: 12,
      schedule: "everyday"
    )
    
    QuickStatsRow(
      currentStreak: 5,
      schedule: "3 days a week"
    )
    
    QuickStatsRow(
      currentStreak: 1,
      schedule: "every Monday, Wednesday & Friday"
    )
    
    QuickStatsRow(
      currentStreak: 0,
      schedule: "once a month"
    )
  }
  .padding()
  .background(Color.appSurface01Variant)
  .cornerRadius(16)
  .padding()
}
