//
//  SmallWidgetView.swift
//  HabittoWidget
//
//  Widget view for small size (systemSmall)
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

struct SmallWidgetView: View {
    let entry: HabitWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                
                Text("Today")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Divider()
            
            // Primary habit (most important or first incomplete)
            if let primaryHabit = getPrimaryHabit() {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: primaryHabit.icon)
                            .foregroundColor(colorForName(primaryHabit.color))
                            .font(.caption)
                        
                        Text(primaryHabit.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Completion indicator
                        if primaryHabit.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    
                    // Streak info
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 10))
                        Text("\(primaryHabit.streak)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Stats summary
            let completedCount = entry.habits.filter { $0.isCompleted }.count
            let totalCount = entry.habits.count
            
            HStack {
                Text("\(completedCount)/\(totalCount) done")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    /// Gets the primary habit to display (first incomplete, or first if all complete)
    private func getPrimaryHabit() -> HabitItem? {
        // Show first incomplete habit, or first habit if all are complete
        if let incomplete = entry.habits.first(where: { !$0.isCompleted }) {
            return incomplete
        }
        return entry.habits.first
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

#Preview("Small Widget", as: .systemSmall) {
    HabittoWidget()
} timeline: {
    HabitWidgetEntry.placeholder
    HabitWidgetEntry(
        date: Date(),
        habits: [
            HabitItem(
                id: UUID(),
                name: "Morning Meditation",
                icon: "leaf.fill",
                color: "green",
                isCompleted: true,
                streak: 7,
                goal: "1 time per day"
            )
        ]
    )
}
