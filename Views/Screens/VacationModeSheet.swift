import SwiftUI

struct VacationModeSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var vacationManager: VacationManager

  @State private var excludeToday = false
  @State private var showingEndVacationAlert = false

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Header
        VStack(spacing: 16) {
          HStack {
            Image("Icon-Vacation")
              .renderingMode(.template)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 32, height: 32)
              .foregroundColor(.navy200)

            VStack(alignment: .leading, spacing: 4) {
              Text("Vacation Mode")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.text01)

              Text(vacationManager.isActive ? "Currently paused" : "Pause all habits")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.text04)
            }

            Spacer()

            // Vacation Mode Toggle
            VStack(alignment: .trailing, spacing: 4) {
              Toggle("", isOn: Binding(
                get: { vacationManager.isActive },
                set: { isOn in
                  if isOn {
                    startVacation()
                  } else {
                    showingEndVacationAlert = true
                  }
                }))
                .toggleStyle(SwitchToggleStyle(tint: .primary))

              Text(vacationManager.isActive ? "ON" : "OFF")
                .font(.caption2)
                .foregroundColor(.text04)
            }
          }
          .padding(.horizontal, 20)
          .padding(.top, 20)

          // Divider
          Rectangle()
            .fill(Color.grey100)
            .frame(height: 1)
            .padding(.horizontal, 20)
        }

        // Content
        VStack(spacing: 24) {
          if !vacationManager.isActive {
            // Start Vacation Section
            VStack(alignment: .leading, spacing: 16) {
              Text("Start Vacation")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.text01)

              VStack(spacing: 12) {
                // Exclude Today Toggle
                HStack {
                  VStack(alignment: .leading, spacing: 4) {
                    Text("Exclude today")
                      .font(.system(size: 16, weight: .medium))
                      .foregroundColor(.text01)

                    Text("Start vacation from tomorrow")
                      .font(.system(size: 14, weight: .regular))
                      .foregroundColor(.text04)
                  }

                  Spacer()

                  Toggle("", isOn: $excludeToday)
                    .toggleStyle(SwitchToggleStyle(tint: .primary))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.surface)
                .cornerRadius(12)

                // Start Button
                Button(action: startVacation) {
                  HStack {
                    Image("Icon-Vacation")
                      .renderingMode(.template)
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .frame(width: 20, height: 20)

                    Text("Start Vacation")
                      .font(.system(size: 16, weight: .semibold))
                  }
                  .foregroundColor(.white)
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 16)
                  .background(Color.primary)
                  .cornerRadius(12)
                }
                .padding(.horizontal, 20)
              }
            }
            .padding(.horizontal, 20)
          } else {
            // End Vacation Section
            VStack(alignment: .leading, spacing: 16) {
              Text("End Vacation")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.text01)

              if let current = vacationManager.current {
                VStack(alignment: .leading, spacing: 8) {
                  Text("Started on")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.text04)

                  Text(formatDate(current.start))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.text01)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.surface)
                .cornerRadius(12)
                .padding(.horizontal, 20)
              }

              // End Button
              Button(action: { showingEndVacationAlert = true }) {
                HStack {
                  Image("Icon-Vacation")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(Color("red900"))

                  Text("End Vacation")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("red900"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color("red200"))
                .cornerRadius(12)
              }
              .padding(.horizontal, 20)
            }
            .padding(.horizontal, 20)
          }

          Spacer()
        }
        .padding(.top, 20)
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(.primary)
        }
      }
    }
    .alert("End Vacation", isPresented: $showingEndVacationAlert) {
      Button("Cancel", role: .cancel) { }
      Button("End Vacation", role: .destructive) {
        endVacation()
      }
    } message: {
      Text("Are you sure you want to end your vacation? All habits will resume immediately.")
    }
  }

  private func startVacation() {
    vacationManager.startVacation(excludeToday: excludeToday)
    dismiss()
  }

  private func endVacation() {
    vacationManager.endVacation()
    dismiss()
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
  }
}

#Preview {
  VacationModeSheet()
    .environmentObject(VacationManager.shared)
}
