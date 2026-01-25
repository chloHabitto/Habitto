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
    .padding(.top, 6) // Align with dot (line above is 6pt)
  }

  // MARK: - Spine Column (24pt): pulsing dot + gradient line - fixed height approach

  private var spineColumn: some View {
    VStack(spacing: 0) {
      // Line ABOVE - solid primary, connects from previous completed item
      Rectangle()
        .fill(Color.appPrimaryOpacity10)
        .frame(width: 3, height: 6)
      
      // Pulsing dot
      nowDot
      
      // Line BELOW - gradient with FIXED height that extends past row
      // Using fixed 60pt ensures it overlaps with pending item's line-above
      Rectangle()
        .fill(Color.appPrimaryOpacity10)
        .frame(width: 3, height: 60)
    }
    .frame(width: 24, alignment: .top)
    // Note: Remove .frame(maxHeight: .infinity) - we don't need it anymore
  }

  private var nowDot: some View {
    Circle()
      .fill(Color.appPrimaryFocus)
      .frame(width: 12, height: 12)
      .shadow(
        color: Color.appPrimaryFocus.opacity(isPulsing ? 0.5 : 0),
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
        .fill(Color.appPrimaryOpacity10)
        .frame(height: 2)

      // NOW badge
      Text("progress.journey.now".localized)
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(.appPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.appPrimaryContainer)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .padding(.top, 11) // Align with dot center: 6 (line above) + 6 (half of 12pt dot) - 1 (half of 2pt line)
  }
}

// MARK: - Preview

#Preview {
  TodaysJourneyNowMarker()
    .padding()
    .background(Color.appSurface01)
}
