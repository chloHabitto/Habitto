import Lottie
import SwiftUI

// MARK: - StreakFireAnimation

struct StreakFireAnimation: View {
  var body: some View {
    StreakFireLottieView()
  }
}

// MARK: - StreakFireLottieView

struct StreakFireLottieView: UIViewRepresentable {
  let loopMode: LottieLoopMode
  
  init(loopMode: LottieLoopMode = .loop) {
    self.loopMode = loopMode
  }
  
  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    let animationView = LottieAnimationView()
    
    // Load StreakFireAnimation.json from Animations folder
    if let path = Bundle.main.path(forResource: "StreakFireAnimation", ofType: "json") {
      animationView.animation = LottieAnimation.filepath(path)
    } else {
      animationView.animation = LottieAnimation.named("StreakFireAnimation")
    }
    
    animationView.loopMode = loopMode
    animationView.contentMode = .scaleAspectFit
    animationView.translatesAutoresizingMaskIntoConstraints = false
    
    view.addSubview(animationView)
    NSLayoutConstraint.activate([
      animationView.topAnchor.constraint(equalTo: view.topAnchor),
      animationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      animationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      animationView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    
    animationView.animationSpeed = 1.0
    animationView.play()
    
    return view
  }
  
  func updateUIView(_ uiView: UIView, context: Context) {
    // No updates needed
  }
}

