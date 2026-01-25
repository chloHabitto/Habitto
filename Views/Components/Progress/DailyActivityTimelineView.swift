//
//  DailyActivityTimelineView.swift
//  Habitto
//
//  Main container for the daily activity timeline feature
//  Shows chronological progress entries for a habit on a specific day
//

import SwiftUI

struct DailyActivityTimelineView: View {
    let habit: Habit
    let selectedDate: Date
    let entries: [DailyProgressEntry]
    let streak: Int
    
    private var currentProgress: Int {
        entries.last?.runningTotal ?? 0
    }
    
    private var goalAmount: Int {
        habit.goalAmount(for: selectedDate)
    }
    
    private var isGoalComplete: Bool {
        currentProgress >= goalAmount
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            timelineHeader
            
            // Content
            if entries.isEmpty {
                emptyState
            } else {
                timelineContent
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
        .padding(.leading, 12)
        .padding(.trailing, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appSurface02)
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
    
    // MARK: - Header
    
    private var timelineHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("progress.journey.todaysActivity".localized)
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.appText02)
            
            Text("progress.journey.progressToday".localized)
                .font(.appBodySmall)
                .foregroundColor(.appText04)
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Timeline Content
    
    private var timelineContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                TimelineEntryRow(
                    entry: entry,
                    habit: habit,
                    index: index,
                    isFirst: index == 0,
                    isLast: index == entries.count - 1 && isGoalComplete
                )
            }
            
            if !isGoalComplete {
                NextActionRow(remainingCount: goalAmount - currentProgress)
            } else {
                GoalCompleteCelebration(streak: streak)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Text("☀️")
                .font(.system(size: 48))
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.15), Color.orange.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            VStack(spacing: 8) {
                Text("progress.journey.yourDayBeginning".localized)
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.appText01)
                
                Text("progress.journey.completeFromHomeToStart".localized)
                    .font(.appBodyMedium)
                    .foregroundColor(.appText03)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Preview
// Preview removed - will be visible once integrated into ProgressTabView
