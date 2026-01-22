//
//  TodaysJourneyNowMarker.swift
//  Habitto
//
//  "NOW" marker for Today's Journey timeline – current time, pulsing dot, gradient lines.
//

import SwiftUI

struct TodaysJourneyNowMarker: View {
  @State private var isPulsing = false

  private static let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm"
    return f
  }()

  private static let amPmFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "a"
    return f
  }()

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      timeColumn
      spineColumn
      contentColumn
    }
  }

  // MARK: - Time Column (45pt, right-aligned, primary styling) - matches TimelineEntryRow

  private var timeColumn: some View {
    VStack(alignment: .trailing, spacing: 2) {
      Text(Self.timeFormatter.string(from: Date()))
        .font(.appLabelSmall)
        .foregroundColor(.appPrimary)
      Text(Self.amPmFormatter.string(from: Date()))
        .font(.appLabelSmall)
        .foregroundColor(.appPrimary)
    }
    .frame(width: 45, alignment: .trailing)
    .padding(.top, 16)
  }

  // MARK: - Spine Column (24pt): lines + pulsing dot - matches TodaysJourneyItemView

  private var spineColumn: some View {
    VStack(spacing: 0) {
      // Line above NOW – solid primary (extends to connect with previous item)
      // This connects to the line below the previous completed item
      spineLineAbove
      
      // Pulsing NOW dot (aligned with timeline nodes at same vertical position)
      nowDot
        .padding(.top, 18) // Match TimelineEntryRow dot positioning
      
      // Line below NOW – gradient primary → outline02 (extends to connect with next item)
      // This connects to the line above the next pending item
      spineLineBelow
    }
    .frame(width: 24)
  }
  
  private var spineLineAbove: some View {
    GeometryReader { geo in
      let h = max(24, geo.size.height)
      Rectangle()
        .fill(Color.appPrimary)
        .frame(width: 3, height: h)
    }
    .frame(width: 3)
    .frame(minHeight: 24) // Extend through card bottom padding (8pt) + spacing
  }
  
  private var spineLineBelow: some View {
    GeometryReader { geo in
      let h = max(24, geo.size.height)
      Rectangle()
        .fill(
          LinearGradient(
            colors: [Color.appPrimary, Color.appOutline02],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(width: 3, height: h)
    }
    .frame(width: 3)
    .frame(minHeight: 24) // Extend through card bottom padding (8pt) + spacing
  }

  private var nowDot: some View {
    Circle()
      .fill(Color.appPrimary)
      .frame(width: 14, height: 14) // Match TodaysJourneyItemView timeline node size
      .shadow(
        color: Color.appPrimary.opacity(isPulsing ? 0.5 : 0),
        radius: isPulsing ? 8 : 0
      )
      .onAppear {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
          isPulsing = true
        }
      }
  }

  // MARK: - Content Column: horizontal gradient line + NOW badge

  private var contentColumn: some View {
    HStack(spacing: 0) {
      // Horizontal gradient line
      Rectangle()
        .fill(
          LinearGradient(
            colors: [Color.appPrimary, Color.appOutline02],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .frame(height: 3)

      // NOW badge
      Text("NOW")
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(.appPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.appPrimaryContainer)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .padding(.top, 16) // Match TimelineEntryRow entryCard top padding
    .padding(.bottom, 12) // Match TimelineEntryRow entryCard bottom padding
  }
}

// MARK: - Preview

#Preview {
  TodaysJourneyNowMarker()
    .padding()
    .background(Color.appSurface01)
}
