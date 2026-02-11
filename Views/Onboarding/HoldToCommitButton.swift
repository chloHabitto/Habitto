import SwiftUI

struct HoldToCommitButton: View {
  let onComplete: () -> Void
  @State private var isHolding = false
  @State private var holdProgress: CGFloat = 0
  @State private var holdTimer: Timer?
  @State private var lastHapticThreshold: CGFloat = 0

  private let holdDuration: CGFloat = 1.2
  private let buttonSize: CGFloat = 120
  private let buttonBorderColor = Color(red: 0.62, green: 0.73, blue: 0.95)
  private let buttonBackgroundColor = Color(red: 0.60, green: 0.72, blue: 0.96)

  var body: some View {
    VStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(buttonBackgroundColor.opacity(0.3 + holdProgress * 0.7))
          .frame(width: buttonSize, height: buttonSize)

        Circle()
          .stroke(buttonBorderColor.opacity(0.3), lineWidth: 4)
          .frame(width: buttonSize, height: buttonSize)

        Circle()
          .trim(from: 0, to: holdProgress)
          .stroke(buttonBorderColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
          .frame(width: buttonSize, height: buttonSize)
          .rotationEffect(.degrees(-90))

        Image("Finger-print")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 48, height: 48)
          .foregroundColor(.white.opacity(0.8))
      }
      .scaleEffect(isHolding ? 0.95 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHolding)
      .contentShape(Circle())

      Text(holdProgress >= 1.0 ? "Committed" : "Hold to commit")
        .font(.appBodyMedium)
        .foregroundColor(.white.opacity(0.7))
    }
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in
          if !isHolding {
            isHolding = true
            startHoldTimer()
          }
        }
        .onEnded { _ in
          isHolding = false
          holdTimer?.invalidate()
          holdTimer = nil
          lastHapticThreshold = 0
          if holdProgress < 1.0 {
            withAnimation(.easeOut(duration: 0.3)) {
              holdProgress = 0
            }
          }
        }
    )
    .accessibilityLabel(holdProgress >= 1.0 ? "Committed" : "Hold to commit")
    .accessibilityHint("Press and hold for \(String(format: "%.1f", holdDuration)) seconds to commit")
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

        let currentThreshold = (progress * 10).rounded(.down) / 10
        if currentThreshold > lastHapticThreshold && progress < 1.0 {
          lastHapticThreshold = currentThreshold
          let impact = UIImpactFeedbackGenerator(style: .light)
          impact.impactOccurred(intensity: CGFloat(0.4) + progress * CGFloat(0.6))
        }

        if progress >= 1.0 {
          t.invalidate()
          holdTimer = nil
          lastHapticThreshold = 0
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
