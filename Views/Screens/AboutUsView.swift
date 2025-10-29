import SwiftUI

// MARK: - SectionCard

struct SectionCard: View {
  let icon: String
  let title: String
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.appTitleMedium)
          .foregroundColor(.primary)
          .frame(width: 24)

        Text(title)
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
      }

      Text(text)
        .font(.appBodyLarge)
        .foregroundColor(.text05)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(16)
    .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
  }
}

// MARK: - AboutUsView

struct AboutUsView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          // Description text
          Text("Better, together — one step at a time.")
            .font(.appBodyMedium)
            .foregroundColor(.text05)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)

          // Hanging image - full width outside VStack padding
        Image("Hanging")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: .infinity)
//                    .padding(.top, 16)
          .padding(.horizontal, -20) // Negative padding to counteract parent VStack padding
          .padding(.bottom, -32) // Negative bottom padding to reduce space to next section

        // Our Promise
        SectionCard(
          icon: "heart.circle.fill",
          title: "Our Promise",
          text: "We're here for the long run. This isn't a quick fix — it's a steady companion for your journey. We'll keep things simple, kind, and helpful, so you can keep moving forward no matter what life brings.")

        // The Real Goal
        SectionCard(
          icon: "figure.walk.motion",
          title: "The Real Goal",
          text: "Perfection isn't the plan. Life happens — you might miss a day, a week, or even a month. That's okay. What matters is returning, recommitting, and taking the next step.\nProgress over perfection, always.")

        // Focus on Yourself
        SectionCard(
          icon: "person.fill.checkmark",
          title: "Focus on Yourself",
          text: "This is not a competition. At the end of the day, it's you who has to change for yourself. Compare yourself only to who you were yesterday, not to others.\nIt doesn't matter how fast or slow someone else is going — your path is yours alone.\nFocus on yourself, with Habitto by your side.")

        // Why We Built This
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 12) {
            Image(systemName: "sparkles")
              .font(.appTitleMedium)
              .foregroundColor(.primary)
              .frame(width: 24)

            Text("Why We Built This")
              .font(.appTitleMediumEmphasised)
              .foregroundColor(.text01)
          }

          Text(
            "We've been where you are — starting fresh, full of motivation, then struggling to keep it going. We built Habitto to make that journey feel lighter, kinder, and more sustainable:")
            .font(.appBodyLarge)
            .foregroundColor(.text05)
            .fixedSize(horizontal: false, vertical: true)

          VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
              Text("•")
                .foregroundColor(.primary)
              Text("Clear tracking to see your progress")
                .font(.appBodyLarge)
                .foregroundColor(.text05)
            }
            HStack(alignment: .top, spacing: 8) {
              Text("•")
                .foregroundColor(.primary)
              Text("Gentle nudges to help you stay on track")
                .font(.appBodyLarge)
                .foregroundColor(.text05)
            }
            HStack(alignment: .top, spacing: 8) {
              Text("•")
                .foregroundColor(.primary)
              Text("Space to start again anytime you need to")
                .font(.appBodyLarge)
                .foregroundColor(.text05)
            }
          }
          .padding(.leading, 8)
        }
        .padding(16)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))

        // Our Vision for the Future
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 12) {
            Image(systemName: "eye.fill")
              .font(.appTitleMedium)
              .foregroundColor(.primary)
              .frame(width: 24)

            Text("Our Vision for the Future")
              .font(.appTitleMediumEmphasised)
              .foregroundColor(.text01)
          }

          VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
              Text("•")
                .foregroundColor(.primary)
              Text("Grow with You — The app adapts as your life changes")
                .font(.appBodyLarge)
                .foregroundColor(.text05)
            }
            HStack(alignment: .top, spacing: 8) {
              Text("•")
                .foregroundColor(.primary)
              Text("Celebrate Progress — Every small step counts")
                .font(.appBodyLarge)
                .foregroundColor(.text05)
            }
            HStack(alignment: .top, spacing: 8) {
              Text("•")
                .foregroundColor(.primary)
              Text("Focus on the Process — Enjoy the journey, not just the result")
                .font(.appBodyLarge)
                .foregroundColor(.text05)
            }
            HStack(alignment: .top, spacing: 8) {
              Text("•")
                .foregroundColor(.primary)
              Text("Build Community — A place to learn, share, and be inspired")
                .foregroundColor(.text05)
            }
          }
          .padding(.leading, 8)
        }
        .padding(16)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))

        // Closing Note
        VStack(alignment: .leading, spacing: 8) {
          Text("Closing Note")
            .font(.appTitleMediumEmphasised)
            .foregroundColor(.text01)
          Text(
            "We're walking this path with you.\nThrough the ups, the downs, and everything in between — we'll keep getting better together.")
            .font(.appBodyLarge)
            .foregroundColor(.text04)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 24)
        .padding(.horizontal, 24)
        }
        .padding(.horizontal, 20)
      }
      .navigationTitle("About Us")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.visible, for: .navigationBar)
      .background(Color.surface2)
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
}

#Preview {
  NavigationView {
    AboutUsView()
  }
}
