import SwiftUI

/// Confirmation view for account deletion with data preview
struct AccountDeletionConfirmationView: View {
    
    // MARK: - Properties
    
    @StateObject private var deletionService = {
        print("🗑️ AccountDeletionConfirmationView: Creating AccountDeletionService")
        return AccountDeletionService()
    }()
    @Environment(\.dismiss) private var dismiss
    @State private var showingFinalConfirmation = false
    @State private var isDeleting = false
    @State private var deletionSuccessful = false
    
    // MARK: - Body
    
    var body: some View {
        print("🗑️ AccountDeletionConfirmationView: Body rendered")
        return NavigationView {
            VStack(spacing: 0) {
                // Header
                ScreenHeader(
                    title: "Delete Account",
                    description: "This action cannot be undone"
                ) {
                    dismiss()
                }
                
                Spacer().frame(height: 20)
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Warning Section
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            
                            Text("Permanent Account Deletion")
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text("Deleting your account will permanently remove all your data, habits, and progress. This action cannot be undone.")
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
                            
                            Text("After deletion, you can create a new account with the same email address if you choose to. However, all your previous data will be permanently lost.")
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
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.surface2)
        }
        .navigationBarHidden(true)
        .alert("Final Confirmation", isPresented: $showingFinalConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Account", role: .destructive) {
                Task {
                    await performAccountDeletion()
                }
            }
        } message: {
            Text("Are you absolutely sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.")
        }
        .alert("Deletion Error", isPresented: .constant(deletionService.deletionError != nil)) {
            Button("OK") {
                deletionService.deletionError = nil
            }
        } message: {
            Text(deletionService.deletionError ?? "An unknown error occurred")
        }
        .alert("Account Deleted Successfully", isPresented: $deletionSuccessful) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your account has been signed out and all local data has been cleared. You can now create a new account if desired.")
        }
    }
    
    // MARK: - Actions
    
    private func performAccountDeletion() async {
        isDeleting = true
        
        // Check if re-authentication is needed
        let isAuthFresh = await deletionService.checkAuthenticationFreshness()
        if !isAuthFresh {
            DispatchQueue.main.async {
                self.deletionService.deletionError = "Your authentication session has expired. Please sign out and sign in again, then try deleting your account."
                self.isDeleting = false
            }
            return
        }
        
        do {
            try await deletionService.deleteAccount()
            
            // Mark deletion as successful
            DispatchQueue.main.async {
                self.deletionSuccessful = true
                self.isDeleting = false
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
                self.deletionService.deletionError = detailedError
                self.isDeleting = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AccountDeletionConfirmationView()
}
