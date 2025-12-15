import SwiftUI

struct VacationStatusIndicator: View {
  @EnvironmentObject var vacationManager: VacationManager

  var body: some View {
    if vacationManager.isActive {
      Image("Icon-Vacation")
        .renderingMode(.template)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 16, height: 16)
        .foregroundColor(.navy200)
        .background(
          Circle()
            .fill(.surface)
            .frame(width: 20, height: 20))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
  }
}

#Preview {
  VacationStatusIndicator()
    .environmentObject(VacationManager.shared)
}
