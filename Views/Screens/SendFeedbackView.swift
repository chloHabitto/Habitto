import SwiftUI
import MessageUI

struct SendFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingEmailComposer = false
    @State private var showingMailAppAlert = false
    
    private let recipientEmail = "chloe@habitto.nl"
    private let emailSubject = "App Feedback"
    private let emailBody = "Hello, I'd like to share some feedback:\n\n"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header with close button and left-aligned title
                ScreenHeader(
                    title: "Send Feedback",
                    description: "Help us improve Habitto with your suggestions"
                ) {
                    dismiss()
                }
                
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
                        
                        Text("Share your thoughts, suggestions, or report any issues. Your feedback helps us make Habitto better for everyone.")
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
                            hugging: false
                        ) {
                            sendFeedback()
                        }
                        
                        Text("This will open your email app")
                            .font(.appCaptionMedium)
                            .foregroundColor(.text03)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 24)
            }
        }
        .background(Color.surface2)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEmailComposer) {
            EmailComposerView(
                recipient: recipientEmail,
                subject: emailSubject,
                body: emailBody,
                isPresented: $showingEmailComposer
            )
        }
        .alert("Open Mail App", isPresented: $showingMailAppAlert) {
            Button("Open Mail") {
                openMailApp()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Would you like to open the Mail app to send your feedback?")
        }
    }
    
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

// MARK: - Email Composer
struct EmailComposerView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setToRecipients([recipient])
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(body, isHTML: false)
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: EmailComposerView
        
        init(_ parent: EmailComposerView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            // Dismiss the mail composer
            parent.isPresented = false
            
            // Handle the result if needed
            switch result {
            case .sent:
                print("📧 Email sent successfully")
            case .cancelled:
                print("📧 Email cancelled")
            case .saved:
                print("📧 Email saved as draft")
            case .failed:
                print("📧 Email failed to send: \(error?.localizedDescription ?? "Unknown error")")
            @unknown default:
                print("📧 Unknown email result")
            }
        }
    }
}

#Preview {
    SendFeedbackView()
        .environmentObject(AuthenticationManager.shared)
}
