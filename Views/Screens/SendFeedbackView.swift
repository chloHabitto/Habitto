import SwiftUI

struct SendFeedbackView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      ZStack {
        Color.surface2
          .ignoresSafeArea()

        VStack(spacing: 0) {
          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              // Feedback Content
              VStack(alignment: .leading, spacing: 24) {
                // Icon and description
                VStack(spacing: 16) {
                  Image("Sticker-Exciting")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180)

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
              }
              .padding(.horizontal, 20)
              .padding(.top, 24)
              .padding(.bottom, 24)
            }
          }

          Spacer()

          // Send Feedback Button at bottom of screen
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
          .padding(.horizontal, 20)
          .padding(.bottom, 20)
        }
      }
      .navigationTitle("Send Feedback")
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
