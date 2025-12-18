import PhotosUI
import SwiftUI

struct ContactUsView: View {
  // MARK: Internal

  // MARK: - Enums

  enum Field: Hashable {
    case email
    case description
  }

  var body: some View {
    NavigationView {
      ZStack {
        Color.surface2
          .ignoresSafeArea()

        VStack(spacing: 0) {
          ScrollViewReader { proxy in
            ScrollView {
              VStack(spacing: 0) {
                // Description text
                Text("We'd love to hear from you")
                  .font(.appBodyMedium)
                  .foregroundColor(.text05)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 20)
                  .padding(.top, 24)
                  .padding(.bottom, 16)

                // Form Content
                VStack(spacing: 24) {
                  topicDropdown
                  emailField
                  descriptionField
                }
                .padding(.bottom, 24)
              }
            }
            .onChange(of: focusedField) { _, newValue in
              if let field = newValue {
                withAnimation(.easeInOut(duration: 0.3)) {
                  proxy.scrollTo(field, anchor: .center)
                }
              }
            }
          }

          // Submit Button at bottom of screen
          VStack(spacing: 16) {
            HabittoButton(
              size: .large,
              style: .fillPrimary,
              content: .text(isSubmitting ? "Sending..." : "Submit"),
              state: (isFormValid && !isSubmitting) ? .default : .disabled)
            {
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
          .padding(.bottom, 20)
          .background(Color.sheetBackground)
        }
      }
      .navigationTitle("Contact Us")
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
    .onAppear {
      setupKeyboardNotifications()
    }
    .onDisappear {
      removeKeyboardNotifications()
    }
    .confirmationDialog(
      "Discard Changes?",
      isPresented: .constant(hasFormData && !showingSuccessMessage),
      titleVisibility: .visible)
    {
      Button("Discard", role: .destructive) {
        dismiss()
      }
      Button("Keep Editing", role: .cancel) { }
    } message: {
      Text("Your form data will not be saved if you close this screen.")
    }
    .overlay(
      // Success Message
      Group {
        if showingSuccessMessage {
          VStack {
            HStack {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
              Text("Message sent successfully!")
                .font(.appBodyMedium)
                .foregroundColor(.text01)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
              RoundedRectangle(cornerRadius: 20)
                .fill(Color.surface)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5))
            Spacer()
          }
          .transition(.move(edge: .top).combined(with: .opacity))
          .animation(.easeInOut(duration: 0.3), value: showingSuccessMessage)
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
              withAnimation {
                showingSuccessMessage = false
              }
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
              }
            }
          }
        }
      })
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var authenticationManager: AuthenticationManager

  // MARK: - State Variables

  @State private var selectedTopic = ""
  @State private var email = ""
  @State private var description = ""
  @State private var showingTopicDropdown = false
  @State private var isSubmitting = false
  @State private var showingSuccessMessage = false

  // MARK: - Focus State

  @FocusState private var focusedField: Field?

  // MARK: - Keyboard State

  @State private var keyboardHeight: CGFloat = 0

  // MARK: - Constants

  private let topicOptions = [
    "General Inquiry",
    "Technical Support",
    "Feature Request",
    "Bug Report",
    "Account Issue",
    "Other"
  ]

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

  // MARK: - Topic Dropdown

  private var topicDropdown: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Topic")
        .font(.appTitleSmallEmphasised)
        .foregroundColor(.text01)

      ZStack(alignment: .topLeading) {
        // Main Button
        Button(action: {
          withAnimation(.easeInOut(duration: 0.2)) {
            showingTopicDropdown.toggle()
          }
        }) {
          HStack {
            Text(selectedTopic.isEmpty ? "Select a topic" : selectedTopic)
              .font(.appBodyMedium)
              .foregroundColor(selectedTopic.isEmpty ? .text03 : .text01)

            Spacer()

            Image(systemName: "chevron.down")
              .font(.caption)
              .foregroundColor(.text02)
              .rotationEffect(.degrees(showingTopicDropdown ? 180 : 0))
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.surface)
              .stroke(Color.outline3, lineWidth: 1))
        }

        // Dropdown Options
        if showingTopicDropdown {
          VStack(spacing: 0) {
            ForEach(topicOptions, id: \.self) { option in
              Button(action: {
                selectedTopic = option
                withAnimation(.easeInOut(duration: 0.2)) {
                  showingTopicDropdown = false
                }
              }) {
                HStack {
                  Text(option)
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)

                  Spacer()

                  if selectedTopic == option {
                    Image(systemName: "checkmark")
                      .font(.caption)
                      .foregroundColor(.primary)
                  }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                  RoundedRectangle(cornerRadius: 20)
                    .fill(selectedTopic == option ? Color.primary.opacity(0.1) : Color.surface))
                .overlay(
                  RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.outline3, lineWidth: 1))
              }
              .buttonStyle(PlainButtonStyle())

              if option != topicOptions.last {
                Divider()
                  .padding(.horizontal, 16)
              }
            }
          }
          .background(
            RoundedRectangle(cornerRadius: 20)
              .fill(Color.surface)
              .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5))
          .overlay(
            RoundedRectangle(cornerRadius: 20)
              .stroke(Color.outline3, lineWidth: 1))
          .offset(y: 50)
          .zIndex(1000)
        }
      }
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
            .stroke(Color.outline3, lineWidth: 1))
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
        .lineLimit(5 ... 10)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(Color.surface)
            .stroke(Color.outline3, lineWidth: 1))
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

  // MARK: - Form Submission

  private func submitForm() async {
    guard isFormValid else {
      print("❌ Form validation failed")
      return
    }

    await MainActor.run {
      isSubmitting = true
    }

    do {
      // TODO: Implement email functionality later
      print("📧 Contact form submitted (email functionality to be implemented)")
      print("📝 Topic: \(selectedTopic)")
      print("📧 Email: \(email)")
      print("📄 Description: \(description)")

      // Simulate network delay
      try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

      await MainActor.run {
        isSubmitting = false
        showingSuccessMessage = true
      }

      print("✅ Contact form submitted successfully!")

    } catch {
      await MainActor.run {
        isSubmitting = false
      }
      print("❌ Contact form submission failed: \(error)")
    }
  }

  // MARK: - Keyboard Management

  private func setupKeyboardNotifications() {
    NotificationCenter.default.addObserver(
      forName: UIResponder.keyboardWillShowNotification,
      object: nil,
      queue: .main)
    { notification in
      if let keyboardFrame = notification
        .userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
      {
        keyboardHeight = keyboardFrame.height
      }
    }

    NotificationCenter.default.addObserver(
      forName: UIResponder.keyboardWillHideNotification,
      object: nil,
      queue: .main)
    { _ in
      keyboardHeight = 0
    }
  }

  private func removeKeyboardNotifications() {
    NotificationCenter.default.removeObserver(self)
  }

  private func hideKeyboard() {
    focusedField = nil
  }
}
