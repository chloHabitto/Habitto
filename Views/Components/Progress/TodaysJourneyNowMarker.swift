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
    .padding(.bottom, 8) // Match item spacing
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

  // MARK: - Spine Column (24pt): pulsing dot + gradient line - simplified to match TodaysJourneyItemView

  private var spineColumn: some View {
    VStack(spacing: 0) {
      // Pulsing dot
      nowDot
        .padding(.top, 18)
      
      // Gradient line below
      Rectangle()
        .fill(
          LinearGradient(
            colors: [Color.appPrimary, Color.appOutline02],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(width: 3)
        .frame(maxHeight: .infinity) // Extend to fill available space
        .padding(.top, 4)
    }
    .frame(width: 24)
    .frame(maxHeight: .infinity, alignment: .top)
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
      // Horizontal gradient line
      Rectangle()
        .fill(
          LinearGradient(
            colors: [Color.appPrimary, Color.appOutline02],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .frame(height: 2)

      // NOW badge
      Text("NOW")
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(.appPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.appPrimaryContainer)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .padding(.top, 22) // Align horizontal line with center of dot (16 + 18/2 - 2/2 ≈ 22)
  }
}

// MARK: - Preview

#Preview {
  TodaysJourneyNowMarker()
    .padding()
    .background(Color.appSurface01)
}
