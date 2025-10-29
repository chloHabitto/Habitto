import SwiftUI

struct SendFeedbackView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          // Description text
          Text("Help us improve Habitto with your suggestions")
            .font(.appBodyMedium)
            .foregroundColor(.text05)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)

          // Feedback Content
        VStack(alignment: .leading, spacing: 24) {
          // Icon and description
          VStack(spacing: 16) {
            Image(systemName: "envelope.fill")
              .font(.system(size: 48))
              .foregroundColor(.primary)

            Text("We'd love to hear from you!")
              .font(.appTitleMedium)
              .foregroundColor(.text01)

            Text(
              "Share your thoughts, suggestions, or report any issues. You can use Gmail, Mail, or any other email app you prefer.")
              .font(.appBodyMedium)
              .foregroundColor(.text02)
              .multilineTextAlignment(.leading)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          // Send Feedback Button
          VStack(spacing: 12) {
            HabittoButton(
              size: .large,
              style: .fillPrimary,
              content: .text("Send Email"),
              hugging: false)
            {
              sendFeedback()
            }

            Text("This will open your preferred email app")
              .font(.appCaptionMedium)
              .foregroundColor(.text03)
          }
        }
        .padding(.horizontal, 20)

          Spacer(minLength: 24)
        }
      }
      .background(Color.surface2)
      .navigationTitle("Send Feedback")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "chevron.left")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.text01)
          }
        }
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

  private let recipientEmail = "chloe@habitto.nl"
  private let emailSubject = "App Feedback"
  private let emailBody = "Hello, I'd like to share some feedback:\n\n"

  // MARK: - Helper Methods

  private func sendFeedback() {
    // Always use mailto: link to give users choice of email apps
    openMailApp()
  }

  private func openMailApp() {
    let mailtoURL = "mailto:\(recipientEmail)?subject=\(emailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

    if let url = URL(string: mailtoURL) {
      UIApplication.shared.open(url)
    }
  }
}

#Preview {
  SendFeedbackView()
    .environmentObject(AuthenticationManager.shared)
}
