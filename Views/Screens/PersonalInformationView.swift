import SwiftUI

struct PersonalInformationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var originalFirstName: String = ""
    @State private var originalLastName: String = ""
    @State private var originalEmail: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with close button and left-aligned title
                    ScreenHeader(
                        title: "Personal Information",
                        description: "Manage your personal details"
                    ) {
                        dismiss()
                    }
                    
                    // Profile Picture
                    VStack(spacing: 16) {
                        Image("Default-Profile@4x")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.primaryContainer, lineWidth: 3)
                            )
                    }
                    .padding(.top, 16)
                    
                    // Name and Email Fields
                    VStack(spacing: 16) {
                        // First Name Field
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
                                        .stroke(Color.outline3, lineWidth: 1.5)
                                )
                                .cornerRadius(12)
                        }
                        
                        // Last Name Field
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
                                        .stroke(Color.outline3, lineWidth: 1.5)
                                )
                                .cornerRadius(12)
                        }
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.appBodyMedium)
                                .foregroundColor(.text01)
                            
                            TextField("Enter email", text: $email)
                                .font(.appBodyLarge)
                                .foregroundColor(.text01)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(Color.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.outline3, lineWidth: 1.5)
                                )
                                .cornerRadius(12)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Save Button
                    VStack(spacing: 16) {
                        HabittoButton(
                            size: .large,
                            style: .fillPrimary,
                            content: .text("Save"),
                            hugging: false
                        ) {
                            saveChanges()
                        }
                        .disabled(!hasChanges)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
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
        .background(Color.surface2)
        .navigationBarHidden(true)
    }
    
    // MARK: - Helper Properties
    private var hasChanges: Bool {
        firstName != originalFirstName || 
        lastName != originalLastName || 
        email != originalEmail
    }
    
    // MARK: - Helper Functions
    private func loadUserData() {
        if let user = authManager.currentUser {
            firstName = user.displayName?.components(separatedBy: " ").first ?? ""
            lastName = user.displayName?.components(separatedBy: " ").dropFirst().joined(separator: " ") ?? ""
            email = user.email ?? ""
            
            // Store original values
            originalFirstName = firstName
            originalLastName = lastName
            originalEmail = email
        }
    }
    
    private func saveChanges() {
        // TODO: Implement save functionality
        print("Saving changes: \(firstName) \(lastName), \(email)")
        
        // Update original values after save
        originalFirstName = firstName
        originalLastName = lastName
        originalEmail = email
    }
}

#Preview {
    PersonalInformationView()
}
