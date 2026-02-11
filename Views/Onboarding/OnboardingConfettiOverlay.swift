import SwiftUI

// MARK: - OnboardingConfettiOverlay

struct OnboardingConfettiOverlay: View {
  @State private var particles: [ConfettiPart] = []
  @State private var tick: Int = 0
  @State private var timer: Timer?

  var body: some View {
    Canvas { context, size in
      for particle in particles {
        guard particle.opacity > 0 else { continue }

        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: particle.x, y: particle.y)
        transform = transform.rotated(by: particle.rotation * .pi / 180)

        context.opacity = particle.opacity

        if particle.isCircle {
          let rect = CGRect(
            x: particle.x - particle.size / 2,
            y: particle.y - particle.size / 2,
            width: particle.size,
            height: particle.size
          )
          context.fill(Path(ellipseIn: rect), with: .color(particle.color))
        } else {
          let w = particle.size * 0.5
          let h = particle.size * 1.5
          let rect = CGRect(
            x: particle.x - w / 2,
            y: particle.y - h / 2,
            width: w,
            height: h
          )
          context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(particle.color))
        }

        context.opacity = 1.0
      }
    }
    .allowsHitTesting(false)
    .onAppear {
      generateAllBursts()
      startPhysicsLoop()
    }
    .onDisappear {
      timer?.invalidate()
      timer = nil
    }
  }

  private func generateAllBursts() {
    let screenW = UIScreen.main.bounds.width
    let screenH = UIScreen.main.bounds.height
    let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink, .mint, .cyan, .indigo]

    let burst1 = makeBurst(
      originX: screenW * 0.5,
      originY: screenH * 0.6,
      count: 50,
      spreadDeg: 80,
      velocity: 600,
      colors: colors
    )

    let burst2 = makeBurst(
      originX: screenW * 0.3,
      originY: screenH * 0.5,
      count: 30,
      spreadDeg: 100,
      velocity: 500,
      colors: colors
    )

    let burst3 = makeBurst(
      originX: screenW * 0.7,
      originY: screenH * 0.5,
      count: 30,
      spreadDeg: 100,
      velocity: 500,
      colors: colors
    )

    particles = burst1

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      particles.append(contentsOf: burst2)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
      particles.append(contentsOf: burst3)
    }
  }

  private func makeBurst(
    originX: CGFloat,
    originY: CGFloat,
    count: Int,
    spreadDeg: CGFloat,
    velocity: CGFloat,
    colors: [Color]
  ) -> [ConfettiPart] {
    var result: [ConfettiPart] = []
    for _ in 0..<count {
      let angleDeg = CGFloat.random(in: -spreadDeg/2...spreadDeg/2)
      let angleRad = angleDeg * .pi / 180
      let speed = velocity * CGFloat.random(in: 0.5...1.0)
      let vx = sin(angleRad) * speed
      let vy = -cos(angleRad) * speed

      result.append(ConfettiPart(
        x: originX + CGFloat.random(in: -5...5),
        y: originY + CGFloat.random(in: -5...5),
        vx: vx,
        vy: vy,
        color: colors.randomElement()!,
        size: CGFloat.random(in: 6...12),
        isCircle: Bool.random(),
        rotation: CGFloat.random(in: 0...360),
        rotationSpeed: CGFloat.random(in: -300...300),
        opacity: 1.0,
        age: 0,
        lifetime: CGFloat.random(in: 2.0...3.0)
      ))
    }
    return result
  }

  private func startPhysicsLoop() {
    let dt: CGFloat = 1.0 / 60.0
    let gravity: CGFloat = 900

    timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(dt), repeats: true) { _ in
      DispatchQueue.main.async {
        var allDead = true
        for i in particles.indices {
          particles[i].age += dt

          if particles[i].age >= particles[i].lifetime {
            particles[i].opacity = 0
            continue
          }

          allDead = false

          particles[i].vy += gravity * dt
          particles[i].x += particles[i].vx * dt
          particles[i].y += particles[i].vy * dt
          particles[i].rotation += particles[i].rotationSpeed * dt

          particles[i].vx *= 0.995

          let remaining = particles[i].lifetime - particles[i].age
          if remaining < 0.5 {
            particles[i].opacity = Double(max(0, remaining / 0.5))
          }
        }

        tick += 1

        if allDead {
          timer?.invalidate()
          timer = nil
        }
      }
    }
  }
}

// MARK: - ConfettiPart

private struct ConfettiPart: Identifiable {
  let id = UUID()
  var x: CGFloat
  var y: CGFloat
  var vx: CGFloat
  var vy: CGFloat
  let color: Color
  let size: CGFloat
  let isCircle: Bool
  var rotation: CGFloat
  var rotationSpeed: CGFloat
  var opacity: Double
  var age: CGFloat
  let lifetime: CGFloat
}
