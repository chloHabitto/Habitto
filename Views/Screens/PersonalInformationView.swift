import SwiftUI
import UIKit

struct PersonalInformationView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var authManager: AuthenticationManager
  @ObservedObject private var avatarManager = AvatarManager.shared

  @State private var firstName = ""
  @State private var lastName = ""
  @State private var email = ""
  @State private var originalFirstName = ""
  @State private var originalLastName = ""
  @State private var originalEmail = ""
  @State private var isSaving = false
  @State private var showingSuccessAlert = false
  @State private var showingErrorAlert = false
  @State private var errorMessage = ""

  var body: some View {
    NavigationView {
      contentView
        .navigationTitle("Personal Information")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
            Button(action: {
              dismiss()
            }) {
              Image(systemName: "xmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.text01)
            }
          }
        }
    }
    .alert("Success", isPresented: $showingSuccessAlert) {
      Button("OK") {
        dismiss()
      }
    } message: {
      Text("Your profile has been updated successfully.")
    }
    .alert("Error", isPresented: $showingErrorAlert) {
      Button("OK") { }
    } message: {
      Text(errorMessage)
    }
  }

  private var contentView: some View {
    ScrollView {
      VStack(spacing: 24) {
        // Description text
        Text("Manage your personal details")
          .font(.appBodyMedium)
          .foregroundColor(.text05)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 20)
          .padding(.top, 8)

        profilePictureSection
        formSection
        Spacer()
        saveButtonSection
      }
      .padding(.horizontal, 0)
      .padding(.top, 0)
      .padding(.bottom, 20)
    }
    .background(Color.surface2)
    .onAppear {
      loadUserData()
    }
  }

  private var profilePictureSection: some View {
    VStack(spacing: 16) {
      Group {
        if avatarManager.selectedAvatar.isCustomPhoto,
           let imageData = avatarManager.selectedAvatar.customPhotoData,
           let uiImage = UIImage(data: imageData)
        {
          Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
        } else {
          Image(avatarManager.selectedAvatar.imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
        }
      }
      .frame(width: 80, height: 80)
      .clipShape(Circle())
      .overlay(
        Circle()
          .stroke(Color.primaryContainer, lineWidth: 3))

      // Email display below profile image
      Text(email)
        .font(.appBodyLarge)
        .foregroundColor(.text02)
        .multilineTextAlignment(.center)
    }
    .padding(.top, 16)
  }

  private var formSection: some View {
    VStack(spacing: 16) {
      firstNameField
      lastNameField
    }
    .padding(.horizontal, 20)
  }

  private var firstNameField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("First Name")
        .font(.appBodyMedium)
        .foregroundColor(.text01)

      TextField("Enter first name", text: $firstName)
        .font(.appBodyLarge)
        .foregroundColor(.text01)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.surface)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.outline3, lineWidth: 1.5))
        .cornerRadius(12)
        .keyboardDoneButton()
    }
  }

  private var lastNameField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Last Name")
        .font(.appBodyMedium)
        .foregroundColor(.text01)

      TextField("Enter last name", text: $lastName)
        .font(.appBodyLarge)
        .foregroundColor(.text01)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.surface)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.outline3, lineWidth: 1.5))
        .cornerRadius(12)
        .keyboardDoneButton()
    }
  }

  private var saveButtonSection: some View {
    VStack(spacing: 16) {
      HabittoButton(
        size: .large,
        style: .fillPrimary,
        content: .text(isSaving ? "Saving..." : "Save"),
        hugging: false)
      {
        saveChanges()
      }
      .disabled(!hasChanges || isSaving)
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 20)
  }

  // MARK: - Helper Properties

  private var hasChanges: Bool {
    firstName != originalFirstName ||
      lastName != originalLastName
    // Email is disabled, so we don't check for email changes
  }

  // MARK: - Helper Functions

  private func loadUserData() {
    if let user = authManager.currentUser {
      firstName = user.displayName?.components(separatedBy: " ").first ?? ""
      lastName = user.displayName?.components(separatedBy: " ").dropFirst()
        .joined(separator: " ") ?? ""
      email = user.email ?? ""

      // Store original values
      originalFirstName = firstName
      originalLastName = lastName
      originalEmail = email
    }
  }

  private func saveChanges() {
    guard hasChanges else { return }

    isSaving = true

    // Create display name from first and last name
    let displayName = "\(firstName.trimmingCharacters(in: .whitespacesAndNewlines)) \(lastName.trimmingCharacters(in: .whitespacesAndNewlines))"
      .trimmingCharacters(in: .whitespacesAndNewlines)

    // Update user profile via AuthenticationManager
    authManager.updateUserProfile(
      displayName: displayName.isEmpty ? nil : displayName,
      photoURL: nil)
    { result in
      DispatchQueue.main.async {
        isSaving = false

        switch result {
        case .success:
          // Update original values after successful save
          originalFirstName = firstName
          originalLastName = lastName

          // Show success alert
          showingSuccessAlert = true

          print("✅ PersonalInformationView: Profile updated successfully")

        case .failure(let error):
          // Show error alert
          errorMessage = error.localizedDescription
          showingErrorAlert = true

          print(
            "❌ PersonalInformationView: Failed to update profile: \(error.localizedDescription)")
        }
      }
    }
  }
}

#Preview {
  PersonalInformationView()
}
