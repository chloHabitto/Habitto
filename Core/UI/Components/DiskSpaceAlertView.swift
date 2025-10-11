import SwiftUI

// MARK: - DiskSpaceAlertView

/// User-visible alert when disk space is insufficient
struct DiskSpaceAlertView: View {
  // MARK: Internal

  let requiredSpace: Int
  let availableSpace: Int
  let onDismiss: () -> Void
  let onRetry: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      // Icon
      Image(systemName: "externaldrive.trianglebadge.exclamationmark")
        .font(.system(size: 50))
        .foregroundColor(.red)

      // Title
      Text("Storage Space Low")
        .font(.title2)
        .fontWeight(.bold)

      // Message
      VStack(spacing: 12) {
        Text("Your device doesn't have enough storage space to save your data safely.")
          .multilineTextAlignment(.center)
          .foregroundColor(.secondary)

        // Space details
        VStack(spacing: 8) {
          HStack {
            Text("Required:")
            Spacer()
            Text(formatBytes(requiredSpace))
              .fontWeight(.medium)
          }

          HStack {
            Text("Available:")
            Spacer()
            Text(formatBytes(availableSpace))
              .fontWeight(.medium)
          }
        }
        .font(.caption)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)

        Text("Please free up some space and try again.")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      // Action buttons
      VStack(spacing: 12) {
        Button(action: onRetry) {
          Text("Try Again")
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }

        Button(action: onDismiss) {
          Text("Cancel")
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(10)
        }
      }
    }
    .padding(24)
    .background(Color(.systemBackground))
    .cornerRadius(16)
    .shadow(radius: 10)
  }

  // MARK: Private

  private func formatBytes(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
  }
}

// MARK: - DiskSpaceAlertManager

@MainActor
class DiskSpaceAlertManager: ObservableObject {
  // MARK: Lifecycle

  private init() { }

  // MARK: Internal

  static let shared = DiskSpaceAlertManager()

  @Published var isShowing = false
  @Published var requiredSpace = 0
  @Published var availableSpace = 0

  func showAlert(required: Int, available: Int) {
    requiredSpace = required
    availableSpace = available
    isShowing = true
  }

  func dismiss() {
    isShowing = false
  }
}

// MARK: - DiskSpaceAlertModifier

struct DiskSpaceAlertModifier: ViewModifier {
  // MARK: Internal

  func body(content: Content) -> some View {
    content
      .overlay(
        Group {
          if alertManager.isShowing {
            ZStack {
              // Background overlay
              Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                  alertManager.dismiss()
                }

              // Alert content
              DiskSpaceAlertView(
                requiredSpace: alertManager.requiredSpace,
                availableSpace: alertManager.availableSpace,
                onDismiss: {
                  alertManager.dismiss()
                },
                onRetry: {
                  alertManager.dismiss()
                  // Retry logic would be handled by the caller
                })
                .padding(.horizontal, 20)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: alertManager.isShowing)
          }
        })
  }

  // MARK: Private

  @StateObject private var alertManager = DiskSpaceAlertManager.shared
}

// MARK: - View Extension

extension View {
  func diskSpaceAlert() -> some View {
    modifier(DiskSpaceAlertModifier())
  }
}

// MARK: - DiskSpaceAlertView_Previews

struct DiskSpaceAlertView_Previews: PreviewProvider {
  static var previews: some View {
    DiskSpaceAlertView(
      requiredSpace: 100 * 1024 * 1024, // 100 MB
      availableSpace: 50 * 1024 * 1024, // 50 MB
      onDismiss: { },
      onRetry: { })
      .previewLayout(.sizeThatFits)
      .padding()
  }
}
