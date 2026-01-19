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
  let isSkipped: Bool
  let onSkip: (() -> Void)?
  
  var body: some View {
    VStack(spacing: 12) {
      if isSkipped {
        // Skipped state
        Button(action: {
          onSkip?()
        }) {
          VStack(spacing: 12) {
            // Ring with skipped indicator
            ZStack {
              // Background ring (muted)
              Circle()
                .stroke(Color.text05.opacity(0.2), lineWidth: 10)
                .frame(width: 120, height: 120)
              
              // Center content - skipped icon
              VStack(spacing: 4) {
                Image(systemName: "forward.fill")
                  .font(.system(size: 32, weight: .bold))
                  .foregroundColor(.text04)
                
                Text("Skipped")
                  .font(.appBodySmall)
                  .foregroundColor(.text04)
              }
            }
            .contentShape(Circle())
            
            // View Skip button
            Text("View Skip")
              .font(.appBodySmall)
              .foregroundColor(.primary)
          }
        }
        .buttonStyle(ScaleButtonStyle())
      } else {
        // Normal or completed state
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
            if isCompleted {
              Text("Completed ✓")
                .font(.appBodySmall)
                .foregroundColor(.text04)
            } else {
              // In-progress state - show "Tap to log • Skip"
              HStack(spacing: 4) {
                Text("Tap to log")
                  .font(.appBodySmall)
                  .foregroundColor(.text04)
                
                if let onSkip = onSkip {
                  Text("•")
                    .font(.appBodySmall)
                    .foregroundColor(.text05)
                  
                  Button(action: onSkip) {
                    Text("Skip")
                      .font(.appBodySmall)
                      .foregroundColor(.text04)
                  }
                  .buttonStyle(PlainButtonStyle())
                }
              }
            }
          }
        }
        .buttonStyle(ScaleButtonStyle())
      }
    }
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
      onTap: { print("Tapped") },
      isSkipped: false,
      onSkip: { print("Skip tapped") }
    )
    
    // Complete state
    CompletionRingView(
      progress: 1.0,
      currentValue: 30,
      goalValue: 30,
      unit: "min",
      habitColor: .green,
      onTap: { print("Tapped") },
      isSkipped: false,
      onSkip: nil
    )
    
    // Skipped state
    CompletionRingView(
      progress: 0.0,
      currentValue: 0,
      goalValue: 3,
      unit: "times",
      habitColor: .blue,
      onTap: { print("Tapped") },
      isSkipped: true,
      onSkip: { print("Unskip tapped") }
    )
  }
  .padding()
  .background(Color.appSurface01Variant)
}
