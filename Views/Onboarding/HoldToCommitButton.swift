import SwiftUI

// MARK: - HoldToCommitButton

struct HoldToCommitButton: View {
  let onComplete: () -> Void
  @State private var isHolding = false
  @State private var holdProgress: CGFloat = 0
  @State private var holdTimer: Timer?
  @State private var holdStartTime: Date?

  private let holdDuration: CGFloat = 2.0

  var body: some View {
    ZStack(alignment: .leading) {
      Capsule()
        .fill(Color.white.opacity(0.15))
        .frame(height: 56)

      Capsule()
        .fill(Color("appPrimary"))
        .frame(width: nil, height: 56)
        .frame(maxWidth: .infinity)
        .scaleEffect(x: holdProgress, y: 1, anchor: .leading)
        .clipShape(Capsule())
    }
    .frame(height: 56)
    .clipShape(Capsule())
    .overlay {
      Text(holdProgress >= 1.0 ? "Committed! ✓" : "Hold to commit")
        .font(.appButtonText1)
        .foregroundColor(.white)
    }
    .contentShape(Capsule())
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
    .padding(.horizontal, 20)
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
