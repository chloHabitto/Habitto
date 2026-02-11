import SwiftUI

struct OnboardingConfettiOverlay: View {
  @Binding var isActive: Bool
  @State private var particles: [OnboardingConfettiParticle] = []
  @State private var startTime: Date?

  var body: some View {
    TimelineView(.animation) { timeline in
      Canvas { context, size in
        guard let start = startTime else { return }
        let elapsed = timeline.date.timeIntervalSince(start)

        for particle in particles {
          let age = elapsed - particle.delaySeconds
          guard age >= 0 && age < particle.lifetime else { continue }

          let gravity: CGFloat = 800
          let t = CGFloat(age)
          let x = particle.startX + particle.horizontalVelocity * t
          let y = particle.startY - particle.upwardVelocity * t + 0.5 * gravity * t * t

          let fadeStart = particle.lifetime - 0.5
          let opacity = age > fadeStart ? max(0, (particle.lifetime - age) / 0.5) : 1.0

          let rotation = Angle.degrees(particle.rotationSpeed * age)

          context.opacity = opacity
          context.translateBy(x: x, y: y)
          context.rotate(by: rotation)

          let rect = CGRect(
            x: -particle.width / 2,
            y: -particle.height / 2,
            width: particle.width,
            height: particle.height
          )

          if particle.isCircle {
            context.fill(Path(ellipseIn: rect), with: .color(particle.color))
          } else {
            context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(particle.color))
          }

          context.rotate(by: -rotation)
          context.translateBy(x: -x, y: -y)
          context.opacity = 1
        }
      }
    }
    .allowsHitTesting(false)
    .onChange(of: isActive) { _, newValue in
      if newValue {
        generateParticles()
        startTime = Date()
      }
    }
  }

  private func generateParticles() {
    let screenW = UIScreen.main.bounds.width
    let screenH = UIScreen.main.bounds.height
    let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink, .mint, .cyan, .indigo]

    struct BurstConfig {
      let delay: Double
      let originX: CGFloat
      let originY: CGFloat
      let count: Int
      let spreadDegrees: CGFloat
      let velocity: CGFloat
    }

    let bursts: [BurstConfig] = [
      BurstConfig(delay: 0, originX: 0.5, originY: 0.6, count: 40, spreadDegrees: 80, velocity: 600),
      BurstConfig(delay: 0.15, originX: 0.3, originY: 0.5, count: 25, spreadDegrees: 100, velocity: 500),
      BurstConfig(delay: 0.30, originX: 0.7, originY: 0.5, count: 25, spreadDegrees: 100, velocity: 500),
    ]

    var newParticles: [OnboardingConfettiParticle] = []

    for burst in bursts {
      let originX = screenW * burst.originX
      let originY = screenH * burst.originY

      for _ in 0..<burst.count {
        let angleDeg = CGFloat.random(in: (-burst.spreadDegrees / 2)...(burst.spreadDegrees / 2))
        let angleRad = angleDeg * .pi / 180
        let speed = burst.velocity * CGFloat.random(in: 0.6...1.0)
        let vx = sin(angleRad) * speed
        let vy = cos(angleRad) * speed

        let isCircle = Bool.random()
        let size = CGFloat.random(in: 6...12)

        newParticles.append(OnboardingConfettiParticle(
          startX: originX,
          startY: originY,
          upwardVelocity: vy,
          horizontalVelocity: vx,
          color: colors.randomElement()!,
          width: isCircle ? size : CGFloat.random(in: 4...6),
          height: isCircle ? size : CGFloat.random(in: 8...14),
          isCircle: isCircle,
          rotationSpeed: Double.random(in: -360...360),
          lifetime: Double.random(in: 2.0...3.0),
          delaySeconds: burst.delay
        ))
      }
    }

    particles = newParticles
  }
}

private struct OnboardingConfettiParticle: Identifiable {
  let id = UUID()
  let startX: CGFloat
  let startY: CGFloat
  let upwardVelocity: CGFloat
  let horizontalVelocity: CGFloat
  let color: Color
  let width: CGFloat
  let height: CGFloat
  let isCircle: Bool
  let rotationSpeed: Double
  let lifetime: Double
  let delaySeconds: Double
}
