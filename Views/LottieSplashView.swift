import SwiftUI
import Lottie

struct LottieSplashView: View {
    @State private var showMainApp = false
    
    var body: some View {
        ZStack {
            // Background color matching your app theme
            Color.primary
                .ignoresSafeArea()
            
            // Full screen Lottie Animation
            LottieView(animation: nil, onAnimationComplete: {
                // Transition immediately when animation completes
                showMainApp = true
            })
            .ignoresSafeArea()
        }
        .onAppear {
            // Fallback: Auto-hide after 4 seconds if animation doesn't complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                if !showMainApp {
                    showMainApp = true
                }
            }
        }
    }
}

// MARK: - LottieView Wrapper
struct LottieView: UIViewRepresentable {
    let animationName: String
    let loopMode: LottieLoopMode
    let onAnimationComplete: (() -> Void)?
    
    init(
        animation: LottieAnimation?,
        loopMode: LottieLoopMode = .playOnce,
        onAnimationComplete: (() -> Void)? = nil
    ) {
        self.animationName = "SplashAnimation"
        self.loopMode = loopMode
        self.onAnimationComplete = onAnimationComplete
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let animationView = LottieAnimationView()
        
        // Load animation by name
        animationView.animation = LottieAnimation.named(animationName)
        animationView.loopMode = loopMode
        animationView.contentMode = .scaleAspectFill  // Changed to fill the entire screen
        animationView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: view.topAnchor),
            animationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            animationView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Set up completion handler
        animationView.animationSpeed = 1.0
        animationView.play { completed in
            if completed {
                // Animation completed successfully
                DispatchQueue.main.async {
                    onAnimationComplete?()
                }
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}

#Preview {
    LottieSplashView()
}
