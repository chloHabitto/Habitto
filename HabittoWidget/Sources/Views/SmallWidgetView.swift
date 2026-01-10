//
//  SmallWidgetView.swift
//  HabittoWidget
//
//  Widget view for small size (systemSmall)
//

import SwiftUI
import WidgetKit

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
    
    /// Maps color name to SwiftUI Color
    /// TODO: Replace with design system colors when App Groups are set up
    private func colorForName(_ name: String) -> Color {
        switch name.lowercased() {
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
