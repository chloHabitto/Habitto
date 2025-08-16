import SwiftUI
// Remove Firebase import since we're using EmailJS instead

/*
 NOTE: EmailJS Integration Status
 
 CURRENT IMPLEMENTATION:
 - Using EmailJS REST API directly via HTTP requests
 - This is the recommended approach for iOS apps since there's no official Swift SDK
 
 The REST API approach is documented and supported by EmailJS.
 We're using the /send endpoint with proper authentication.
 */

struct ContactUsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTopic: String = ""
    @State private var showingTopicDropdown: Bool = false
    @State private var email: String = ""
    @State private var description: String = ""

    @State private var showingExitConfirmation: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var isSubmitting: Bool = false
    @FocusState private var focusedField: Field?
    
    // Completion handler to return the email when form is submitted
    var onFormSubmit: ((String, Bool) -> Void)?
    
    // Enum to track focused field
    private enum Field {
        case email
        case description
    }
    
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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Header with close button and left-aligned title
                    ScreenHeader(
                        title: "Contact Us",
                        description: "Get in touch with our support team"
                    ) {
                        // Check if form has data before dismissing
                        if hasFormData {
                            showingExitConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                    
                    // Form Fields
                    formFields
                    
                    Spacer(minLength: 24)
                    
                    // Submit Button
                    submitButton
                }
            }
            .onChange(of: focusedField) { oldValue, newValue in
                if let newValue = newValue {
                    // Add a small delay to let the keyboard animation start
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newValue == .email ? "emailField" : "descriptionField", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color.surface2)
        .navigationBarHidden(true)

        .confirmationDialog(
            "Leave Contact Form?",
            isPresented: $showingExitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave Form", role: .destructive) {
                dismiss()
            }
            
            Button("Continue Editing", role: .cancel) { }
        } message: {
            Text("Your form data will not be saved. Are you sure you want to leave?")
        }

        .onTapGesture {
            hideKeyboard()
        }
        .onAppear {
            setupKeyboardNotifications()
        }
        .onDisappear {
            removeKeyboardNotifications()
        }
    }
    

    
    // MARK: - Form Fields
    private var formFields: some View {
        VStack(spacing: 24) {
            topicDropdown
            emailField
            descriptionField
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
                .focused($focusedField, equals: .email)
                .id("emailField")
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
                .focused($focusedField, equals: .description)
                .id("descriptionField")
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            hideKeyboard()
                        }
                        .font(.appBodyMedium)
                        .foregroundColor(.primary)
                    }
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
                content: .text(isSubmitting ? "Sending..." : "Submit"),
                state: (isFormValid && !isSubmitting) ? .default : .disabled
            ) {
                print("🔘 Submit button tapped!")
                print("📋 Form valid: \(isFormValid)")
                print("📝 Topic: \(selectedTopic)")
                print("📧 Email: \(email)")
                print("📄 Description: \(description)")
                
                Task {
                    await submitForm()
                }
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
    
    private var hasFormData: Bool {
        !selectedTopic.isEmpty || 
        !email.isEmpty || 
        !description.isEmpty
    }
    
        // MARK: - Actions
    private func submitForm() async {
        print("🚀 Starting form submission...")
        print("📝 Topic: \(selectedTopic)")
        print("📧 Email: \(email)")
        print("📄 Description: \(description)")
        
        await MainActor.run {
            isSubmitting = true
        }
        
        // Submit via EmailJS
        do {
            print("📧 Sending email via EmailJS...")
                    try await EmailService.shared.sendContactForm(
            topic: selectedTopic,
            userEmail: email,
            description: description,
            attachmentData: nil
        )
            
            print("✅ Email sent successfully!")
            
            // Return success through the completion handler and dismiss immediately
            await MainActor.run {
                print("📱 Calling completion handler with success...")
                onFormSubmit?(email, true)  // true = success
                print("🚪 Dismissing view...")
                dismiss()
            }
        } catch {
            print("❌ Error sending email: \(error)")
            // Return failure through the completion handler and dismiss
            await MainActor.run {
                print("📱 Calling completion handler with failure...")
                onFormSubmit?(email, false)  // false = failure
                print("🚪 Dismissing view...")
                dismiss()
            }
        }
        
        await MainActor.run {
            isSubmitting = false
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    

    
    private func handleFocusChange(_ newValue: Field?) {
        if let newValue = newValue {
            // Add a small delay to let the keyboard animation start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    // We'll handle scrolling through a different approach
                    // For now, just log the focus change
                    print("Focus changed to: \(newValue)")
                }
            }
        }
    }
    
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

#Preview {
    ContactUsView { email, success in
        if success {
            print("Form submitted successfully with email: \(email)")
        } else {
            print("Form submission failed for email: \(email)")
        }
    }
    .environmentObject(AuthenticationManager.shared)
}

