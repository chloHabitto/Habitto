//
//  TimelineEntryRow.swift
//  Habitto
//
//  Individual timeline entry row showing a single progress event
//

import SwiftUI

struct TimelineEntryRow: View {
    let entry: DailyProgressEntry
    let habit: Habit
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time Column
            timeColumn
            
            // Connector
            connectorColumn
            
            // Entry Card
            entryCard
        }
    }
    
    // MARK: - Time Column
    
    private var timeColumn: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(entry.formattedTime)
                .font(.appLabelLargeEmphasised)
                .foregroundColor(.appText02)
            
            Text(entry.amPmString)
                .font(.appLabelSmall)
                .foregroundColor(.appText04)
            
            Image(systemName: entry.timePeriodIcon)
                .font(.system(size: 12))
                .foregroundColor(.appText04)
        }
        .frame(width: 45)
        .padding(.top, 16)
    }
    
    // MARK: - Connector Column
    
    private var connectorColumn: some View {
        VStack(spacing: 0) {
            // Dot
            Circle()
                .fill(Color.green)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 3)
                )
                .shadow(color: Color.green.opacity(0.3), radius: 2, y: 1)
                .padding(.top, 18)
            
            // Line below (if not last) - extends to connect with next dot
            if !isLast {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.appOutline02)
                        .frame(width: 2, height: max(28, geo.size.height))
                }
                .frame(width: 2)
                .frame(minHeight: 28) // Minimum height to extend through card padding (12pt) and connect
            }
        }
        .frame(width: 24)
    }
    
    // MARK: - Status Icon
    
    @ViewBuilder
    private var statusIcon: some View {
        if entry.runningTotal >= entry.goalAmount {
            // Goal completed - green checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.green))
        }
    }
    
    // MARK: - Entry Card
    
    private var entryCard: some View {
        HStack(alignment: .top, spacing: 12) {
            // Habit Icon
            HabitIconView(habit: habit)
                .frame(width: 40, height: 40)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Header row
                HStack {
                    Text(entry.deltaDisplayText)
                        .font(.appLabelLargeEmphasised)
                        .foregroundColor(.appText01)
                    
                    Spacer()
                    
                    // Status icon (checkmark/plus/minus based on entry type)
                    statusIcon
                }
                
                // Meta row with difficulty badge
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress: \(entry.runningTotal)/\(entry.goalAmount)")
                        .font(.appBodySmall)
                        .foregroundColor(.appText03)
                    
                    if let difficulty = entry.difficulty {
                        DifficultyBadge(difficulty: difficulty)
                    }
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.appSurface03)
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(habit.color.color)
                            .frame(width: geo.size.width * entry.progressPercentage, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appSurface4)
                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appOutline02, lineWidth: 1)
        )
        .padding(.top, 16)
        .padding(.bottom, isLast ? 0 : 12)
    }
}

// MARK: - Preview
// Preview removed - will be visible once integrated into ProgressTabView
