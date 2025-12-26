import SwiftUI

// MARK: - CelebrationView

struct CelebrationView: View {
  @State private var animateElements = false
  @Binding var isPresented: Bool
  @State private var circleProgress: CGFloat = 0
  @State private var checkmarkProgress: CGFloat = 0
  @State private var confettiParticles: [ConfettiParticle] = []
  @State private var showMessage = false
  @State private var scale: CGFloat = 0.8

  let isPartialCompletion: Bool
  let onDismiss: () -> Void
  
  init(isPresented: Binding<Bool>, isPartialCompletion: Bool = false, onDismiss: @escaping () -> Void) {
    self._isPresented = isPresented
    self.isPartialCompletion = isPartialCompletion
    self.onDismiss = onDismiss
  }

  var body: some View {
    ZStack {
      // Background overlay
      Color.black.opacity(0.2)
        .ignoresSafeArea()
        .onTapGesture {
          dismissCelebration()
        }

      // Confetti layer
      ForEach(confettiParticles, id: \.id) { particle in
        ConfettiShape(particle: particle)
      }

      // Main celebration content
      VStack(spacing: 32) {
        // Check icon with animation
        ZStack {
          // Background circle
          Circle()
            .fill(Color.green)
            .frame(width: 120, height: 120)

          // Animated circle progress (filled)
          Circle()
            .trim(from: 0, to: circleProgress)
            .fill(Color.green)
            .frame(width: 120, height: 120)
            .rotationEffect(.degrees(-90))
            .mask(
              Circle()
                .stroke(Color.white, lineWidth: 8)
                .frame(width: 120, height: 120))

          // Checkmark
          FilledCheckmarkShape(progress: checkmarkProgress)
            .fill(.surface)
            .frame(width: 60, height: 60)
        }
        .scaleEffect(scale)
        .rotationEffect(.degrees(animateElements ? 0 : -180))
        .opacity(animateElements ? 1 : 0)

        // Celebration message
        if showMessage {
          VStack(spacing: 16) {
            Text("Amazing!")
              .font(.appTitleLargeEmphasised)
              .foregroundColor(.white)
              .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

            Text(isPartialCompletion ? "Progress over perfection 🌱" : "All habits completed for today")
              .font(.appBodyLarge)
              .foregroundColor(.white)
              .multilineTextAlignment(.center)
              .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
          }
          .padding(.horizontal, 24)
          .padding(.vertical, 20)
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.black.opacity(0.7))
              .blur(radius: 0.5))
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(.white.opacity(0.2), lineWidth: 1))
          .transition(.asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity).combined(with: .offset(y: 20)),
            removal: .scale(scale: 0.8).combined(with: .opacity)))
          .offset(y: animateElements ? 0 : 30)
          .opacity(animateElements ? 1 : 0)
        }
      }
    }
    .onAppear {
      startCelebrationSequence()

      // Trigger entrance animations
      withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
        animateElements = true
      }
    }
  }

  private func startCelebrationSequence() {
    // Phase 1: Circle drawing animation (0-0.4s)
    withAnimation(.easeInOut(duration: 0.4)) {
      circleProgress = 1.0
    }

    // Phase 2: Checkmark drawing (0.3-0.7s) - starts after circle is more complete
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      withAnimation(.easeOut(duration: 0.4)) {
        checkmarkProgress = 1.0
      }
    }

    // Phase 3: Scale animation (0.4-0.8s)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
        scale = 1.1
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          scale = 1.0
        }
      }
    }

    // Phase 4: Start confetti (0.6s)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
      startConfetti()
    }

    // Phase 5: Show message (0.8s)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
      withAnimation(.easeInOut(duration: 0.3)) {
        showMessage = true
      }
    }

    // Haptic feedback
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
      impactFeedback.impactOccurred()
    }

    // Auto dismiss after 3 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
      dismissCelebration()
    }
  }

  private func startConfetti() {
    // Generate confetti particles
    for _ in 0 ..< 50 {
      let particle = ConfettiParticle(
        id: UUID(),
        x: Double.random(in: 0 ... UIScreen.main.bounds.width),
        y: -50,
        color: getRandomHabittoColor(),
        shape: getRandomShape(),
        size: Double.random(in: 8 ... 16),
        rotation: Double.random(in: 0 ... 360),
        velocity: Double.random(in: 2 ... 6))
      confettiParticles.append(particle)
    }

    // Animate confetti falling
    withAnimation(.linear(duration: 3.0)) {
      for i in confettiParticles.indices {
        confettiParticles[i].y = UIScreen.main.bounds.height + 100
        confettiParticles[i].rotation += 360
      }
    }
  }

  private func getRandomHabittoColor() -> Color {
    let colors: [Color] = [
      .primary,
      .mint,
      .blue,
      .purple,
      .orange,
      .pink,
      .green,
      .yellow,
      .cyan,
      .indigo
    ]
    return colors.randomElement() ?? .primary
  }

  private func getRandomShape() -> ConfettiShapeType {
    let shapes: [ConfettiShapeType] = [.circle, .star, .heart, .diamond]
    return shapes.randomElement() ?? .circle
  }

  private func dismissCelebration() {
    withAnimation(.easeInOut(duration: 0.3)) {
      isPresented = false
    }
    onDismiss()
  }
}

