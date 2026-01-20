//
//  DailyActivityStatsCard.swift
//  Habitto
//
//  Stats header card displaying habit info and daily statistics
//  Shows above the daily activity timeline
//

import SwiftUI

struct DailyActivityStatsCard: View {
    let habit: Habit
    let entries: [DailyProgressEntry]
    let selectedDate: Date
    
    private var currentProgress: Int {
        entries.last?.runningTotal ?? 0
    }
    
    private var goalAmount: Int {
        habit.goalAmount(for: selectedDate)
    }
    
    private var streak: Int {
        habit.calculateTrueStreak()
    }
    
    private var averageDifficulty: String {
        let difficulties = entries.compactMap { $0.difficulty }
        guard !difficulties.isEmpty else { return "—" }
        
        let average = Double(difficulties.reduce(0, +)) / Double(difficulties.count)
        let roundedAverage = Int(round(average))
        
        switch roundedAverage {
        case 1: return "😊"
        case 2: return "🙂"
        case 3: return "😐"
        case 4: return "😓"
        case 5: return "🥵"
        default: return "😐"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Habit Header Row
            habitHeader
            
            // Stats Grid
            statsGrid
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appSurface01)
                .overlay(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: .white.opacity(0.07), location: 0.00),
                            Gradient.Stop(color: .white.opacity(0.03), location: 1.00),
                        ],
                        startPoint: UnitPoint(x: 0.08, y: 0.09),
                        endPoint: UnitPoint(x: 0.88, y: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.appOutline1Variant, lineWidth: 2)
        )
    }
    
    // MARK: - Habit Header
    
    private var habitHeader: some View {
        HStack(spacing: 12) {
            // Habit Icon
            HabitIconView(habit: habit)
            
            VStack(alignment: .leading, spacing: 4) {
                // Habit Name
                Text(habit.name)
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.appText01)
                
                // Streak Badge
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 12))
                    Text("\(streak) day streak")
                        .font(.appLabelSmall)
                        .foregroundColor(.appText03)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        HStack(spacing: 0) {
            // Progress
            statColumn(
                title: "Progress",
                value: "\(currentProgress)/\(goalAmount)"
            )
            
            Divider()
                .frame(height: 40)
                .background(Color.appOutline1Variant)
            
            // Sessions
            statColumn(
                title: "Sessions",
                value: "\(entries.count)"
            )
            
            Divider()
                .frame(height: 40)
                .background(Color.appOutline1Variant)
            
            // Avg. Effort
            statColumn(
                title: "Avg. Effort",
                value: averageDifficulty
            )
        }
    }
    
    // MARK: - Helper Views
    
    private func statColumn(title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.appLabelSmall)
                .foregroundColor(.appText04)
            
            Text(value)
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.appText01)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // With entries
        DailyActivityStatsCard(
            habit: Habit(
                name: "Meditation",
                description: "Daily meditation practice",
                icon: "🧘‍♂️",
                color: .purple,
                habitType: .formation,
                schedule: "Daily",
                goal: "5 sessions",
                reminder: "No reminder",
                startDate: Date(),
                endDate: nil
            ),
            entries: [
                DailyProgressEntry(
                    id: UUID(),
                    timestamp: Date().addingTimeInterval(-3600 * 4),
                    progressDelta: 1,
                    runningTotal: 1,
                    goalAmount: 5,
                    difficulty: 2,
                    eventType: "INCREMENT"
                ),
                DailyProgressEntry(
                    id: UUID(),
                    timestamp: Date().addingTimeInterval(-3600 * 2),
                    progressDelta: 1,
                    runningTotal: 2,
                    goalAmount: 5,
                    difficulty: 3,
                    eventType: "INCREMENT"
                ),
                DailyProgressEntry(
                    id: UUID(),
                    timestamp: Date().addingTimeInterval(-3600),
                    progressDelta: 1,
                    runningTotal: 3,
                    goalAmount: 5,
                    difficulty: 4,
                    eventType: "INCREMENT"
                )
            ],
            selectedDate: Date()
        )
        
        // Empty state (no entries)
        DailyActivityStatsCard(
            habit: Habit(
                name: "Reading",
                description: "Read daily",
                icon: "📚",
                color: .blue,
                habitType: .formation,
                schedule: "Daily",
                goal: "20 pages",
                reminder: "No reminder",
                startDate: Date(),
                endDate: nil
            ),
            entries: [],
            selectedDate: Date()
        )
    }
    .padding()
    .background(Color.appSurface01Variant02)
}
