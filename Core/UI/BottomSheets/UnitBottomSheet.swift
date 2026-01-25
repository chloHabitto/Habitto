import SwiftUI

struct UnitBottomSheet: View {
  @ObservedObject private var localizationManager = LocalizationManager.shared

  // MARK: Internal

  let onClose: () -> Void
  let onUnitSelected: (String) -> Void
  let currentUnit: String

  var body: some View {
    BaseBottomSheet(
      title: "create.unit.title".localized,
      description: "create.unit.description".localized,
      onClose: onClose,
      useSimpleCloseButton: true,
      confirmButton: {
        if showingCustomUnitInput, !customUnit.isEmpty {
          onUnitSelected(customUnit)
        }
        onClose()
      },
      confirmButtonTitle: showingCustomUnitInput ? "create.unit.addCustom".localized : "create.button.select".localized)
    {
      VStack(spacing: 0) {
        if showingCustomUnitInput {
          // Custom unit input
          VStack(spacing: 16) {
            Text("create.unit.enterCustom".localized)
              .font(Font.appTitleMedium)
              .foregroundColor(.text01)
              .frame(maxWidth: .infinity, alignment: .leading)

            TextField("create.placeholder.customUnit".localized, text: $customUnit)
              .font(Font.appBodyLarge)
              .foregroundColor(.text01)
              .accentColor(.text01)
              .inputFieldStyle()
              .contentShape(Rectangle())
              .frame(minHeight: 48)
              .submitLabel(.done)

            Spacer()
          }
          .padding(.horizontal, 16)
          .padding(.top, 16)
        } else {
          // Predefined units grid
          LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8)
          {
            ForEach(predefinedUnits, id: \.self) { unit in
              Button(action: {
                onUnitSelected(unit)
                onClose()
              }) {
                Text(unit)
                  .font(Font.appBodyMedium)
                  .foregroundColor(currentUnit == unit ? .onPrimary : .text01)
                  .padding(.horizontal, 16)
                  .padding(.vertical, 12)
                  .frame(maxWidth: .infinity)
                  .background(currentUnit == unit ? ColorTokens.primary : .surfaceContainer)
                  .overlay(
                    RoundedRectangle(cornerRadius: 8)
                      .stroke(
                        currentUnit == unit ? ColorTokens.primary : .outline3,
                        lineWidth: 1))
                  .clipShape(RoundedRectangle(cornerRadius: 8))
              }
              .buttonStyle(PlainButtonStyle())
            }

            // Custom unit button
            Button(action: {
              showingCustomUnitInput = true
            }) {
              HStack(spacing: 4) {
                Image(systemName: "plus")
                  .font(Font.appLabelSmall)
                Text("create.unit.custom".localized)
                  .font(Font.appBodyMedium)
              }
              .foregroundColor(ColorTokens.primary)
              .padding(.horizontal, 16)
              .padding(.vertical, 12)
              .frame(maxWidth: .infinity)
              .background(.surfaceContainer)
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(ColorTokens.primary, lineWidth: 1))
              .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())
          }
          .padding(.horizontal, 16)
          .padding(.top, 16)
        }

        Spacer()
      }
    }
    .presentationDetents([.height(500), .large])
  }

  // MARK: Private

  @State private var customUnit = ""
  @State private var showingCustomUnitInput = false

  private let predefinedUnits = [
    "times", "steps", "m", "km", "mile", "sec", "min", "hr", "ml", "oz", "Cal", "g", "mg", "drink"
  ]
}

#Preview {
  UnitBottomSheet(
    onClose: { },
    onUnitSelected: { _ in },
    currentUnit: "times")
}
