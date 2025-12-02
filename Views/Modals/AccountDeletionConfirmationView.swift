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
            Text("This action cannot be undone")
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

              Text("Permanent Account Deletion")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

              Text(
                "Deleting your account will permanently remove all your data, habits, and progress. This action cannot be undone.")
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
                Text("Data to be Deleted")
                  .font(.headline)
                  .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                  HStack {
                    Image(systemName: "list.bullet")
                      .foregroundColor(.blue)
                    Text("Habits Created")
                    Spacer()
                    Text("\(preview.habitCount)")
                      .fontWeight(.semibold)
                  }

                  HStack {
                    Image(systemName: "clock.arrow.circlepath")
                      .foregroundColor(.green)
                    Text("Backups Available")
                    Spacer()
                    Text("\(preview.backupCount)")
                      .fontWeight(.semibold)
                  }

                  HStack {
                    Image(systemName: "envelope")
                      .foregroundColor(.orange)
                    Text("Account Email")
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
                Text("Re-registration")
                  .font(.headline)
                Spacer()
              }

              Text(
                "After deletion, you can create a new account with the same email address if you choose to. However, all your previous data will be permanently lost.")
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
              content: .text("Delete My Account"),
              action: {
                showingFinalConfirmation = true
              })
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
      }
      .background(Color.surface2)
      .navigationTitle("Delete Account")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.text01)
          }
        }
      }
    }
    .alert("Final Confirmation", isPresented: $showingFinalConfirmation) {
      Button("Cancel", role: .cancel) { }
      Button("Delete Account", role: .destructive) {
        Task {
          await performAccountDeletion()
        }
      }
    } message: {
      Text(
        "Are you absolutely sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.")
    }
    .alert("Deletion Error", isPresented: $showingErrorAlert) {
      Button("OK") {
        deletionService.deletionError = nil
        showingErrorAlert = false
      }
    } message: {
      Text(deletionService.deletionError ?? "An unknown error occurred")
    }
    .onChange(of: deletionService.deletionError) { _, newValue in
      showingErrorAlert = newValue != nil
    }
    .alert("Account Deleted Successfully", isPresented: $deletionSuccessful) {
      Button("OK") {
        dismiss()
      }
    } message: {
      Text(
        "Your account has been signed out and all local data has been cleared. You can now create a new account if desired.")
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
        deletionService.deletionError = "Your authentication session has expired. Please sign out and sign in again, then try deleting your account."
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
      let detailedError = """
      Account deletion failed: \(error.localizedDescription)

      Error details: \(String(describing: error))
      """

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
