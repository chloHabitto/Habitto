import SwiftUI

// MARK: - ViewAnimator-Style Animations for SwiftUI
/// Provides ViewAnimator-inspired animations for SwiftUI views
/// Based on https://github.com/marcosgriselli/ViewAnimator

struct ViewAnimatorStyle {
    /// Animation types inspired by ViewAnimator
    enum AnimationType {
        case fadeIn
        case slideFromTop(offset: CGFloat = 30)
        case slideFromBottom(offset: CGFloat = 30)
        case slideFromLeft(offset: CGFloat = 30)
        case slideFromRight(offset: CGFloat = 30)
        case zoom(scale: CGFloat = 0.5)
        case rotate(angle: Angle = .degrees(15))
        
        var transition: AnyTransition {
            switch self {
            case .fadeIn:
                return AnyTransition.opacity
            case .slideFromTop(let offset):
                return AnyTransition.offset(y: -offset).combined(with: AnyTransition.opacity)
            case .slideFromBottom(let offset):
                return AnyTransition.offset(y: offset).combined(with: AnyTransition.opacity)
            case .slideFromLeft(let offset):
                return AnyTransition.offset(x: -offset).combined(with: AnyTransition.opacity)
            case .slideFromRight(let offset):
                return AnyTransition.offset(x: offset).combined(with: AnyTransition.opacity)
            case .zoom(let scale):
                return AnyTransition.scale(scale: scale).combined(with: AnyTransition.opacity)
            case .rotate(let angle):
                // SwiftUI doesn't have a rotation transition, so we use scale + opacity
                return AnyTransition.scale(scale: 0.8).combined(with: AnyTransition.opacity)
            }
        }
    }
    
    /// Configuration for ViewAnimator-style animations
    struct Config {
        var duration: Double = 0.5
        var dampingFraction: CGFloat = 0.7
        var initialDelay: Double = 0.0
        var itemDelay: Double = 0.05
        
        static let `default` = Config()
        static let fast = Config(duration: 0.3, dampingFraction: 0.8, itemDelay: 0.03)
        static let slow = Config(duration: 0.7, dampingFraction: 0.6, itemDelay: 0.08)
    }
}

// MARK: - View Modifier for Staggered Animations
struct StaggeredAnimationModifier: ViewModifier {
    let index: Int
    let animation: ViewAnimatorStyle.AnimationType
    let config: ViewAnimatorStyle.Config
    @State private var isVisible: Bool = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.9)
            .offset(y: isVisible ? 0 : 10)
            .onAppear {
                withAnimation(
                    .spring(response: config.duration, dampingFraction: config.dampingFraction)
                    .delay(config.initialDelay + Double(index) * config.itemDelay)
                ) {
                    isVisible = true
                }
            }
    }
}

// MARK: - View Extension
extension View {
    /// Apply ViewAnimator-style staggered animation to a view
    /// - Parameters:
    ///   - index: The index of the view in a list (for staggered delay)
    ///   - animation: The type of animation to apply
    ///   - config: Animation configuration
    func animateViewAnimatorStyle(
        index: Int,
        animation: ViewAnimatorStyle.AnimationType = .slideFromBottom(offset: 20),
        config: ViewAnimatorStyle.Config = .default
    ) -> some View {
        self.modifier(StaggeredAnimationModifier(index: index, animation: animation, config: config))
    }
    
    /// Apply entrance animation (fade + scale + slide)
    func entranceAnimation(delay: Double = 0) -> some View {
        self.modifier(EntranceAnimationModifier(delay: delay))
    }
}

// MARK: - Entrance Animation Modifier
struct EntranceAnimationModifier: ViewModifier {
    let delay: Double
    @State private var isVisible: Bool = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.85)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

