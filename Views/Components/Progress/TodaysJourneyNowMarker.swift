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
    HStack(alignment: .top, spacing: 8) {
      timeColumn
      spineColumn
      contentColumn
    }
    // No top padding - line above handles the connection
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
    .padding(.top, 16) // Align with dot (line above is 16pt)
  }

  // MARK: - Spine Column (24pt): pulsing dot + gradient line - two-segment approach

  private var spineColumn: some View {
    VStack(spacing: 0) {
      // Line ABOVE - solid primary, connects from previous completed item
      Rectangle()
        .fill(Color.appPrimary)
        .frame(width: 3, height: 16)
      
      // Pulsing dot
      nowDot
      
      // Line BELOW - gradient, connects to next pending item
      GeometryReader { geo in
        Rectangle()
          .fill(
            LinearGradient(
              colors: [Color.appPrimary, Color.appOutline02],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: 3, height: geo.size.height)
      }
      .frame(width: 3)
    }
    .frame(width: 24)
    .frame(maxHeight: .infinity, alignment: .top) // CRITICAL: Expand to fill row height
  }

  private var nowDot: some View {
    Circle()
      .fill(Color.appPrimary)
      .frame(width: 12, height: 12)
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
    HStack(spacing: 8) {
      Rectangle()
        .fill(
          LinearGradient(
            colors: [Color.appPrimary, Color.appOutline02],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .frame(height: 2)

      Text("NOW")
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(.appPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.appPrimaryContainer)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .padding(.top, 21) // Align with dot center: 16 (line above) + 6 (half of 12pt dot) - 1 (half of 2pt line)
  }
}

// MARK: - Preview

#Preview {
  TodaysJourneyNowMarker()
    .padding()
    .background(Color.appSurface01)
}
