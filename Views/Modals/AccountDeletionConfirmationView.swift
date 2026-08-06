import SwiftUI

/// Confirmation view for account deletion with data preview
struct AccountDeletionConfirmationView: View {
  // MARK: Internal

  // MARK: - Body

  var body: some View {
    print("🗑️ AccountDeletionConfirmationView: Body rendered")
    return NavigationView {
      VStack(spacing: 0) {
        // Content
        ScrollView {
          VStack(spacing: 24) {
            // Description text
            Text("more.accountDeletion.banner".localized)
              .font(.appBodyMedium)
              .foregroundColor(.text05)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 20)
              .padding(.top, 8)

            // Warning Section
            VStack(spacing: 16) {
              Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)

              Text("more.accountDeletion.headline".localized)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

              Text("more.accountDeletion.bodyWarning".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Data Preview
            if let preview = deletionService.getDeletionPreview() {
              VStack(spacing: 16) {
                Text("more.accountDeletion.previewTitle".localized)
                  .font(.headline)
                  .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                  HStack {
                    Image(systemName: "list.bullet")
                      .foregroundColor(.blue)
                    Text("more.accountDeletion.habitsCreated".localized)
                    Spacer()
                    Text("\(preview.habitCount)")
                      .fontWeight(.semibold)
                  }

                  HStack {
                    Image(systemName: "clock.arrow.circlepath")
                      .foregroundColor(.green)
                    Text("more.accountDeletion.backupsAvailable".localized)
                    Spacer()
                    Text("\(preview.backupCount)")
                      .fontWeight(.semibold)
                  }

                  HStack {
                    Image(systemName: "envelope")
                      .foregroundColor(.orange)
                    Text("more.accountDeletion.accountEmail".localized)
                    Spacer()
                    Text(preview.userEmail)
                      .fontWeight(.semibold)
                      .foregroundColor(.secondary)
                  }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
              }
            }

            // Re-registration Info
            VStack(spacing: 12) {
              HStack {
                Image(systemName: "info.circle.fill")
                  .foregroundColor(.blue)
                Text("more.accountDeletion.reregTitle".localized)
                  .font(.headline)
                Spacer()
              }

              Text("more.accountDeletion.reregBody".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
          }
          .padding(.horizontal, 20)
        }

        // Action Buttons
        VStack(spacing: 16) {
          if isDeleting {
            // Deletion Progress
            VStack(spacing: 12) {
              ProgressView(value: deletionService.deletionProgress)
                .progressViewStyle(LinearProgressViewStyle())

              Text(deletionService.deletionStatus)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
          } else {
            // Delete Account Button
            HabittoButton(
              size: .large,
              style: .fillDestructive,
              content: .text("more.accountDeletion.deleteMyAccount".localized),
              action: {
                showingFinalConfirmation = true
              })
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
      }
      .background(Color.surface2)
      .navigationTitle("more.account.deleteAccount".localized)
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 14, weight: .heavy))
              .foregroundColor(.appInverseSurface70)
              .foregroundColor(.text01)
          }
        }
      }
    }
    .alert("more.accountDeletion.finalConfirmationTitle".localized, isPresented: $showingFinalConfirmation) {
      Button("common.cancel".localized, role: .cancel) { }
      Button("more.account.deleteAccount".localized, role: .destructive) {
        Task {
          await performAccountDeletion()
        }
      }
    } message: {
      Text("more.accountDeletion.finalConfirmationMessage".localized)
    }
    .alert("more.accountDeletion.deletionErrorTitle".localized, isPresented: $showingErrorAlert) {
      Button("common.ok".localized) {
        deletionService.deletionError = nil
        showingErrorAlert = false
      }
    } message: {
      Text(deletionService.deletionError ?? "more.accountDeletion.unknownError".localized)
    }
    .onChange(of: deletionService.deletionError) { _, newValue in
      showingErrorAlert = newValue != nil
    }
    .alert("more.accountDeletion.successTitle".localized, isPresented: $deletionSuccessful) {
      Button("common.ok".localized) {
        dismiss()
      }
    } message: {
      Text("more.accountDeletion.successMessage".localized)
    }
  }

  // MARK: Private

  @StateObject private var deletionService = {
    print("🗑️ AccountDeletionConfirmationView: Creating AccountDeletionService")
    return AccountDeletionService()
  }()

  @Environment(\.dismiss) private var dismiss
  @State private var showingFinalConfirmation = false
  @State private var isDeleting = false
  @State private var deletionSuccessful = false
  @State private var showingErrorAlert = false

  private func performAccountDeletion() async {
    // Clear any previous errors
    DispatchQueue.main.async {
      deletionService.deletionError = nil
      showingErrorAlert = false
    }
    
    isDeleting = true

    // Check if re-authentication is needed
    let isAuthFresh = await deletionService.checkAuthenticationFreshness()
    if !isAuthFresh {
      DispatchQueue.main.async {
        deletionService.deletionError = "more.accountDeletion.authExpired".localized
        isDeleting = false
      }
      return
    }

    do {
      try await deletionService.deleteAccount()

      // Mark deletion as successful
      DispatchQueue.main.async {
        deletionSuccessful = true
        isDeleting = false
      }

      // Dismiss the view after showing success message
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        dismiss()
      }

    } catch {
      print("❌ AccountDeletionConfirmationView: Account deletion failed: \(error)")
      print("❌ Error details: \(error)")
      print("❌ Error localized description: \(error.localizedDescription)")

      // Set a more detailed error message for debugging
      let detailedError = String(
        format: "more.accountDeletion.failedDetail".localized,
        error.localizedDescription,
        String(describing: error))

      DispatchQueue.main.async {
        deletionService.deletionError = detailedError
        isDeleting = false
      }
    }
  }
}

// MARK: - Preview

#Preview {
  AccountDeletionConfirmationView()
}