// MARK: - ConfettiParticle

struct ConfettiParticle {
  let id: UUID
  var x: Double
  var y: Double
  let color: Color
  let shape: ConfettiShapeType
  let size: Double
  var rotation: Double
  let velocity: Double
}

// MARK: - ConfettiShapeType

enum ConfettiShapeType {
  case circle
  case star
  case heart
  case diamond
}

// MARK: - ConfettiShape

struct ConfettiShape: View {
  let particle: ConfettiParticle

  var body: some View {
    Group {
      switch particle.shape {
      case .circle:
        Circle()
          .fill(particle.color)
          .frame(width: particle.size, height: particle.size)

      case .star:
        StarShape()
          .fill(particle.color)
          .frame(width: particle.size, height: particle.size)

      case .heart:
        HeartShape()
          .fill(particle.color)
          .frame(width: particle.size, height: particle.size)

      case .diamond:
        DiamondShape()
          .fill(particle.color)
          .frame(width: particle.size, height: particle.size)
      }
    }
    .position(x: particle.x, y: particle.y)
    .rotationEffect(.degrees(particle.rotation))
  }
}

// MARK: - CheckmarkShape

struct CheckmarkShape: Shape {
  var progress: CGFloat

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()

    let width = rect.width
    let height = rect.height

    // Checkmark path
    let startX = width * 0.2
    let startY = height * 0.5
    let midX = width * 0.45
    let midY = height * 0.7
    let endX = width * 0.8
    let endY = height * 0.3

    path.move(to: CGPoint(x: startX, y: startY))
    path.addLine(to: CGPoint(x: midX, y: midY))
    path.addLine(to: CGPoint(x: endX, y: endY))

    return path.trimmedPath(from: 0, to: progress)
  }
}

// MARK: - FilledCheckmarkShape

struct FilledCheckmarkShape: Shape {
  var progress: CGFloat

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()

    let width = rect.width
    let height = rect.height
    let thickness: CGFloat = 10

    // More natural checkmark points
    let startX = width * 0.2
    let startY = height * 0.6
    let midX = width * 0.45
    let midY = height * 0.8
    let endX = width * 0.8
    let endY = height * 0.2

    // Create a more natural checkmark path
    let leftStart = CGPoint(x: startX, y: startY)
    let leftEnd = CGPoint(x: midX, y: midY)
    let rightStart = CGPoint(x: midX, y: midY)
    let rightEnd = CGPoint(x: endX, y: endY)

