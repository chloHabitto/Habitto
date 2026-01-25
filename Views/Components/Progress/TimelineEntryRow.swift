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
    let index: Int
    let isFirst: Bool
    let isLast: Bool
    
    @State private var hasAppeared = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Time Column
            timeColumn
            
            // Spine Column
            spineColumn
            
            // Entry Card
            entryCard
        }
        .padding(.top, isFirst ? 16 : 0)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05),
            value: hasAppeared
        )
        .onAppear { hasAppeared = true }
    }
    
    // MARK: - Time Column
    
    private var timeColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(entry.formattedTime)
                .font(.appLabelSmall)
                .foregroundColor(.appText02)
            
            Text(entry.amPmString)
                .font(.appLabelSmall)
                .foregroundColor(.appText04)
        }
        .frame(width: 45, alignment: .trailing)
        .padding(.top, isFirst ? 0 : 16)
    }
    
    // MARK: - Spine Column
    
    private var spineColumn: some View {
        VStack(spacing: 0) {
            // Line ABOVE the dot - connects to previous item
            if !isFirst {
                lineSegment(position: .above)
                    .frame(height: 16)
            }
            
            // The dot
            timelineNode
            
            // Line BELOW the dot - connects to next item
            if !isLast {
                lineSegment(position: .below)
            }
        }
        .frame(width: 24)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private enum LinePosition {
        case above, below
    }
    
    private func lineSegment(position: LinePosition) -> some View {
        let lineColor = Color.appPrimaryOpacity10
        
        return GeometryReader { geo in
            Rectangle()
                .fill(lineColor)
                .frame(width: 3, height: geo.size.height)
        }
        .frame(width: 3)
    }
    
    private var timelineNode: some View {
        Circle()
            .fill(Color.appPrimaryContainerFocus)
            .frame(width: 12, height: 12)
            .shadow(
                color: Color.appPrimaryContainerFocus.opacity(0.3),
                radius: 2,
                y: 1
            )
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
        HStack(alignment: .top, spacing: 16) {
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.deltaDisplayText)
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.appText02)
                    
                    Text(String(format: "progress.journey.progressLabel".localized, entry.runningTotal, entry.goalAmount))
                        .font(.appLabelSmall)
                        .foregroundColor(.appText05)
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.appOutline02)
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(habit.color.color)
                            .frame(width: geo.size.width * entry.progressPercentage, height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            Spacer()
            
            // Status icon (checkmark)
            statusIcon
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appSurface01Variant)
                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appOutline02, lineWidth: 1)
        )
        .padding(.top, isFirst ? 0 : 16)
    }
}

// MARK: - Preview
// Preview removed - will be visible once integrated into ProgressTabView
