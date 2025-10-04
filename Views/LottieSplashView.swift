import SwiftUI
import Lottie

struct LottieSplashView: View {
    @State private var animationFailed = false
    @State private var shouldDismiss = false
    @State private var showLoginView = false
    let onAnimationComplete: (() -> Void)?
    
    init(onAnimationComplete: (() -> Void)? = nil) {
        self.onAnimationComplete = onAnimationComplete
    }
    
    var body: some View {
        Group {
            if shouldDismiss {
                // Animation completed - don't show anything
                EmptyView()
            } else if animationFailed {
                // Fallback: Show nothing - just empty background
                EmptyView()
            } else {
                // Full screen Lottie Animation with Sign In button
                ZStack {
                    LottieView(animation: nil, onAnimationComplete: {
                        print("✅ LottieSplashView: Animation completed")
                        shouldDismiss = true
                        onAnimationComplete?()
                    })
                    .ignoresSafeArea()
                    
                    // Sign In Button positioned at bottom
                    VStack {
                        Spacer()
                        signInButton
                            .padding(.horizontal, 24)
                            .padding(.bottom, 50) // Safe area padding
                    }
                }
            }
        }
        .onAppear {
            // Fallback: Auto-complete after 3 seconds if animation doesn't finish
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if !shouldDismiss {
                    print("⚠️ LottieSplashView: Animation timeout, completing")
                    shouldDismiss = true
                    onAnimationComplete?()
                }
            }
        }
        .sheet(isPresented: $showLoginView) {
            LoginView()
        }
    }
    
    // MARK: - Sign In Button
    private var signInButton: some View {
        HabittoButton(
            size: .large,
            style: .fillPrimary,
            content: .text("Sign In"),
            hugging: false
        ) {
            showLoginView = true
        }
    }
}

// Alternative approach - better solution
struct LottieSplashView2: View {
    @State private var isVisible = true
    @State private var showLoginView = false
    let onAnimationComplete: (() -> Void)?
    
    init(onAnimationComplete: (() -> Void)? = nil) {
        self.onAnimationComplete = onAnimationComplete
    }
    
    var body: some View {
        Group {
            if isVisible {
                ZStack {
                    LottieView(animation: nil, onAnimationComplete: {
                        print("✅ LottieSplashView: Animation completed")
                        withAnimation(.easeOut(duration: 0.3)) {
                            isVisible = false
                        }
                        // Small delay to ensure smooth transition
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onAnimationComplete?()
                        }
                    })
                    .ignoresSafeArea()
                    .transition(.opacity)
                    
                    // Sign In Button positioned at bottom
                    VStack {
                        Spacer()
                        signInButton
                            .padding(.horizontal, 24)
                            .padding(.bottom, 50) // Safe area padding
                    }
                }
            }
        }
        .onAppear {
            // Fallback timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if isVisible {
                    print("⚠️ LottieSplashView: Animation timeout")
                    withAnimation(.easeOut(duration: 0.3)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onAnimationComplete?()
                    }
                }
            }
        }
        .sheet(isPresented: $showLoginView) {
            LoginView()
        }
    }
    
    // MARK: - Sign In Button
    private var signInButton: some View {
        HabittoButton(
            size: .large,
            style: .fillPrimary,
            content: .text("Sign In"),
            hugging: false
        ) {
            showLoginView = true
        }
    }
}

// MARK: - LottieView Wrapper (unchanged)
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
        if let path = Bundle.main.path(forResource: animationName, ofType: "json") {
            animationView.animation = LottieAnimation.filepath(path)
            print("✅ LottieSplashView: Successfully loaded animation from path: \(path)")
        } else {
            print("❌ LottieSplashView: Failed to find animation file: \(animationName).json")
            animationView.animation = LottieAnimation.named(animationName)
            if animationView.animation == nil {
                print("❌ LottieSplashView: Also failed to load animation by name: \(animationName)")
            } else {
                print("✅ LottieSplashView: Successfully loaded animation by name: \(animationName)")
            }
        }
        
        animationView.loopMode = loopMode
        animationView.contentMode = .scaleAspectFill
        animationView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: view.topAnchor),
            animationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            animationView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        animationView.animationSpeed = 1.0
        
        if animationView.animation != nil {
            animationView.play { completed in
                if completed {
                    DispatchQueue.main.async {
                        onAnimationComplete?()
                    }
                }
            }
        } else {
            print("❌ LottieSplashView: Animation failed to load, triggering completion")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onAnimationComplete?()
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}

#Preview {
    LottieSplashView2()
}
