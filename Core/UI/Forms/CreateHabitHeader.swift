import SwiftUI

struct CreateHabitHeader: View {
  @ObservedObject private var localizationManager = LocalizationManager.shared

  // MARK: Lifecycle

  init(
    stepNumber: Int,
    onCancel: @escaping () -> Void,
    title: String = "Create Habit",
    subtitle: String = "" // "Let's get started!"
  ) {
    self.stepNumber = stepNumber
    self.onCancel = onCancel
    self.title = title
    self.subtitle = subtitle
  }

  // MARK: Internal

  let stepNumber: Int
  let onCancel: () -> Void
  let title: String
  let subtitle: String

  var body: some View {
    VStack(spacing: 0) {
      // Progress indicator and Cancel button on same row
      ZStack {
        // Bottom layer: Progress indicator - truly centered
        HStack {
          Spacer()
          HStack(spacing: 0) {
            Rectangle()
              .fill(.primaryDim)
              .frame(width: 32, height: 8)
            Rectangle()
              .fill(stepNumber >= 2 ? .primaryDim : .surfaceContainer)
              .frame(width: 32, height: 8)
          }
          .frame(width: 64, height: 8)
          .clipShape(RoundedRectangle(cornerRadius: 4))
          Spacer()
        }
        
        // Top layer: Cancel button - right aligned
        HStack {
          Spacer()
          Button("common.cancel".localized) {
            onCancel()
          }
          .foregroundColor(.blue)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 16)

      // Header
      VStack(alignment: .leading, spacing: 8) {
        Text("create.title".localized)
          .font(.appHeadlineMediumEmphasised)
          .foregroundColor(.text01)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.top, 28)
      .padding(.bottom, 20)
    }
  }
}

#Preview {
  VStack {
    CreateHabitHeader(
      stepNumber: 1,
      onCancel: { })

    CreateHabitHeader(
      stepNumber: 2,
      onCancel: { })
  }
}