    // Calculate the total path length for more natural progress
    let leftLength = sqrt(pow(leftEnd.x - leftStart.x, 2) + pow(leftEnd.y - leftStart.y, 2))
    let rightLength = sqrt(pow(rightEnd.x - rightStart.x, 2) + pow(rightEnd.y - rightStart.y, 2))
    let totalLength = leftLength + rightLength

    // Calculate progress for each segment
    let leftProgress = min(progress * totalLength / leftLength, 1.0)
    let rightProgress = max(0, (progress * totalLength - leftLength) / rightLength)

    // Draw left segment
    if leftProgress > 0 {
      let leftEndPoint = CGPoint(
        x: leftStart.x + (leftEnd.x - leftStart.x) * leftProgress,
        y: leftStart.y + (leftEnd.y - leftStart.y) * leftProgress)

      path.move(to: leftStart)
      path.addLine(to: leftEndPoint)
    }

    // Draw right segment
    if rightProgress > 0 {
      let rightStartPoint = CGPoint(x: midX, y: midY)
      let rightEndPoint = CGPoint(
        x: rightStartPoint.x + (rightEnd.x - rightStartPoint.x) * rightProgress,
        y: rightStartPoint.y + (rightEnd.y - rightStartPoint.y) * rightProgress)

      if leftProgress >= 1.0 {
        path.move(to: rightStartPoint)
      }
      path.addLine(to: rightEndPoint)
    }

    // Create thickness by stroking the path
    let strokedPath = path.strokedPath(StrokeStyle(
      lineWidth: thickness,
      lineCap: .round,
      lineJoin: .round))

    return strokedPath
  }
}

// MARK: - StarShape

struct StarShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2

    let outerRadius = radius
    let innerRadius = radius * 0.4

    for i in 0 ..< 10 {
      let angle = Double(i) * .pi / 5 - .pi / 2
      let currentRadius = i % 2 == 0 ? outerRadius : innerRadius
      let x = center.x + cos(angle) * currentRadius
      let y = center.y + sin(angle) * currentRadius

      if i == 0 {
        path.move(to: CGPoint(x: x, y: y))
      } else {
        path.addLine(to: CGPoint(x: x, y: y))
      }
    }
    path.closeSubpath()
    return path
  }
}

// MARK: - HeartShape

struct HeartShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let width = rect.width
    let height = rect.height

    // Heart shape using cubic curves
    path.move(to: CGPoint(x: width * 0.5, y: height * 0.9))

    path.addCurve(
      to: CGPoint(x: width * 0.1, y: height * 0.3),
      control1: CGPoint(x: width * 0.5, y: height * 0.7),
      control2: CGPoint(x: width * 0.1, y: height * 0.5))

    path.addCurve(
      to: CGPoint(x: width * 0.5, y: height * 0.1),
      control1: CGPoint(x: width * 0.1, y: height * 0.1),
      control2: CGPoint(x: width * 0.3, y: height * 0.1))

    path.addCurve(
      to: CGPoint(x: width * 0.9, y: height * 0.3),
      control1: CGPoint(x: width * 0.7, y: height * 0.1),
      control2: CGPoint(x: width * 0.9, y: height * 0.1))

    path.addCurve(
      to: CGPoint(x: width * 0.5, y: height * 0.9),
      control1: CGPoint(x: width * 0.9, y: height * 0.5),
      control2: CGPoint(x: width * 0.5, y: height * 0.7))

    return path
  }
}

// MARK: - DiamondShape

struct DiamondShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let width = rect.width
    let height = rect.height

    path.move(to: CGPoint(x: width * 0.5, y: 0)) // Top
    path.addLine(to: CGPoint(x: width, y: height * 0.5)) // Right
    path.addLine(to: CGPoint(x: width * 0.5, y: height)) // Bottom
    path.addLine(to: CGPoint(x: 0, y: height * 0.5)) // Left
    path.closeSubpath()

    return path
  }
}

#Preview {
  CelebrationView(
    isPresented: .constant(true),
    isPartialCompletion: false,
    onDismiss: { })
}
