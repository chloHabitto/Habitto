import SwiftUI
import Lottie

struct SplashView: View {
    @State private var showMainApp = false
    
    var body: some View {
        // Remove ZStack - just show animation directly
        LottieView(name: "SplashAnimation")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea() // Fill entire screen
            .onAppear {
                // Animation plays automatically
            }
            .onAppear {
                // Start timer immediately - no waiting for loading
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    showMainApp = true
                }
            }
            .fullScreenCover(isPresented: $showMainApp) {
                HomeView()
                    .preferredColorScheme(.light)
                    .environment(\.managedObjectContext, CoreDataManager.shared.context)
                    .environmentObject(CoreDataManager.shared)
                    .environmentObject(CoreDataAdapter.shared)
                    .environmentObject(TutorialManager())
            }
    }
}

// MARK: - Lottie View Wrapper
struct LottieView: UIViewRepresentable {
    let name: String
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView()
        animationView.contentMode = .scaleAspectFill // Fill entire screen
        animationView.loopMode = .playOnce
        animationView.animationSpeed = 1.0
        animationView.backgroundColor = .clear
        animationView.isOpaque = false // Allow transparency
        
        // Load and play the animation immediately
        if let animation = LottieAnimation.named(name) {
            animationView.animation = animation
            animationView.play()
        } else {
            print("⚠️ Could not load Lottie animation: \(name)")
        }
        
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        // No updates needed
    }
}



#Preview {
    SplashView()
}
