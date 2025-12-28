import SwiftUI

// MARK: - AnimatedCheckbox

struct AnimatedCheckbox: View {
  // MARK: Internal

  let isChecked: Bool
  let accentColor: Color
  let isAnimating: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        // Background circle
        Circle()
          .fill(isChecked ? accentColor : .surface)
          .frame(width: 28, height: 28)
          .animation(.easeInOut(duration: 0.6), value: isChecked)
          .scaleEffect(isAnimating ? 1.2 : 1.0)
          .animation(
            .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1),
            value: isAnimating)

        // Stroke circle - frame is 26x26 so with 2pt stroke it visually matches the 28x28 filled circle
        Circle()
          .stroke(.outline3, lineWidth: 2)
          .frame(width: 26, height: 26)
          .scaleEffect(isAnimating ? 1.2 : 1.0)
          .animation(.easeInOut(duration: 0.6), value: isChecked)
          .animation(
            .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1),
            value: isAnimating)

        // Checkmark - scaled proportionally to match 28x28 circle
        AnimatedCheckmarkShape()
          .trim(from: 0, to: isChecked ? 1 : 0)
          .stroke(.checkStroke, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
          .frame(width: 22, height: 16)
          .opacity(isHovered && !isChecked ? 0.3 : (isChecked ? 1 : 0))
          .offset(x: isChecked ? -0.5 : 0)
          .animation(.easeInOut(duration: 0.6), value: isChecked)
          .animation(.easeInOut(duration: 0.2), value: isHovered)
      }
    }
    .buttonStyle(PlainButtonStyle())
    .frame(width: 36, height: 36)
    .contentShape(Rectangle())
    .onHover { hovering in
      isHovered = hovering
    }
  }

  // MARK: Private

  @State private var isHovered = false
}

// MARK: - AnimatedCheckmarkShape

struct AnimatedCheckmarkShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()

    // Create checkmark path centered in the frame
    let point1 = CGPoint(x: rect.width * 0.25, y: rect.height * 0.5)
    let point2 = CGPoint(x: rect.width * 0.45, y: rect.height * 0.75)
    let point3 = CGPoint(x: rect.width * 0.85, y: rect.height * 0.25)

    path.move(to: point1)
    path.addLine(to: point2)
    path.addLine(to: point3)

    return path
  }
}

// Preview for testing
#Preview {
  VStack(spacing: 20) {
    Text("Animated Checkbox Examples")
      .font(.title2)

    HStack(spacing: 30) {
      // Unchecked state
      AnimatedCheckbox(
        isChecked: false,
        accentColor: .green,
        isAnimating: false,
        action: { })

      // Checked state
      AnimatedCheckbox(
        isChecked: true,
        accentColor: .blue,
        isAnimating: false,
        action: { })

      // Animating state
      AnimatedCheckbox(
        isChecked: true,
        accentColor: .purple,
        isAnimating: true,
        action: { })
    }

    Text("Unchecked, Checked, Animating")
      .font(.caption)
      .foregroundColor(.secondary)
  }
  .padding()
}
