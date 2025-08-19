import SwiftUI
import Lottie

struct SplashView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var tutorialManager = TutorialManager()
    @State private var showMainApp = false
    
    var body: some View {
        GeometryReader { geometry in
            // Ensure animation fills entire screen without white space
            LottieView(name: "SplashAnimation")
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .ignoresSafeArea(.all, edges: .all) // Fill entire screen including safe areas
                .onAppear {
                    // Animation plays automatically
                }
                .onAppear {
                    // Start timer immediately - no waiting for loading
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        // Always show main app - no authentication required
                        showMainApp = true
                    }
                }
                .fullScreenCover(isPresented: $showMainApp) {
                    // Navigate directly to main app without authentication
                    HomeView()
                        .preferredColorScheme(.light)
                        .environment(\.managedObjectContext, CoreDataManager.shared.context)
                        .environmentObject(CoreDataManager.shared)
                        .environmentObject(CoreDataAdapter.shared)
                        .environmentObject(tutorialManager)
                        .environmentObject(authManager)
                }
        }
        .ignoresSafeArea(.all, edges: .all)
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
        
        // Ensure the animation view fills the entire container
        animationView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set clipsToBounds to false to allow full screen coverage
        animationView.clipsToBounds = false
        
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
