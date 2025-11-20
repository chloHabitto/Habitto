// DISABLED: Sign-in functionality commented out for future use
/*
import SwiftUI

struct ForgotPasswordView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Header
        VStack(spacing: 16) {
          Image(systemName: "lock.rotation")
            .font(.system(size: 60))
            .foregroundColor(.green600)
            .padding(.top, 40)

          VStack(spacing: 8) {
            Text("Reset Password")
              .font(.system(size: 28, weight: .bold))
              .foregroundColor(.text01)

            Text("Enter your email address and we'll send you a link to reset your password")
              .font(.system(size: 16, weight: .regular))
              .foregroundColor(.text04)
              .multilineTextAlignment(.center)
          }
        }
        .padding(.horizontal, 24)

        Spacer()

        // Form
        VStack(spacing: 24) {
          // Email Field
          VStack(alignment: .leading, spacing: 8) {
            Text("Email")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.text01)

            TextField("Enter your email", text: $email)
              .textFieldStyle(CustomTextFieldStyle())
              .textContentType(.emailAddress)
              .keyboardType(.emailAddress)
              .autocapitalization(.none)
              .disableAutocorrection(true)
              .keyboardDoneButton()
          }

          // Reset Button
          Button(action: {
            handleResetPassword()
          }) {
            HStack(spacing: 12) {
              if isLoading {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
                  .scaleEffect(0.8)
              } else {
                Image(systemName: "paperplane")
                  .font(.system(size: 18, weight: .medium))
                  .foregroundColor(.white)
              }

              Text(isLoading ? "Sending..." : "Send Reset Link")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isFormValid ? Color.green600 : Color.grey400)
            .cornerRadius(12)
          }
          .disabled(!isFormValid || isLoading)

          // Back to Sign In
          Button("Back to Sign In") {
            dismiss()
          }
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.green600)
        }
        .padding(.horizontal, 24)

        Spacer()
      }
      .background(Color.surface)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Close") {
            dismiss()
          }
          .foregroundColor(.text04)
        }
      }
      .alert("Error", isPresented: $showError) {
        Button("OK") { }
      } message: {
        Text(errorMessage)
      }
      .overlay(
        Group {
          if showSuccess {
            VStack(spacing: 16) {
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green600)

              Text("Reset Link Sent!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.text01)

              Text("Check your email for a link to reset your password")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.text04)
                .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(Color.surface)
            .cornerRadius(16)
            .shadow(radius: 20)
            .transition(.scale.combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: showSuccess)
          }
        })
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @StateObject private var authManager = AuthenticationManager.shared

  @State private var email = ""
  @State private var isLoading = false
  @State private var showSuccess = false
  @State private var errorMessage = ""
  @State private var showError = false

  private var isFormValid: Bool {
    !email.isEmpty && authManager.isValidEmail(email)
  }

  private func handleResetPassword() {
    isLoading = true

    authManager.resetPassword(email: email) { result in
      DispatchQueue.main.async {
        isLoading = false
        switch result {
        case .success:
          showSuccess = true
          // Dismiss after showing success
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            dismiss()
          }

        case .failure(let error):
          errorMessage = error.localizedDescription
          showError = true
        }
      }
    }
  }
}

#Preview {
  ForgotPasswordView()
}
*/
