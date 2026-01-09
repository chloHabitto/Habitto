import SwiftUI

struct CustomRatingView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      ZStack(alignment: .bottom) {
        // Background
        Color("appSurface01Variant02")
          .ignoresSafeArea(.all)
        
        ScrollViewReader { proxy in
          ScrollView {
            VStack(spacing: 20) {
              // Header
              VStack(spacing: 16) {
                Image("Rate")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 120, height: 120)
              }
              .padding(.top, 20)

              // Star Rating
              VStack(spacing: 16) {
                Text("How would you rate your experience?")
                  .font(.appTitleLargeEmphasised)
                  .foregroundColor(.text04)

                HStack(spacing: 12) {
                  ForEach(1 ... maxRating, id: \.self) { index in
                    Button(action: {
                      selectedRating = index
                    }) {
                      Image("Icon-Star_Filled")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(index <= selectedRating ? .yellow : .gray)
                        .frame(width: 32, height: 32)
                    }
                    .buttonStyle(PlainButtonStyle())
                  }
                }

                if selectedRating > 0 {
                  Text(ratingText)
                    .font(.appBodyLarge)
                    .foregroundColor(.text05)
                    .multilineTextAlignment(.center)
                }
              }
              .padding(.horizontal, 20)

              // Comment Section
              VStack(alignment: .leading, spacing: 12) {
                Text("Share your thoughts (optional)")
                  .font(.appBodyMediumEmphasised)
                  .foregroundColor(.text04)

                VStack(alignment: .leading, spacing: 8) {
                  ZStack(alignment: .topLeading) {
                    TextEditor(text: $comment)
                      .font(.appBodyMedium)
                      .foregroundColor(.text01)
                      .scrollContentBackground(.hidden)
                      .padding(12)
                      .background(Color.surface01)
                      .overlay(
                        RoundedRectangle(cornerRadius: 16)
                          .stroke(
                            comment.count > maxCommentLength ? Color.red : Color.outline02,
                            lineWidth: 1.5))
                      .cornerRadius(16)
                      .frame(minHeight: 100)
                      .focused($isCommentFocused)
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
                      .font(.appBodySmall)
                      .foregroundColor(comment.count > maxCommentLength ? .red : .text06)
                  }
                }
              }
              .padding(.horizontal, 20)
              .padding(.top, 28) // Spacing of 48 total (20 from parent VStack + 28 padding)
              .padding(.bottom, isCommentFocused ? 300 : 120) // Extra padding when keyboard is visible
              .id("commentSection")
            }
          }
          .onChange(of: isCommentFocused) { _, isFocused in
            if isFocused {
              // Scroll to comment section when focused, with a slight delay to allow keyboard to appear
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                  proxy.scrollTo("commentSection", anchor: .center)
                }
              }
            }
          }
        }
        
        // Action Buttons at bottom
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
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
          VStack(spacing: 0) {
            Color("appSurface01Variant02")
              .frame(height: 1)
            LinearGradient(
              gradient: Gradient(colors: [
                Color("appSurface01Variant02").opacity(0),
                Color("appSurface01Variant02")
              ]),
              startPoint: .top,
              endPoint: .bottom
            )
            .frame(height: 20)
            Color("appSurface01Variant02")
          }
        )
      }
      .navigationTitle("Rate Us")
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
      .ignoresSafeArea(.keyboard, edges: .bottom)
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
  @FocusState private var isCommentFocused: Bool
  @State private var selectedRating = 5
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
