import SwiftUI

struct FAQView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var expandedQuestions: Set<String> = []
    
    // Sample FAQ data
    private let faqData = [
        FAQItem(
            question: "How do I create a new habit?",
            answer: "To create a new habit, go to the Habits tab and tap the '+' button. You can then set your habit name, description, schedule, and other preferences."
        ),
        FAQItem(
            question: "Can I change my habit schedule?",
            answer: "Yes! You can edit any habit by tapping on it in the Habits tab. From there, you can modify the schedule, goal, or any other settings."
        ),
        FAQItem(
            question: "How does the streak counter work?",
            answer: "The streak counter tracks how many consecutive days you've completed your habit. It resets to 0 if you miss a day, helping you stay motivated to maintain consistency."
        ),
        FAQItem(
            question: "What is Vacation Mode?",
            answer: "Vacation Mode allows you to pause your habits temporarily without losing your progress. Your streaks and data are preserved while you take a break."
        ),
        FAQItem(
            question: "How do I track my progress?",
            answer: "Your progress is automatically tracked in the Progress tab. You can see daily, weekly, and monthly views of how well you're doing with your habits."
        ),
        FAQItem(
            question: "Can I export my habit data?",
            answer: "Currently, habit data is stored locally on your device. We're working on cloud sync and export features for future updates."
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header with close button and left-aligned title
                ScreenHeader(
                    title: "FAQ",
                    description: "Frequently asked questions about Habitto"
                ) {
                    dismiss()
                }
                
                // Search Bar
                searchBar
                
                // FAQ Questions List
                faqQuestionsList
                
                Spacer(minLength: 24)
            }
        }
        .background(Color.surface2)
        .navigationBarHidden(true)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.text03)
            
            TextField("Search FAQ...", text: $searchText)
                .font(.appBodyMedium)
                .foregroundColor(.text01)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text03)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.surface)
                .stroke(Color.outline3, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - FAQ Questions List
    private var faqQuestionsList: some View {
        VStack(spacing: 0) {
            ForEach(faqData, id: \.question) { faqItem in
                FAQQuestionRow(
                    faqItem: faqItem,
                    isExpanded: expandedQuestions.contains(faqItem.question),
                    onTap: {
                        toggleQuestion(faqItem.question)
                    }
                )
                
                if faqItem.question != faqData.last?.question {
                    Divider()
                        .background(Color.outline3)
                        .padding(.leading, 20)
                }
            }
        }
        .background(Color.surface)
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Functions
    private func toggleQuestion(_ question: String) {
        if expandedQuestions.contains(question) {
            // If clicking the same question, close it
            expandedQuestions.remove(question)
        } else {
            // If opening a new question, close any previously opened question first
            expandedQuestions.removeAll()
            // Then open the new question
            expandedQuestions.insert(question)
        }
    }
}

// MARK: - FAQ Item Model
struct FAQItem {
    let question: String
    let answer: String
}

// MARK: - FAQ Question Row
struct FAQQuestionRow: View {
    let faqItem: FAQItem
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Question Row
            Button(action: onTap) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(faqItem.question)
                            .font(.appBodyLarge)
                            .foregroundColor(.text01)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.text02)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Answer (shown when expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .background(Color.outline3)
                        .padding(.horizontal, 20)
                    
                    Text(faqItem.answer)
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                        .multilineTextAlignment(.leading)
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
    FAQView()
        .environmentObject(AuthenticationManager.shared)
}
