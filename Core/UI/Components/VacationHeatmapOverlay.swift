import SwiftUI

struct VacationHeatmapOverlay: View {
  // MARK: Internal

  @EnvironmentObject var vacationManager: VacationManager

  var body: some View {
    if vacationManager.isActive {
      VStack(spacing: 8) {
        HStack(spacing: 6) {
          Image("Icon-Vacation")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16)
            .foregroundColor(.navy200)

          Text("Vacation Mode Active")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.navy200)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(.surface.opacity(0.9)))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

        if let current = vacationManager.current {
          Text("Progress paused until \(formatDate(current.start))")
            .font(.system(size: 10, weight: .regular))
            .foregroundColor(.text04)
            .multilineTextAlignment(.center)
        }
      }
    }
  }

  // MARK: Private

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
  }
}

#Preview {
  VacationHeatmapOverlay()
    .environmentObject(VacationManager.shared)
}
