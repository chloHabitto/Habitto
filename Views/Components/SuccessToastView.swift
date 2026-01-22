import SwiftUI
import UIKit

// MARK: - SuccessToastView

/// A toast notification that appears after habit creation or edit with a success checkmark
struct SuccessToastView: View {
  // MARK: Lifecycle
  
  init(message: String, onDismiss: @escaping () -> Void) {
    self.message = message
    self.onDismiss = onDismiss
  }
  
  // MARK: Internal
  
  let message: String
  let onDismiss: () -> Void
  
  var body: some View {
    HStack(spacing: 12) {
      // Success checkmark icon
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 20, weight: .semibold))
        .foregroundColor(.appInverseSuccess)
      
      // Success message
      Text(message)
        .font(.appBodyLarge)
        .foregroundColor(.appText01Inverse)
        .lineLimit(2)
      
      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.appInverseSurface80)
    )
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    .onAppear {
      // Haptic feedback
      UINotificationFeedbackGenerator().notificationOccurred(.success)
      
      // Auto-dismiss after 2.5 seconds
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
        onDismiss()
      }
    }
  }
}

// MARK: - Preview

#Preview {
  ZStack {
    Color.gray.ignoresSafeArea()
    
    VStack {
      Spacer()
      
      SuccessToastView(
        message: "\"Morning Yoga\" created",
        onDismiss: {
          print("Toast dismissed")
        }
      )
      .padding(.horizontal, 16)
      .padding(.bottom, ToastConstants.bottomPadding)
    }
  }
}
