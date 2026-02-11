import SwiftUI

// MARK: - HoldToCommitButton

struct HoldToCommitButton: View {
  let onComplete: () -> Void
  @State private var isHolding = false
  @State private var holdProgress: CGFloat = 0
  @State private var holdTimer: Timer?
  @State private var holdStartTime: Date?

  private let holdDuration: CGFloat = 2.0

  private let buttonBorderColor = Color(red: 0.62, green: 0.73, blue: 0.95)
  private let buttonBackgroundColor = Color(red: 0.6, green: 0.72, blue: 0.96)

  var body: some View {
    VStack(alignment: .center, spacing: 0) {
      // Oval container with fingerprint — scale and opacity respond to hold progress
      VStack(alignment: .center, spacing: 0) {
        Image("Finger-print")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 54, height: 54)
          .foregroundColor(.white.opacity(0.1 + holdProgress * 0.5))
      }
      .padding(.horizontal, 18.5)
      .padding(.vertical, 30)
      .frame(width: 91, height: 114, alignment: .center)
      .background(buttonBackgroundColor.opacity(0.1 + holdProgress * 0.15))
      .cornerRadius(57)
      .overlay(
        // Base border (full oval)
        RoundedRectangle(cornerRadius: 57)
          .inset(by: 2.5)
          .stroke(buttonBorderColor.opacity(0.4), lineWidth: 5)
      )
      .overlay(
        // Progress border (fills clockwise as user holds)
        RoundedRectangle(cornerRadius: 57)
          .inset(by: 2.5)
          .trim(from: 0, to: holdProgress)
          .stroke(buttonBorderColor, lineWidth: 5)
          .rotationEffect(.degrees(-90)) // start from top
      )
      .scaleEffect(1.0 + holdProgress * 0.1)
      .contentShape(RoundedRectangle(cornerRadius: 57))

      Text("Hold to commit")
        .font(.appHeadlineSmallEmphasised)
        .foregroundColor(.white)
        .padding(.top, 16)
    }
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in
          if !isHolding {
            isHolding = true
            holdStartTime = Date()
            startHoldTimer()
          }
        }
        .onEnded { _ in
          isHolding = false
          holdTimer?.invalidate()
          holdTimer = nil
          if holdProgress < 1.0 {
            withAnimation(.easeOut(duration: 0.3)) {
              holdProgress = 0
            }
          }
        }
    )
    .accessibilityLabel(holdProgress >= 1.0 ? "Committed" : "Hold to commit")
    .accessibilityHint("Press and hold for 2 seconds to commit")
  }

  private func startHoldTimer() {
    holdTimer?.invalidate()
    let start = Date()
    let timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { t in
      guard isHolding else {
        t.invalidate()
        DispatchQueue.main.async { holdTimer = nil }
        return
      }
      let elapsed = Date().timeIntervalSince(start)
      let progress = min(CGFloat(elapsed) / holdDuration, 1.0)
      DispatchQueue.main.async {
        withAnimation(.linear(duration: 0.02)) {
          holdProgress = progress
        }
        if progress >= 1.0 {
          t.invalidate()
          holdTimer = nil
          let generator = UINotificationFeedbackGenerator()
          generator.notificationOccurred(.success)
          onComplete()
        }
      }
    }
    timer.tolerance = 0.01
    RunLoop.main.add(timer, forMode: .common)
    holdTimer = timer
  }
}
