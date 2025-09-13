import SwiftUI
// import Lottie // Temporarily commented out - package dependency issues

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

// MARK: - Simple View Wrapper (Lottie disabled)
struct LottieView: UIViewRepresentable {
    let name: String
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        
        // Simple fallback - just return empty view
        print("⚠️ Lottie animation disabled: \(name)")
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}

#Preview {
    SplashView()
}
