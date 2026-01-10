//
//  MediumWidgetView.swift
//  HabittoWidget
//
//  Widget view for medium size (systemMedium)
//

import SwiftUI
import WidgetKit

// MARK: - Color Hex Extension (Widget Target)

extension Color {
    /// Initialize Color from hex string (e.g., "#FF5733" or "FF5733")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct MediumWidgetView: View {
    let entry: HabitWidgetEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side: Today's summary
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    Text("Today")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                Divider()
                
                // Stats
                let completedCount = entry.habits.filter { $0.isCompleted }.count
                let totalCount = entry.habits.count
                let completionRate = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(completedCount)/\(totalCount) Habits")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(Int(completionRate * 100))% Complete")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(completionRate))
                    }
                }
                .frame(height: 6)
                
                Spacer()
            }
            
            Divider()
            
            // Right side: Habit list
            VStack(alignment: .leading, spacing: 8) {
                Text("Habits")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                // Show up to 3 habits
                ForEach(Array(entry.habits.prefix(3))) { habit in
                    HabitRowView(habit: habit)
                }
                
                // Show count if more habits exist
                if entry.habits.count > 3 {
                    Text("+\(entry.habits.count - 3) more")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

// MARK: - Habit Row Component

struct HabitRowView: View {
    let habit: HabitItem
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: habit.icon)
                .foregroundColor(colorForName(habit.color))
                .font(.caption)
                .frame(width: 20)
            
            // Name
            Text(habit.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Spacer()
            
            // Completion indicator
            if habit.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption2)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary.opacity(0.3))
                    .font(.caption2)
            }
            
            // Streak
            HStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 8))
                Text("\(habit.streak)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Converts color string (hex or name) to SwiftUI Color
    /// Supports hex strings (e.g., "#FF5733") and fallback color names
    private func colorForName(_ colorString: String) -> Color {
        // Try to parse as hex string first (from real data)
        if colorString.hasPrefix("#") {
            return Color(hex: colorString)
        }
        
        // Fallback to named colors (for sample data)
        switch colorString.lowercased() {
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "pink": return .pink
        default: return .blue
        }
    }
}

// MARK: - Preview

#Preview("Medium Widget", as: .systemMedium) {
    HabittoWidget()
} timeline: {
    HabitWidgetEntry.placeholder
}
