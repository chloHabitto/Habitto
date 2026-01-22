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
    HStack(alignment: .top, spacing: 0) {
      timeColumn
      spineColumn
      contentColumn
    }
  }

  // MARK: - Time Column (44pt, right-aligned, primary styling)

  private var timeColumn: some View {
    VStack(alignment: .trailing, spacing: 2) {
      Text(Self.timeFormatter.string(from: Date()))
        .font(.appLabelSmall)
        .foregroundColor(.appPrimary)
      Text(Self.amPmFormatter.string(from: Date()))
        .font(.appLabelSmall)
        .foregroundColor(.appPrimary)
    }
    .frame(width: 44, alignment: .trailing)
    .padding(.top, 14)
  }

  // MARK: - Spine Column (28pt): lines + pulsing dot

  private var spineColumn: some View {
    VStack(spacing: 0) {
      // Line above NOW – solid primary
      Rectangle()
        .fill(Color.appPrimary)
        .frame(width: 3)
        .frame(minHeight: 18)

      // Pulsing NOW dot
      nowDot
        .padding(.vertical, 0)

      // Line below NOW – gradient primary → outline02 (flexible height)
      Rectangle()
        .fill(
          LinearGradient(
            colors: [Color.appPrimary, Color.appOutline02],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(width: 3)
        .frame(minHeight: 18)
    }
    .frame(width: 28)
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
    .padding(.leading, 8)
    .padding(.top, 8)
    .padding(.bottom, 8)
  }
}

// MARK: - Preview

#Preview {
  TodaysJourneyNowMarker()
    .padding()
    .background(Color.appSurface01)
}
