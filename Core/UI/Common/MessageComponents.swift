import SwiftUI

// MARK: - ErrorMessage

struct ErrorMessage: View {
  let message: String

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 16))
        .foregroundColor(.error)

      Text(message)
        .font(.appBodyMedium)
        .foregroundColor(.errorText)
    }
  }
}

// MARK: - WarningMessage

struct WarningMessage: View {
  let message: String

  var body: some View {
    HStack(spacing: 8) {
      // TODO: Update icon and color for warning message
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 16))
        .foregroundColor(.warning)

      Text(message)
        .font(.appBodyMedium)
        .foregroundColor(.warning)
    }
  }
}

// MARK: - SuccessMessage

struct SuccessMessage: View {
  let message: String

  var body: some View {
    HStack(spacing: 8) {
      // TODO: Update icon and color for success message
      Image(systemName: "checkmark.circle")
        .font(.system(size: 16))
        .foregroundColor(.success)

      Text(message)
        .font(.appBodyMedium)
        .foregroundColor(.success)
    }
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 16) {
    ErrorMessage(message: "Please enter a number greater than 0")
    WarningMessage(message: "This is a warning message")
    SuccessMessage(message: "Successfully saved!")
  }
  .padding()
}
