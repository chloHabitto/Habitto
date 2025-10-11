import SwiftUI

// MARK: - EmptyStateView

struct EmptyStateView: View {
  let icon: String
  let message: String

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: icon)
        .font(.system(size: 24))
        .foregroundColor(.primaryContainer)

      Text(message)
        .font(.appBodyLarge)
        .foregroundColor(.text05)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 48)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(.surface))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(.outline3, lineWidth: 1))
  }
}
