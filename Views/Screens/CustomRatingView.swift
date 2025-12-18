import SwiftUI

struct CustomRatingView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          // Header
          VStack(spacing: 16) {
            Image(systemName: "star.fill")
              .font(.system(size: 48))
              .foregroundColor(.primary)

            Text("Rate Habitto")
              .font(.appTitleLarge)
              .foregroundColor(.text01)

            Text("Your feedback helps us improve the app for everyone")
              .font(.appBodyMedium)
              .foregroundColor(.text02)
              .multilineTextAlignment(.center)
          }
          .padding(.top, 20)

          // Star Rating
          VStack(spacing: 12) {
            Text("How would you rate your experience?")
              .font(.appBodyLarge)
              .foregroundColor(.text01)

            HStack(spacing: 8) {
              ForEach(1 ... maxRating, id: \.self) { index in
                Button(action: {
                  selectedRating = index
                }) {
                  Image(systemName: index <= selectedRating ? "star.fill" : "star")
                    .font(.system(size: 32))
                    .foregroundColor(index <= selectedRating ? .yellow : .gray)
                }
                .buttonStyle(PlainButtonStyle())
              }
            }

            if selectedRating > 0 {
              Text(ratingText)
                .font(.appBodyMedium)
                .foregroundColor(.text02)
                .multilineTextAlignment(.center)
            }
          }
          .padding(.horizontal, 20)

          // Comment Section
          VStack(alignment: .leading, spacing: 12) {
            Text("Share your thoughts (optional)")
              .font(.appBodyLarge)
              .foregroundColor(.text01)

            VStack(alignment: .leading, spacing: 8) {
              ZStack(alignment: .topLeading) {
                TextEditor(text: $comment)
                  .font(.appBodyMedium)
                  .foregroundColor(.text01)
                  .padding(12)
                  .background(Color.surface)
                  .overlay(
                    RoundedRectangle(cornerRadius: 8)
                      .stroke(
                        comment.count > maxCommentLength ? Color.red : Color.outline3,
                        lineWidth: 1))
                  .cornerRadius(8)
                  .frame(minHeight: 100)
                  .keyboardDoneButton()
                  .onChange(of: comment) { _, newValue in
                    // Limit comment length
                    if newValue.count > maxCommentLength {
                      comment = String(newValue.prefix(maxCommentLength))
                    }
                  }

                if comment.isEmpty {
                  Text("Tell us what you think about the app...")
                    .font(.appBodyMedium)
                    .foregroundColor(.text03)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
                }
              }

              HStack {
                Spacer()
                Text("\(comment.count)/\(maxCommentLength)")
                  .font(.appCaptionMedium)
                  .foregroundColor(comment.count > maxCommentLength ? .red : .text03)
              }
            }
          }
          .padding(.horizontal, 20)

          // Action Buttons
          VStack(spacing: 12) {
            HabittoButton(
              size: .large,
              style: .fillPrimary,
              content: .text("Submit Review"),
              hugging: false)
            {
              submitReview()
            }
            .disabled(selectedRating == 0)

            Button("Skip for now") {
              dismiss()
            }
            .font(.appBodyMedium)
            .foregroundColor(.text02)
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 20)
        }
      }
      .background(Color.sheetBackground)
      .navigationTitle("Rate App")
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
    .alert("Open App Store", isPresented: $showingAppStore) {
      Button("Open App Store") {
        openAppStore()
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text(
        "We'll open the App Store where you can submit your review with your rating and comments.")
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var selectedRating = 0
  @State private var comment = ""
  @State private var showingAppStore = false

  private let maxRating = 5
  private let maxCommentLength = 500

  private var ratingText: String {
    switch selectedRating {
    case 1:
      "Poor - We're sorry to hear that"
    case 2:
      "Fair - We'll work to improve"
    case 3:
      "Good - Thanks for the feedback"
    case 4:
      "Great - We're glad you like it"
    case 5:
      "Excellent - Thank you so much!"
    default:
      ""
    }
  }

  // MARK: - Helper Methods

  private func submitReview() {
    // Store the rating and comment locally (optional)
    storeRatingLocally()

    // Open App Store for actual review submission
    showingAppStore = true
  }

  private func storeRatingLocally() {
    // Store rating and comment in UserDefaults for analytics
    UserDefaults.standard.set(selectedRating, forKey: "UserRating")
    UserDefaults.standard.set(comment, forKey: "UserComment")
    UserDefaults.standard.set(Date(), forKey: "RatingDate")

    print(
      "⭐ CustomRatingView: Stored rating: \(selectedRating), comment: \(comment.isEmpty ? "none" : "\(comment.count) chars")")
  }

  private func openAppStore() {
    AppRatingManager.shared.openAppStoreForRating()
    dismiss()
  }
}

#Preview {
  CustomRatingView()
}