// MARK: - Email Service (EmailJS)
class EmailService {
    static let shared = EmailService()
    
    // EmailJS configuration
    private let emailjsPublicKey = "qa1BMb84x0SbGibnR"
    private let emailjsPrivateKey = "IQQKVdqlppTv7VDpwIwS1"
    private let emailjsServiceID = "service_nrca57w"
    private let emailjsTemplateID = "template_lzizg33"
    
    private init() {}
    
    func sendContactForm(topic: String, userEmail: String, description: String, attachmentData: Data?) async throws {
        print("📧 EmailService: Starting email submission...")
        
        // Prepare email data with minimal, standard parameters
        let emailData: [String: Any] = [
            "to_name": "Chloe",
            "from_name": "Habitto User",
            "from_email": userEmail,
            "subject": topic,
            "message": description
        ]
        
        // Also try with template variable names that might match your template
        let alternativeEmailData: [String: Any] = [
            "to_name": "Chloe",
            "from_name": "Habitto User",
            "from_email": userEmail,
            "title": topic,  // Some templates use 'title' instead of 'subject'
            "message": description
        ]
        
        print("📧 Email data structure:")
        print("  - to_name: \(emailData["to_name"] ?? "nil")")
        print("  - from_name: \(emailData["from_name"] ?? "nil")")
        print("  - from_email: \(emailData["from_email"] ?? "nil")")
        print("  - subject: \(emailData["subject"] ?? "nil")")
        print("  - message: \(emailData["message"] ?? "nil")")
        
        print("📧 Alternative email data structure:")
        print("  - title: \(alternativeEmailData["title"] ?? "nil")")
        
        print("📊 Email data prepared: \(emailData)")
        print("📊 Alternative email data prepared: \(alternativeEmailData)")
        
        // Send email via EmailJS REST API using emailData (with 'subject' parameter)
        try await sendEmailViaEmailJSREST(emailData)
        
        print("✅ Email sent successfully to chloe@habitto.nl")
        print("📧 From: \(userEmail)")
        print("📝 Topic: \(topic)")
        print("📄 Message: \(description)")
    }
    
    private func sendEmailViaEmailJSREST(_ emailData: [String: Any]) async throws {
        print("📧 Sending email via EmailJS REST API...")
        
        // Create URL request - using the correct EmailJS REST API endpoint
        guard let url = URL(string: "https://api.emailjs.com/api/v1.0/email/send") else {
            throw EmailError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prepare the request data for EmailJS REST API
        let requestData: [String: Any] = [
            "service_id": emailjsServiceID,
            "template_id": emailjsTemplateID,
            "user_id": emailjsPublicKey,
            "private_key": emailjsPrivateKey,
            "template_params": emailData
        ]
        
        print("🔑 Using Public Key: \(emailjsPublicKey)")
        print("🔐 Using Private Key: \(emailjsPrivateKey)")
        print("📧 Using Service ID: \(emailjsServiceID)")
        print("📋 Using Template ID: \(emailjsTemplateID)")
        
        print("📤 Request data being sent: \(requestData)")
        print("📋 Template params: \(emailData)")
        
        // Convert data to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: requestData)
        request.httpBody = jsonData
        
        print("📤 Sending request to EmailJS...")
        print("📤 Request body: \(String(data: jsonData, encoding: .utf8) ?? "Unable to convert to string")")
        print("🌐 URL: \(url)")
        print("📋 Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("📋 Request data structure:")
        print("  - service_id: \(requestData["service_id"] ?? "nil")")
        print("  - template_id: \(requestData["template_id"] ?? "nil")")
        print("  - user_id: \(requestData["user_id"] ?? "nil")")
        print("  - private_key: \(requestData["private_key"] ?? "nil")")
        print("  - template_params: \(requestData["template_params"] ?? "nil")")
        
        // Send the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailError.invalidResponse
        }
        
        print("📥 EmailJS response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            print("✅ EmailJS request successful")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📋 EmailJS response: \(responseString)")
            }
        } else {
            print("❌ EmailJS request failed with status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📋 Error response: \(responseString)")
            }
            
            // Try to parse the error response as JSON for more details
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📋 Error JSON: \(errorJson)")
            }
            
            throw EmailError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Email Errors
    enum EmailError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case requestFailed(statusCode: Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .requestFailed(let statusCode):
                return "Request failed with status code: \(statusCode)"
            }
        }
    }
}
