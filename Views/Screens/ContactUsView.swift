import SwiftUI
import PhotosUI

struct ContactUsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTopic: String = ""
    @State private var showingTopicDropdown: Bool = false
    @State private var email: String = ""
    @State private var description: String = ""
    @State private var showingAttachmentPicker: Bool = false
    @State private var selectedMedia: PhotosPickerItem? = nil
    @State private var selectedMediaData: Data? = nil
    @State private var showingMediaOptions: Bool = false
    
    private let topicOptions = [
        "General Inquiry",
        "Technical Support", 
        "Feature Request",
        "Bug Report",
        "Account Issue",
        "Feedback",
        "Other"
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header with close button and left-aligned title
                ScreenHeader(
                    title: "Contact Us",
                    description: "Get in touch with our support team"
                ) {
                    dismiss()
                }
                
                // Form Fields
                formFields
                
                Spacer(minLength: 24)
                
                // Submit Button
                submitButton
            }
        }
        .background(Color.surface2)
        .navigationBarHidden(true)
        .photosPicker(
            isPresented: $showingAttachmentPicker,
            selection: $selectedMedia,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: selectedMedia) { oldValue, newValue in
            Task {
                if let newValue = newValue {
                    let data = try? await newValue.loadTransferable(type: Data.self)
                    await MainActor.run {
                        selectedMediaData = data
                    }
                } else {
                    await MainActor.run {
                        selectedMediaData = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Form Fields
    private var formFields: some View {
        VStack(spacing: 24) {
            topicDropdown
            emailField
            descriptionField
            attachmentSection
        }
        .zIndex(showingTopicDropdown ? 1 : 1)

    }
    
    // MARK: - Topic Dropdown
    private var topicDropdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Topic")
                .font(.appTitleSmallEmphasised)
                .foregroundColor(.text01)
            
            // Dropdown field with overlay
            Button(action: {
                showingTopicDropdown.toggle()
            }) {
                HStack {
                    Text(selectedTopic.isEmpty ? "Select a topic" : selectedTopic)
                        .font(.appBodyMedium)
                        .foregroundColor(selectedTopic.isEmpty ? .text05 : .text01)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.text05)
                        .rotationEffect(.degrees(showingTopicDropdown ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.surface)
                        .stroke(Color.outline3, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .overlay(
                // Dropdown options overlay
                Group {
                    if showingTopicDropdown {
                        VStack(spacing: 0) {
                            ForEach(topicOptions, id: \.self) { topic in
                                Button(action: {
                                    selectedTopic = topic
                                    showingTopicDropdown = false
                                }) {
                                    HStack {
                                        Text(topic)
                                            .font(.appBodyMedium)
                                            .foregroundColor(.text01)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(selectedTopic == topic ? Color.primary.opacity(0.1) : Color.surface)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if topic != topicOptions.last {
                                    Divider()
                                        .background(Color.outline3)
                                }
                            }
                        }
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.outline3, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .offset(y: 52)
                    }
                }
                , alignment: .topLeading
            )
            .zIndex(showingTopicDropdown ? 1000 : 1)
        }
        .padding(.horizontal, 20)
        .zIndex(showingTopicDropdown ? 1000 : 1)
    }
    
    // MARK: - Email Field
    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email")
                .font(.appTitleSmallEmphasised)
                .foregroundColor(.text01)
            
            TextField("Enter your email", text: $email)
                .font(.appBodyMedium)
                .foregroundColor(.text01)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.surface)
                        .stroke(Color.outline3, lineWidth: 1)
                )
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Description Field
    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.appTitleSmallEmphasised)
                .foregroundColor(.text01)
            
            TextField("Describe your inquiry or issue...", text: $description, axis: .vertical)
                .font(.appBodyMedium)
                .foregroundColor(.text01)
                .lineLimit(5...10)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.surface)
                        .stroke(Color.outline3, lineWidth: 1)
                )
                .frame(minHeight: 120)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Attachment Section
    private var attachmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attachment")
                .font(.appTitleSmallEmphasised)
                .foregroundColor(.text01)
            
            HStack(spacing: 12) {
                // Attachment Button
                Button(action: {
                    showingMediaOptions = true
                }) {
                    ZStack {
                        if let mediaData = selectedMediaData,
                           let uiImage = UIImage(data: mediaData) {
                            // Show selected image
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            // Black overlay with opacity 0.5
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 64, height: 64)
                            
                            // Close button
                            Button(action: {
                                selectedMedia = nil
                                selectedMediaData = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .offset(x: 16, y: -16) // Position in top-right corner
                        } else {
                            // Show plus icon for adding
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.surface)
                                .frame(width: 64, height: 64)
                            
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                                .foregroundColor(.outline3)
                                .frame(width: 64, height: 64)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.text05)
                                .padding(4)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .confirmationDialog("Add Media", isPresented: $showingMediaOptions) {
                    Button("Take Photo") {
                        // TODO: Implement camera functionality
                        print("Take photo tapped")
                    }
                    
                    Button("Choose from Library") {
                        showingAttachmentPicker = true
                    }
                    
                    if selectedMediaData != nil {
                        Button("Remove", role: .destructive) {
                            selectedMedia = nil
                            selectedMediaData = nil
                        }
                    }
                    
                    Button("Cancel", role: .cancel) { }
                }
                
                // Attachment Info
                VStack(alignment: .leading, spacing: 4) {
                    if selectedMediaData != nil {
                        Text("Photo/video attached")
                            .font(.appBodyMedium)
                            .foregroundColor(.text01)
                        
                        Text("Tap to change or remove")
                            .font(.appBodySmall)
                            .foregroundColor(.text05)
                    } else {
                        Text("Add photo or video")
                            .font(.appBodyMedium)
                            .foregroundColor(.text01)
                        
                        Text("Up to 1 file (optional)")
                            .font(.appBodySmall)
                            .foregroundColor(.text05)
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        VStack(spacing: 16) {
            HabittoButton(
                size: .large,
                style: .fillPrimary,
                content: .text("Submit"),
                state: isFormValid ? .default : .disabled
            ) {
                submitForm()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !selectedTopic.isEmpty && 
        !email.isEmpty && 
        !description.isEmpty
    }
    
    // MARK: - Actions
    private func submitForm() {
        // TODO: Implement form submission logic
        print("Submitting form with:")
        print("Topic: \(selectedTopic)")
        print("Email: \(email)")
        print("Description: \(description)")
        
        // For now, just dismiss the view
        dismiss()
    }
}

#Preview {
    ContactUsView()
        .environmentObject(AuthenticationManager.shared)
}
