import SwiftUI
// import Lottie

struct SplashView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var tutorialManager = TutorialManager()
    @State private var showMainApp = false
    
    var body: some View {
        GeometryReader { geometry in
            // Ensure animation fills entire screen without white space
            // LottieView(name: "SplashAnimation")
            //     .frame(width: geometry.size.width, height: geometry.size.height)
            //     .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            //     .ignoresSafeArea(.all, edges: .all) // Fill entire screen including safe areas
            
            // Temporary placeholder while Lottie is disabled
            ZStack {
                Color.primary
                    .ignoresSafeArea(.all, edges: .all)
                
                VStack(spacing: 20) {
                    Text("Habitto")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Building Better Habits")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
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

// MARK: - Lottie Animation View (Disabled)
/*
struct LottieView: UIViewRepresentable {
    let name: String
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        
        // Create Lottie animation view
        let animationView = LottieAnimationView(name: name)
        print("⚠️ Lottie animation disabled: \(name)")
        
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .playOnce
        animationView.animationSpeed = 1.0
        animationView.play()
        
        view.addSubview(animationView)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            animationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}
*/

#Preview {
    SplashView()
}
