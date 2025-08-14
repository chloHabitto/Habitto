import UIKit
import Lottie

class SplashViewController: UIViewController {
    
    // MARK: - Properties
    private var animationView: LottieAnimationView?
    private var logoImageView: UIImageView?
    private var titleLabel: UILabel?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupAnimation()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAnimation()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Setup logo image view
        logoImageView = UIImageView()
        logoImageView?.contentMode = .scaleAspectFit
        logoImageView?.translatesAutoresizingMaskIntoConstraints = false
        
        if let logoImageView = logoImageView {
            view.addSubview(logoImageView)
        }
        
        // Setup title label
        titleLabel = UILabel()
        titleLabel?.text = "Habitto"
        titleLabel?.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel?.textColor = UIColor.label
        titleLabel?.textAlignment = .center
        titleLabel?.alpha = 0.0 // Start invisible for fade-in effect
        titleLabel?.translatesAutoresizingMaskIntoConstraints = false
        
        if let titleLabel = titleLabel {
            view.addSubview(titleLabel)
        }
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        guard let logoImageView = logoImageView,
              let titleLabel = titleLabel else { return }
        
        NSLayoutConstraint.activate([
            // Logo constraints - center of screen
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            logoImageView.widthAnchor.constraint(equalToConstant: 120),
            logoImageView.heightAnchor.constraint(equalToConstant: 120),
            
            // Title constraints - below logo
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    // MARK: - Animation Setup
    private func setupAnimation() {
        // Load the Lottie animation
        if let animation = LottieAnimation.named("SplashAnimation") {
            animationView = LottieAnimationView(animation: animation)
            animationView?.contentMode = .scaleAspectFit
            animationView?.translatesAutoresizingMaskIntoConstraints = false
            animationView?.loopMode = .playOnce
            animationView?.animationSpeed = 1.0
            
            if let animationView = animationView {
                view.addSubview(animationView)
                
                // Position animation view over the logo area
                NSLayoutConstraint.activate([
                    animationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    animationView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
                    animationView.widthAnchor.constraint(equalToConstant: 200),
                    animationView.heightAnchor.constraint(equalToConstant: 200)
                ])
                
                // Initially hide the logo since animation will be displayed
                logoImageView?.alpha = 0.0
            }
        } else {
            print("⚠️ Could not load SplashAnimation.json - falling back to static logo")
            // If animation fails to load, show the logo instead
            logoImageView?.alpha = 1.0
        }
    }
    
    // MARK: - Animation Start
    private func startAnimation() {
        if let animationView = animationView {
            // Start the Lottie animation
            animationView.play { [weak self] finished in
                if finished {
                    self?.onAnimationComplete()
                }
            }
            
            // Fade in the title label
            UIView.animate(withDuration: 0.8, delay: 0.3, options: .curveEaseInOut) {
                self.titleLabel?.alpha = 1.0
            }
        } else {
            // Fallback animation if Lottie fails
            fallbackAnimation()
        }
    }
    
    private func fallbackAnimation() {
        // Simple fade-in animation for logo and title
        UIView.animate(withDuration: 1.0, delay: 0.5, options: .curveEaseInOut) {
            self.logoImageView?.alpha = 1.0
            self.titleLabel?.alpha = 1.0
        } completion: { _ in
            // Wait a bit then transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.onAnimationComplete()
            }
        }
    }
    
    // MARK: - Animation Completion
    private func onAnimationComplete() {
        // Add a small delay for better user experience
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.transitionToMainApp()
        }
    }
    
    private func transitionToMainApp() {
        // Create a smooth transition to your main app
        let transition = CATransition()
        transition.duration = 0.5
        transition.type = .fade
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // Get the window and set the root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            // Replace the root view controller with your main app
            // You'll need to adjust this based on your app's structure
            if let mainViewController = createMainViewController() {
                window.layer.add(transition, forKey: kCATransition)
                window.rootViewController = mainViewController
            }
        }
    }
    
    private func createMainViewController() -> UIViewController? {
        // This is where you'd create your main app's root view controller
        // For now, I'll create a placeholder - you'll need to adjust this
        
        // Option 1: If you have a storyboard-based main view controller
        // return UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
        
        // Option 2: If you have a programmatic main view controller
        // return YourMainViewController()
        
        // Option 3: For now, create a simple placeholder
        let placeholderVC = UIViewController()
        placeholderVC.view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = "Main App"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        placeholderVC.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: placeholderVC.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: placeholderVC.view.centerYAnchor)
        ])
        
        return placeholderVC
    }
}

// MARK: - Extensions
extension SplashViewController {
    // Helper method to check if animation file exists
    static func hasAnimationFile() -> Bool {
        return LottieAnimation.named("SplashAnimation") != nil
    }
}
