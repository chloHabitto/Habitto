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
    // Remove .padding(.bottom, 16) - it creates empty space, not gradient extension
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

  // MARK: - Spine Column (24pt): pulsing dot + gradient line - fixed height approach

  private var spineColumn: some View {
    VStack(spacing: 0) {
      // Line ABOVE - solid primary, connects from previous completed item
      Rectangle()
        .fill(Color.appPrimary)
        .frame(width: 3, height: 16)
      
      // Pulsing dot
      nowDot
      
      // Line BELOW - gradient with FIXED height that extends past row
      // Using fixed 100pt ensures it overlaps with pending item's line-above
      Rectangle()
        .fill(
          LinearGradient(
            colors: [Color.appPrimary, Color.appOutline02],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(width: 3, height: 100)
    }
    .frame(width: 24, alignment: .top)
    // Note: Remove .frame(maxHeight: .infinity) - we don't need it anymore
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
    .padding(.top, 21) // Align with dot center
  }
}

// MARK: - Preview

#Preview {
  TodaysJourneyNowMarker()
    .padding()
    .background(Color.appSurface01)
}
