import SwiftUI

// MARK: - CompletionRingView

struct CompletionRingView: View {
  // MARK: Internal
  
  let progress: Double // 0.0 to 1.0
  let currentValue: Int
  let goalValue: Int
  let unit: String // e.g., "times", "min", "pages"
  let habitColor: Color
  let onTap: () -> Void
  
  var body: some View {
    Button(action: {
      onTap()
    }) {
      VStack(spacing: 12) {
        // Ring with center content
        ZStack {
          // Background ring
          Circle()
            .stroke(habitColor.opacity(0.15), lineWidth: 10)
            .frame(width: 120, height: 120)
          
          // Progress ring
          Circle()
            .trim(from: 0, to: min(progress, 1.0))
            .stroke(
              habitColor,
              style: StrokeStyle(lineWidth: 10, lineCap: .round)
            )
            .frame(width: 120, height: 120)
            .rotationEffect(.degrees(-90))
            .animation(.easeInOut(duration: 0.3), value: progress)
          
          // Center content
          VStack(spacing: 4) {
            if isCompleted {
              Image(systemName: "checkmark")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(habitColor)
            } else {
              Text(valueText)
                .font(.appTitleLargeEmphasised)
                .foregroundColor(.text01)
              
              Text(unit)
                .font(.appBodySmall)
                .foregroundColor(.text05)
            }
          }
        }
        .contentShape(Circle())
        
        // Label below ring
        Text(isCompleted ? "Completed ✓" : "Tap to log")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
    }
    .buttonStyle(ScaleButtonStyle())
  }
  
  // MARK: Private
  
  private var isCompleted: Bool {
    currentValue >= goalValue && goalValue > 0
  }
  
  private var valueText: String {
    "\(currentValue)/\(goalValue)"
  }
}

// MARK: - ScaleButtonStyle

private struct ScaleButtonStyle: SwiftUI.ButtonStyle {
  func makeBody(configuration: SwiftUI.ButtonStyleConfiguration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
      .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 40) {
    // Incomplete state
    CompletionRingView(
      progress: 0.67,
      currentValue: 2,
      goalValue: 3,
      unit: "times",
      habitColor: .blue,
      onTap: { print("Tapped") }
    )
    
    // Complete state
    CompletionRingView(
      progress: 1.0,
      currentValue: 30,
      goalValue: 30,
      unit: "min",
      habitColor: .green,
      onTap: { print("Tapped") }
    )
  }
  .padding()
  .background(Color.appSurface01Variant)
}
