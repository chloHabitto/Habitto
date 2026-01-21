import SwiftUI

// MARK: - TermsConditionsView

struct TermsConditionsView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Description text
        Text("Terms of Service and Privacy Policy")
          .font(.appBodyMedium)
          .foregroundColor(.text05)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 20)
          .padding(.top, 8)
          .padding(.bottom, 8)

        // Custom Tab Bar for Terms & Conditions (no background)
        customTabBar

      // Tab Content
      TabView(selection: $selectedTab) {
        // Terms of Service Tab
        termsTab
          .tag(0)

        // Privacy Policy Tab
        privacyTab
          .tag(1)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
      }
      .background(Color.surface2)
      .navigationTitle("Terms & Conditions")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 14, weight: .heavy))
              .foregroundColor(.appInverseSurface70)
              .foregroundColor(.text01)
          }
        }
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var selectedTab: Int
  @State private var expandedSections: Set<String> = []
  
  init(initialTab: Int = 0) {
    _selectedTab = State(initialValue: initialTab)
  }

  /// Terms & Conditions data
  private let termsData = [
    TermsSection(
      title: "1. Acceptance of Terms",
      content: "By downloading, installing, or using the Habitto mobile application ('App'), you agree to be bound by these Terms and Conditions ('Terms'). If you do not agree to these Terms, do not use the App. These Terms apply to all users of the App, including without limitation users who are browsers, vendors, customers, merchants, and/or contributors of content.\n\nYou must be at least 13 years old to use the App. If you are under 18, you must have your parent or guardian's permission to use the App and agree to these Terms."),
    TermsSection(
      title: "2. App Description & Services",
      content: "Habitto is a habit tracking and personal development application designed to help users build positive habits, track their progress, and achieve personal goals. The App provides features including but not limited to:\n\n• Habit creation and management\n• Progress tracking and analytics\n• Streak counting and motivation\n• Goal setting and monitoring\n• Data visualization and insights\n\nWe reserve the right to modify, suspend, or discontinue any part of the App at any time without notice."),
    TermsSection(
      title: "3. User Accounts & Data",
      content: "You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. You agree to:\n\n• Provide accurate and complete information\n• Keep your account secure\n• Notify us immediately of any unauthorized use\n• Accept responsibility for all activities under your account\n\nWe collect and process personal data in accordance with our Privacy Policy. By using the App, you consent to such processing and warrant that all data provided is accurate."),
    TermsSection(
      title: "4. Acceptable Use",
      content: "You agree to use the App only for lawful purposes and in accordance with these Terms. You agree not to:\n\n• Use the App for any illegal or unauthorized purpose\n• Attempt to gain unauthorized access to the App or its systems\n• Interfere with or disrupt the App's functionality\n• Upload or transmit harmful, offensive, or inappropriate content\n• Violate any applicable laws or regulations\n• Use the App to harass, abuse, or harm others\n\nViolation of these terms may result in account termination and legal action."),
    TermsSection(
      title: "5. Health & Medical Disclaimers",
      content: "IMPORTANT: Habitto is designed for general wellness and habit tracking purposes only. The App is NOT intended to:\n\n• Provide medical advice, diagnosis, or treatment\n• Replace professional medical consultation\n• Guarantee specific health outcomes\n• Treat or prevent any medical conditions\n\n• Always consult with qualified healthcare professionals for medical concerns\n• Do not rely on the App for medical decisions\n• The App is not a substitute for professional medical care\n• Results may vary and are not guaranteed\n\nBy using the App, you acknowledge that you are responsible for your own health decisions and will consult healthcare professionals when appropriate."),
    TermsSection(
      title: "6. Intellectual Property",
      content: "The App and its original content, features, and functionality are owned by Habitto and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.\n\nYou may not:\n• Copy, modify, or distribute the App\n• Reverse engineer or decompile the App\n• Remove or alter copyright notices\n• Use Habitto trademarks without permission\n\nUser-generated content remains your property, but you grant us a license to use it for App functionality and improvement."),
    TermsSection(
      title: "7. Limitation of Liability",
      content: "TO THE MAXIMUM EXTENT PERMITTED BY LAW, HABITTO SHALL NOT BE LIABLE FOR:\n\n• Indirect, incidental, or consequential damages\n• Loss of profits, data, or business opportunities\n• Damages resulting from App use or inability to use\n• Third-party actions or content\n• Service interruptions or data loss\n\nOur total liability shall not exceed the amount you paid for the App, if any.\n\nThis limitation applies to all claims, whether based on contract, tort, negligence, or other legal theories."),
    TermsSection(
      title: "8. Termination",
      content: "These Terms remain in effect until terminated:\n\n• You may terminate by deleting the App and ceasing use\n• We may terminate or suspend access immediately for Terms violations\n• Upon termination, your right to use the App ceases\n• We may delete or retain your data as permitted by law\n• Surviving provisions remain in effect\n\nTermination does not affect any rights or obligations that arose before termination."),
    TermsSection(
      title: "9. Governing Law & Disputes",
      content: "These Terms are governed by the laws of the Netherlands. Any disputes shall be resolved in the courts of the Netherlands.\n\nBefore pursuing legal action, we encourage you to contact us at chloe@habitto.nl to resolve issues amicably.\n\nIf any provision of these Terms is found to be unenforceable, the remaining provisions remain in full force and effect.")
  ]

  /// Privacy Policy data
  private let privacyData = [
    TermsSection(
      title: "1. Information We Collect",
      content: "We collect information you provide directly to us and information we obtain automatically when you use the App:\n\n**Information You Provide:**\n• Account information (email, name)\n• Habit data and goals\n• Progress tracking information\n• User preferences and settings\n\n**Information We Collect Automatically:**\n• App usage data and analytics\n• Device information (model, OS version)\n• Performance and crash data\n• Interaction patterns within the app"),
    TermsSection(
      title: "2. How We Use Your Information",
      content: "We use the information we collect to:\n\n• Provide, maintain, and improve the App\n• Personalize your experience and content\n• Track your progress and provide insights\n• Send you important updates and notifications\n• Analyze app usage to improve features\n• Ensure app security and prevent fraud\n• Comply with legal obligations\n\nWe do not sell, rent, or trade your personal information to third parties."),
    TermsSection(
      title: "3. Data Storage & Security",
      content: "Your data is stored securely using industry-standard practices:\n\n**Data Storage:**\n• Primary storage: Firebase Cloud Firestore\n• Local backup: Your device storage\n• Encryption: Data encrypted in transit and at rest\n\n**Security Measures:**\n• Secure authentication via Firebase Auth\n• Regular security audits and updates\n• Access controls and monitoring\n• Data backup and recovery procedures\n\n**Data Retention:**\n• Account data: Retained while account is active\n• Deleted accounts: Data removed within 30 days\n• Analytics data: Aggregated and anonymized"),
    TermsSection(
      title: "4. Third-Party Services",
      content: "We use third-party services to provide app functionality:\n\n**Firebase Services (Google):**\n• Authentication and user management\n• Cloud database for habit data\n• Analytics and crash reporting\n• Push notifications\n\n**Data Processing:**\n• All third-party services comply with GDPR\n• Data processing agreements in place\n• Limited to necessary app functionality\n• No additional data sharing beyond required services"),
    TermsSection(
      title: "5. Your Rights & Choices",
      content: "Under GDPR and other privacy laws, you have the right to:\n\n**Data Access:**\n• View all personal data we hold about you\n• Request a copy of your data in portable format\n• Understand how your data is processed\n\n**Data Control:**\n• Correct inaccurate or incomplete data\n• Request deletion of your personal data\n• Withdraw consent for data processing\n• Restrict processing of your data\n\n**Contact Us:**\n• Email: chloe@habitto.nl\n• Response time: Within 30 days\n• No fees for reasonable requests"),
    TermsSection(
      title: "6. Data Sharing & Disclosure",
      content: "We may share your information in these limited circumstances:\n\n**With Your Consent:**\n• When you explicitly agree to sharing\n• For specific features or integrations\n• With clear explanation of what's shared\n\n**Legal Requirements:**\n• To comply with applicable laws\n• In response to legal requests\n• To protect our rights and safety\n• To prevent fraud or abuse\n\n**Service Providers:**\n• Only for essential app functionality\n• Under strict data protection agreements\n• Limited to necessary data only"),
    TermsSection(
      title: "7. International Data Transfers",
      content: "Your data may be processed in countries outside your residence:\n\n**Data Locations:**\n• Primary: European Union (GDPR compliant)\n• Backup: United States (Firebase services)\n• Transfers: Protected by appropriate safeguards\n\n**Protection Measures:**\n• Standard Contractual Clauses (SCCs)\n• Adequacy decisions where applicable\n• Regular compliance monitoring\n• User notification of any changes"),
    TermsSection(
      title: "8. Children's Privacy",
      content: "We take children's privacy seriously:\n\n**Age Requirements:**\n• App is not intended for children under 13\n• We do not knowingly collect data from children under 13\n• Accounts must be created by users 13 or older\n\n**Parental Consent:**\n• Users 13-17 need parental permission\n• Parents can request data review or deletion\n• Contact us for parental control options"),
    TermsSection(
      title: "9. Updates to This Policy",
      content: "We may update this Privacy Policy from time to time:\n\n**Notification Process:**\n• Users notified of significant changes\n• Updates posted in the app\n• Email notification for major changes\n• 30-day advance notice when possible\n\n**Continued Use:**\n• Using the app after changes = acceptance\n• Review policy regularly for updates\n• Contact us with any questions\n• Previous versions available upon request"),
    TermsSection(
      title: "10. Contact Information",
      content: "For privacy-related questions or requests:\n\n**Primary Contact:**\n• Email: chloe@habitto.nl\n• Response time: Within 30 days\n• Language: English and Dutch\n\n**Data Protection Officer:**\n• Available for complex privacy matters\n• GDPR compliance questions\n• Data processing concerns\n\n**Complaints:**\n• We aim to resolve issues promptly\n• Contact us first for fastest resolution\n• Right to lodge complaint with supervisory authority")
  ]

  // MARK: - Custom Tab Bar (matches Habitto design without background)

  private var customTabBar: some View {
    HStack(alignment: .top, spacing: 0) {
      ForEach(0 ..< 2, id: \.self) { index in
        let title = index == 0 ? "Terms of Service" : "Privacy Policy"
        let isSelected = selectedTab == index

        Button(action: { selectedTab = index }) {
          VStack(spacing: 2) {
            Text(title)
              .font(.appTitleSmallEmphasised)
              .foregroundColor(isSelected ? .text03 : .text04)
              .padding(.horizontal, 16)
              .padding(.vertical, 12)
          }
          .frame(maxWidth: .infinity)
          .overlay(
            // Bottom stroke - only show for selected tabs, full width
            VStack {
              Spacer()
              Rectangle()
                .fill(.text03)
                .frame(height: 4)
            }
            .opacity(isSelected ? 1 : 0))
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity, alignment: .center)
      }
    }
    .padding(.top, 8)
    .overlay(
      // Bottom stroke for the entire tab bar
      VStack {
        Spacer()
        Rectangle()
          .fill(Color.outline3)
          .frame(height: 1)
      })
  }

  // MARK: - Terms of Service Tab

  private var termsTab: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        // Terms & Conditions List
        termsList

        // Last Updated
        lastUpdatedSection

        Spacer(minLength: 24)
      }
    }
  }

  // MARK: - Privacy Policy Tab

  private var privacyTab: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        // Privacy Policy List
        privacyList

        // Last Updated
        privacyLastUpdatedSection

        Spacer(minLength: 24)
      }
    }
  }

  // MARK: - Terms List

  private var termsList: some View {
    VStack(spacing: 0) {
      ForEach(termsData, id: \.title) { section in
        TermsSectionRow(
          section: section,
          isExpanded: expandedSections.contains(section.title),
          onTap: {
            toggleSection(section.title)
          })

        if section.title != termsData.last?.title {
          Divider()
            .background(Color.outline3)
            .padding(.leading, 20)
        }
      }
    }
    .background(Color.surface)
    .cornerRadius(16)
    .padding(.horizontal, 20)
    .padding(.top, 16) // Add 16px spacing above the list
  }

  // MARK: - Privacy Policy List

  private var privacyList: some View {
    VStack(spacing: 0) {
      ForEach(privacyData, id: \.title) { section in
        TermsSectionRow(
          section: section,
          isExpanded: expandedSections.contains(section.title),
          onTap: {
            toggleSection(section.title)
          })

        if section.title != privacyData.last?.title {
          Divider()
            .background(Color.outline3)
            .padding(.leading, 20)
        }
      }
    }
    .background(Color.surface)
    .cornerRadius(16)
    .padding(.horizontal, 20)
    .padding(.top, 16) // Add 16px spacing above the list
  }

  // MARK: - Last Updated Section (Terms)

  private var lastUpdatedSection: some View {
    VStack(spacing: 8) {
      Text("Last Updated: August 2025")
        .font(.appBodySmall)
        .foregroundColor(.text04)

      Text("For questions about these terms, contact us at chloe@habitto.nl")
        .font(.appBodySmall)
        .foregroundColor(.text04)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 20)
  }

  // MARK: - Last Updated Section (Privacy)

  private var privacyLastUpdatedSection: some View {
    VStack(spacing: 8) {
      Text("Last Updated: December 2024")
        .font(.appBodySmall)
        .foregroundColor(.text04)

      Text("For privacy questions, contact us at chloe@habitto.nl")
        .font(.appBodySmall)
        .foregroundColor(.text04)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 20)
  }

  // MARK: - Helper Functions

  private func toggleSection(_ title: String) {
    if expandedSections.contains(title) {
      // If clicking the same section, close it
      expandedSections.remove(title)
    } else {
      // If opening a new section, close any previously opened section first
      expandedSections.removeAll()
      // Then open the new section
      expandedSections.insert(title)
    }
  }
}

// MARK: - TermsSection

struct TermsSection {
  let title: String
  let content: String
}

// MARK: - TermsSectionRow

struct TermsSectionRow: View {
  let section: TermsSection
  let isExpanded: Bool
  let onTap: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Section Header Row
      Button(action: onTap) {
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text(section.title)
              .font(.appBodyLarge)
              .foregroundColor(.text01)
              .multilineTextAlignment(.leading)
          }

          Spacer()

          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.text04)
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
      }
      .buttonStyle(PlainButtonStyle())

      // Section Content (shown when expanded)
      if isExpanded {
        VStack(alignment: .leading, spacing: 12) {
          Divider()
            .background(Color.outline3)
            .padding(.horizontal, 20)

          Text(section.content)
            .font(.appBodyMedium)
            .foregroundColor(.text02)
            .multilineTextAlignment(.leading)
            .lineSpacing(4)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
      }
    }
  }
}

#Preview {
  TermsConditionsView()
}
