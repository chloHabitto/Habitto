import SwiftUI

// MARK: - FAQView

struct FAQView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          // Description text
          Text("Frequently asked questions about Habitto")
            .font(.appBodyMedium)
            .foregroundColor(.text05)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)

          // Search Bar
        searchBar

        // FAQ Questions List
        faqQuestionsList

          Spacer(minLength: 24)
        }
      }
      .background(Color("appSurface01Variant02"))
      .navigationTitle("FAQ")
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
  @State private var searchText = ""
  @State private var expandedQuestions: Set<String> = []

  /// Sample FAQ data
  private let faqData = [
    FAQItem(
      question: "How do I create a new habit?",
      answer: "To create a new habit, go to the Habits tab and tap the '+' button. You can then set your habit name, description, schedule, and other preferences."),
    FAQItem(
      question: "Can I change my habit schedule?",
      answer: "Yes! You can edit any habit by tapping on it in the Habits tab. From there, you can modify the schedule, goal, or any other settings."),
    FAQItem(
      question: "How does the streak counter work?",
      answer: "The streak counter tracks how many consecutive days you've completed your habit. It resets to 0 if you miss a day, helping you stay motivated to maintain consistency."),
    FAQItem(
      question: "What is Vacation Mode?",
      answer: "Vacation Mode allows you to pause your habits temporarily without losing your progress. Your streaks and data are preserved while you take a break."),
    FAQItem(
      question: "How do I track my progress?",
      answer: "Your progress is automatically tracked in the Progress tab. You can see daily, weekly, and monthly views of how well you're doing with your habits."),
    FAQItem(
      question: "Can I export my habit data?",
      answer: "Currently, habit data is stored locally on your device. We're working on cloud sync and export features for future updates."),
    FAQItem(
      question: "Why can't I see my habit on the home screen?",
      answer: "Your habit might not appear on the home screen because:\n• It could be inactive (check the Inactive tab)\n• It's not scheduled for today\n• It's set for a different time of day")
  ]

  /// Filtered FAQ data based on search text
  private var filteredFaqData: [FAQItem] {
    if searchText.isEmpty {
      return faqData
    }
    return faqData.filter { item in
      item.question.localizedCaseInsensitiveContains(searchText) ||
      item.answer.localizedCaseInsensitiveContains(searchText)
    }
  }

  // MARK: - Search Bar

  private var searchBar: some View {
    HStack(spacing: 12) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.text05)

      ZStack(alignment: .leading) {
        // Placeholder text
        if searchText.isEmpty {
          Text("Search FAQ...")
            .font(.appBodyLarge)
            .foregroundColor(.text05)
        }
        // Actual text field
        TextField("", text: $searchText)
          .font(.appBodyLarge)
          .foregroundColor(.text01)
          .textFieldStyle(PlainTextFieldStyle())
      }

      if !searchText.isEmpty {
        Button(action: {
          searchText = ""
        }) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.text05)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.surface)
        .stroke(Color.outline02, lineWidth: 1.5))
    .padding(.horizontal, 20)
  }

  // MARK: - FAQ Questions List

  private var faqQuestionsList: some View {
    VStack(spacing: 0) {
      if filteredFaqData.isEmpty && !searchText.isEmpty {
        // Empty state when no search results found
        VStack(spacing: 0) {
          // Image
          Image("Habit-List-Empty-State@4x")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 120, height: 120)
          
          // Space 8
          Spacer()
            .frame(height: 8)
          
          // "No result found" text
          Text("No result found")
            .font(.appTitleLargeEmphasised)
            .foregroundColor(Color("appText04"))
            .multilineTextAlignment(.center)
          
          // "Try searching for something else instead" text
          Text("Try searching for something else instead")
            .font(.appBodyLarge)
            .foregroundColor(Color("appText05"))
            .multilineTextAlignment(.center)
          
          // Space 20
          Spacer()
            .frame(height: 20)
          
          // Contact Us button
          HabittoButton(
            size: .medium,
            style: .fillPrimary,
            content: .text("Contact Us"),
            hugging: false)
          {
            openContactUs()
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 20)
      } else if filteredFaqData.isEmpty {
        // Empty state when no search text (shouldn't happen, but handle gracefully)
        EmptyView()
      } else {
        ForEach(filteredFaqData, id: \.question) { faqItem in
          FAQQuestionRow(
            faqItem: faqItem,
            isExpanded: expandedQuestions.contains(faqItem.question),
            onTap: {
              toggleQuestion(faqItem.question)
            })

          if faqItem.question != filteredFaqData.last?.question {
            Divider()
              .background(Color("appOutline02Variant"))
              .padding(.leading, 20)
          }
        }
      }
    }
    .background(Color("appSurface02Variant"))
    .cornerRadius(24)
    .padding(.horizontal, 20)
  }

  // MARK: - Helper Functions

  private func toggleQuestion(_ question: String) {
    withAnimation(.easeInOut(duration: 0.25)) {
      if expandedQuestions.contains(question) {
        expandedQuestions.remove(question)
      } else {
        expandedQuestions.removeAll()
        expandedQuestions.insert(question)
      }
    }
  }

  private func openContactUs() {
    // Open email app with the same configuration as Send Feedback screen
    let recipientEmail = "chloe@habitto.nl"
    let emailSubject = "App Feedback"
    let emailBody = "Hello, I'd like to share some feedback:\n\n"
    
    let mailtoURL = "mailto:\(recipientEmail)?subject=\(emailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    
    if let url = URL(string: mailtoURL) {
      UIApplication.shared.open(url)
    }
  }
}

// MARK: - FAQItem

struct FAQItem {
  let question: String
  let answer: String
}

// MARK: - FAQQuestionRow

struct FAQQuestionRow: View {
  let faqItem: FAQItem
  let isExpanded: Bool
  let onTap: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Question Row
      Button(action: onTap) {
        HStack(spacing: 12) {
          Text(faqItem.question)
            .font(.appBodyLarge)
            .foregroundColor(.text01)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)

          Image(systemName: "chevron.down")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.appOutline03)
            .rotationEffect(.degrees(isExpanded ? -180 : 0))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
      }
      .buttonStyle(PlainButtonStyle())

      // Answer - always in view hierarchy, animates height smoothly
      VStack(alignment: .leading, spacing: 12) {
        Divider()
          .background(Color("appOutline02Variant"))
          .padding(.horizontal, 20)

        Text(faqItem.answer)
          .font(.appBodyMedium)
          .foregroundColor(.text02)
          .multilineTextAlignment(.leading)
          .padding(.horizontal, 20)
          .padding(.bottom, 16)
      }
      .frame(maxHeight: isExpanded ? nil : 0, alignment: .top)
      .clipped()
      .opacity(isExpanded ? 1 : 0)
    }
    .animation(.easeInOut(duration: 0.25), value: isExpanded)
  }
}

#Preview {
  FAQView()
    .environmentObject(AuthenticationManager.shared)
}
