import SwiftUI

// MARK: - ViewAnimatorStyle

// Provides ViewAnimator-inspired animations for SwiftUI views
// Based on https://github.com/marcosgriselli/ViewAnimator

enum ViewAnimatorStyle {
  /// Animation types inspired by ViewAnimator
  enum AnimationType {
    case fadeIn
    case slideFromTop(offset: CGFloat = 30)
    case slideFromBottom(offset: CGFloat = 30)
    case slideFromLeft(offset: CGFloat = 30)
    case slideFromRight(offset: CGFloat = 30)
    case zoom(scale: CGFloat = 0.5)
    case rotate(angle: Angle = .degrees(15))

    // MARK: Internal

    var transition: AnyTransition {
      switch self {
      case .fadeIn:
        AnyTransition.opacity
      case .slideFromTop(let offset):
        AnyTransition.offset(y: -offset).combined(with: AnyTransition.opacity)
      case .slideFromBottom(let offset):
        AnyTransition.offset(y: offset).combined(with: AnyTransition.opacity)
      case .slideFromLeft(let offset):
        AnyTransition.offset(x: -offset).combined(with: AnyTransition.opacity)
      case .slideFromRight(let offset):
        AnyTransition.offset(x: offset).combined(with: AnyTransition.opacity)
      case .zoom(let scale):
        AnyTransition.scale(scale: scale).combined(with: AnyTransition.opacity)
      case .rotate:
        // SwiftUI doesn't have a rotation transition, so we use scale + opacity
        AnyTransition.scale(scale: 0.8).combined(with: AnyTransition.opacity)
      }
    }
  }

  /// Configuration for ViewAnimator-style animations
  struct Config {
    static let `default` = Config()
    static let fast = Config(duration: 0.3, dampingFraction: 0.8, itemDelay: 0.03)
    static let slow = Config(duration: 0.7, dampingFraction: 0.6, itemDelay: 0.08)

    var duration = 0.5
    var dampingFraction: CGFloat = 0.7
    var initialDelay = 0.0
    var itemDelay = 0.05
  }
}

// MARK: - StaggeredAnimationModifier

struct StaggeredAnimationModifier: ViewModifier {
  // MARK: Internal

  let index: Int
  let animation: ViewAnimatorStyle.AnimationType
  let config: ViewAnimatorStyle.Config

  func body(content: Content) -> some View {
    content
      .opacity(isVisible ? 1 : 0)
      .scaleEffect(isVisible ? 1 : 0.95) // Subtle scale (95% → 100%)
      .offset(y: isVisible ? 0 : 6) // Subtle slide (6 points)
      .onAppear {
        withAnimation(
          .spring(response: config.duration, dampingFraction: config.dampingFraction)
            .delay(config.initialDelay + Double(index) * config.itemDelay))
        {
          isVisible = true
        }
      }
  }

  // MARK: Private

  @State private var isVisible = false
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
    config: ViewAnimatorStyle.Config = .default) -> some View
  {
    modifier(StaggeredAnimationModifier(index: index, animation: animation, config: config))
  }

  /// Apply entrance animation (fade + scale + slide)
  func entranceAnimation(delay: Double = 0) -> some View {
    modifier(EntranceAnimationModifier(delay: delay))
  }
}

// MARK: - EntranceAnimationModifier

struct EntranceAnimationModifier: ViewModifier {
  // MARK: Internal

  let delay: Double

  func body(content: Content) -> some View {
    content
      .opacity(isVisible ? 1 : 0)
      .scaleEffect(isVisible ? 1 : 0.97) // Very subtle scale (97% → 100%)
      .offset(y: isVisible ? 0 : 8) // Very subtle slide (8 points)
      .onAppear {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay)) {
          // Smoother spring
          isVisible = true
        }
      }
  }

  // MARK: Private

  @State private var isVisible = false
}
