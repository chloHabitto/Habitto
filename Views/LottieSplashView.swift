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
            LottieView(animation: nil)
                .ignoresSafeArea()
                .scaleEffect(showMainApp ? 0.8 : 1.0)
                .opacity(showMainApp ? 0.0 : 1.0)
        }
        .onAppear {
            // Auto-hide after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 0.8)) {
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
    
    init(
        animation: LottieAnimation?,
        loopMode: LottieLoopMode = .playOnce
    ) {
        self.animationName = "SplashAnimation"
        self.loopMode = loopMode
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
        
        animationView.play()
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}

#Preview {
    LottieSplashView()
}
