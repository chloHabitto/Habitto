import SwiftUI

// MARK: - TermsConditionsView

struct TermsConditionsView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Description text
        Text("more.terms.subtitle".localized)
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
      .navigationTitle("more.terms.title".localized)
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
  @MainActor
  private var termsData: [TermsSection] {
    [
      TermsSection(
        title: "more.terms.section1Title".localized,
        content: "more.terms.section1Content".localized),
      TermsSection(
        title: "more.terms.section2Title".localized,
        content: "more.terms.section2Content".localized),
      TermsSection(
        title: "more.terms.section3Title".localized,
        content: "more.terms.section3Content".localized),
      TermsSection(
        title: "more.terms.section4Title".localized,
        content: "more.terms.section4Content".localized),
      TermsSection(
        title: "more.terms.section5Title".localized,
        content: "more.terms.section5Content".localized),
      TermsSection(
        title: "more.terms.section6Title".localized,
        content: "more.terms.section6Content".localized),
      TermsSection(
        title: "more.terms.section7Title".localized,
        content: "more.terms.section7Content".localized),
      TermsSection(
        title: "more.terms.section8Title".localized,
        content: "more.terms.section8Content".localized),
      TermsSection(
        title: "more.terms.section9Title".localized,
        content: "more.terms.section9Content".localized)
    ]
  }

  /// Privacy Policy data
  @MainActor
  private var privacyData: [TermsSection] {
    [
      TermsSection(
        title: "more.privacy.section1Title".localized,
        content: "more.privacy.section1Content".localized),
      TermsSection(
        title: "more.privacy.section2Title".localized,
        content: "more.privacy.section2Content".localized),
      TermsSection(
        title: "more.privacy.section3Title".localized,
        content: "more.privacy.section3Content".localized),
      TermsSection(
        title: "more.privacy.section4Title".localized,
        content: "more.privacy.section4Content".localized),
      TermsSection(
        title: "more.privacy.section5Title".localized,
        content: "more.privacy.section5Content".localized),
      TermsSection(
        title: "more.privacy.section6Title".localized,
        content: "more.privacy.section6Content".localized),
      TermsSection(
        title: "more.privacy.section7Title".localized,
        content: "more.privacy.section7Content".localized),
      TermsSection(
        title: "more.privacy.section8Title".localized,
        content: "more.privacy.section8Content".localized),
      TermsSection(
        title: "more.privacy.section9Title".localized,
        content: "more.privacy.section9Content".localized),
      TermsSection(
        title: "more.privacy.section10Title".localized,
        content: "more.privacy.section10Content".localized)
    ]
  }

  // MARK: - Custom Tab Bar (matches Habitto design without background)

  private var customTabBar: some View {
    HStack(alignment: .top, spacing: 0) {
      ForEach(0 ..< 2, id: \.self) { index in
        let title = index == 0 ? "more.terms.termsOfService".localized : "more.privacyPolicy".localized
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
      Text("more.terms.lastUpdated".localized)
        .font(.appBodySmall)
        .foregroundColor(.text04)

      Text("more.terms.contact".localized)
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
      Text("more.privacy.lastUpdated".localized)
        .font(.appBodySmall)
        .foregroundColor(.text04)

      Text("more.privacy.contact".localized)
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
