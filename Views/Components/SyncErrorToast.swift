import SwiftUI
import MijickPopups

// MARK: - SyncErrorToast

struct SyncErrorToast: TopPopup, View {
  let message: String
  let onRetry: (() -> Void)?
  
  var body: some View {
    createContent()
  }
  
  func createContent() -> some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 20))
        .foregroundColor(.appText01Inverse)
      
      VStack(alignment: .leading, spacing: 4) {
        Text("Sync Error")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.appText01Inverse)
        
        Text(message)
          .font(.system(size: 12, weight: .regular))
          .foregroundColor(.appText01Inverse)
          .lineLimit(2)
      }
      
      Spacer()
      
      if let onRetry = onRetry {
        Button(action: {
          onRetry()
        }) {
          Text("Retry")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.appText01Inverse)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.appInverseSurface70)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    .padding(.horizontal, 20)
  }
  
  func configurePopup(popup: TopPopupConfig) -> TopPopupConfig {
    popup
    // Note: dismissAfter is not available on TopPopupConfig in this version
    // Auto-dismiss will need to be handled manually if needed
  }
}

// MARK: - SyncSuccessToast

struct SyncSuccessToast: TopPopup, View {
  let message: String
  
  var body: some View {
    createContent()
  }
  
  func createContent() -> some View {
    HStack(spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 20))
        .foregroundColor(.appText01Inverse)
      
      Text(message)
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.appText01Inverse)
      
      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.appInverseSurface70)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    .padding(.horizontal, 20)
  }
  
  func configurePopup(popup: TopPopupConfig) -> TopPopupConfig {
    popup
    // Note: dismissAfter is not available on TopPopupConfig in this version
    // Auto-dismiss will need to be handled manually if needed
  }
}

