import SwiftUI

// MARK: - AvatarSelectionView

struct AvatarSelectionView: View {
  // MARK: Lifecycle

  init() {
    // Initialize with current selected avatar
    _tempSelectedAvatar = State(initialValue: AvatarManager.shared.selectedAvatar)
  }

  // MARK: Internal

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Header
        VStack(spacing: 16) {
          Text("Choose Your Avatar")
            .font(.appTitleLarge)
            .foregroundColor(.text01)
            .multilineTextAlignment(.center)

          Text("Select an avatar to represent you in the app")
            .font(.appBodyMedium)
            .foregroundColor(.text02)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)

        // Avatar Grid
        ScrollView {
          LazyVGrid(columns: columns, spacing: 20) {
            ForEach(avatarManager.getAllAvatars()) { avatar in
              AvatarSelectionItem(
                avatar: avatar,
                isSelected: tempSelectedAvatar.id == avatar.id,
                size: avatarSize)
              {
                tempSelectedAvatar = avatar
              }
            }
          }
          .padding(.horizontal, 24)
          .padding(.vertical, 8)
        }

        Spacer()

        // Action Buttons
        VStack(spacing: 12) {
          // Save Button
          Button(action: saveAvatar) {
            HStack {
              Text("Save Avatar")
                .font(.appLabelLarge)
                .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.primary)
            .cornerRadius(25) // Pill-shaped
          }
          .buttonStyle(PlainButtonStyle())

          // Cancel Button
          Button(action: {
            dismiss()
          }) {
            Text("Cancel")
              .font(.appLabelLarge)
              .foregroundColor(.text02)
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .background(Color.surface)
              .cornerRadius(25) // Pill-shaped
              .overlay(
                RoundedRectangle(cornerRadius: 25)
                  .stroke(Color.text04, lineWidth: 1))
          }
          .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
      }
      .background(Color.surface)
      .navigationBarHidden(true)
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var avatarManager = AvatarManager.shared
  @State private var tempSelectedAvatar: Avatar

  // Grid configuration
  private let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 6)
  private let avatarSize: CGFloat = 50

  private func saveAvatar() {
    avatarManager.selectAvatar(tempSelectedAvatar)
    dismiss()
  }
}

// MARK: - AvatarSelectionItem

struct AvatarSelectionItem: View {
  let avatar: Avatar
  let isSelected: Bool
  let size: CGFloat
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      ZStack {
        // Avatar Image
        Image(avatar.imageName)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: size, height: size)
          .clipShape(Circle())
          .overlay(
            Circle()
              .stroke(
                isSelected ? Color.primary : Color.clear,
                lineWidth: isSelected ? 2.5 : 0))

        // Selection Indicator
        if isSelected {
          Circle()
            .stroke(Color.primary, lineWidth: 2.5)
            .frame(width: size + 8, height: size + 8)
            .overlay(
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .background(Color.surface)
                .clipShape(Circle())
                .offset(x: size / 2 - 6, y: -size / 2 + 6))
        }
      }
    }
    .buttonStyle(PlainButtonStyle())
    .scaleEffect(isSelected ? 1.1 : 1.0)
    .animation(.easeInOut(duration: 0.2), value: isSelected)
    .padding(4) // Add some padding around each item
  }
}

#Preview {
  AvatarSelectionView()
}
