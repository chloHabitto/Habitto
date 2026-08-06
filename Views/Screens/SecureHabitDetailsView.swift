import SwiftUI

// MARK: - SecureHabitDetailsView

// View for managing habit details with encrypted sensitive fields

struct SecureHabitDetailsView: View {
  // MARK: Lifecycle

  init(habit: SecureHabit) {
    self._habit = State(initialValue: habit)
  }

  // MARK: Internal

  var body: some View {
    NavigationView {
      Form {
        // Basic Information Section
        Section("habits.secureDetail.section.basicInfo".localized) {
          HStack {
            Text("habits.secureDetail.label.name".localized)
            Spacer()
            Text(habit.name)
              .foregroundColor(.secondary)
          }

          HStack {
            Text("habits.secureDetail.label.description".localized)
            Spacer()
            Text(habit.description)
              .foregroundColor(.secondary)
          }

          HStack {
            Text("habits.secureDetail.label.type".localized)
            Spacer()
            Text(habitTypeDisplayName(habit.habitType))
              .foregroundColor(.secondary)
          }
        }

        // Encrypted Fields Section
        Section("habits.secureDetail.section.personalNotes".localized) {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("habits.secureDetail.label.notes".localized)
                .font(.headline)
              Spacer()
              Button("habits.secureDetail.button.encryptionInfo".localized) {
                showingEncryptionInfo = true
              }
              .font(.caption)
              .foregroundColor(.blue)
            }

            if isLoading {
              ProgressView("habits.secureDetail.progress.loadingEncrypted".localized)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
              TextEditor(text: $notes)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .keyboardDoneButton()
            }

            if let error = errorMessage {
              Text(error)
                .foregroundColor(.red)
                .font(.caption)
            }
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("habits.secureDetail.label.personalGoals".localized)
              .font(.headline)

            if isLoading {
              ProgressView("habits.secureDetail.progress.loadingEncrypted".localized)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
              TextEditor(text: $personalGoals)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .keyboardDoneButton()
            }
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("habits.secureDetail.label.motivation".localized)
              .font(.headline)

            if isLoading {
              ProgressView("habits.secureDetail.progress.loadingEncrypted".localized)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
              TextEditor(text: $motivation)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .keyboardDoneButton()
            }
          }
        }

        // Statistics Section
        Section("habits.secureDetail.section.statistics".localized) {
          HStack {
            Text("habits.secureDetail.label.currentStreak".localized)
            Spacer()
            Text(LocalizationManager.shared.localizedStreakDays(habit.streak))
              .foregroundColor(.secondary)
          }

          HStack {
            Text("habits.secureDetail.label.baseline".localized)
            Spacer()
            Text("\(habit.baseline)")
              .foregroundColor(.secondary)
          }

          HStack {
            Text("habits.secureDetail.label.target".localized)
            Spacer()
            Text("\(habit.target)")
              .foregroundColor(.secondary)
          }

          HStack {
            Text("habits.secureDetail.label.completionRate".localized)
            Spacer()
            Text(String(
              format: "habits.secureDetail.format.completionRatePercent".localized,
              calculateCompletionRate()))
              .foregroundColor(.secondary)
          }
        }

        // Security Information Section
        Section("habits.secureDetail.section.security".localized) {
          HStack {
            Image(systemName: "lock.fill")
              .foregroundColor(.green)
            Text("habits.secureDetail.security.fieldsEncrypted".localized)
              .font(.caption)
          }

          HStack {
            Image(systemName: "key.fill")
              .foregroundColor(.blue)
            Text("habits.secureDetail.security.keychain".localized)
              .font(.caption)
          }

          HStack {
            Image(systemName: "faceid")
              .foregroundColor(.purple)
            Text("habits.secureDetail.security.biometric".localized)
              .font(.caption)
          }
        }
      }
      .navigationTitle("habits.secureDetail.navTitle".localized)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("common.save".localized) {
            saveChanges()
          }
          .disabled(isLoading)
        }
      }
      .onAppear {
        loadEncryptedData()
      }
      .alert("habits.secureDetail.alert.encryptionInfoTitle".localized, isPresented: $showingEncryptionInfo) {
        Button("common.ok".localized) { }
      } message: {
        Text("habits.secureDetail.alert.encryptionInfoMessage".localized)
      }
    }
  }

  // MARK: Private

  @State private var habit: SecureHabit
  @State private var notes = ""
  @State private var personalGoals = ""
  @State private var motivation = ""
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var showingEncryptionInfo = false

  // MARK: - Private Methods

  private func loadEncryptedData() {
    isLoading = true
    errorMessage = nil

    Task {
      do {
        var mutableHabit = habit
        let loadedNotes = try await mutableHabit.getNotes()
        let loadedGoals = try await mutableHabit.getPersonalGoals()
        let loadedMotivation = try await mutableHabit.getMotivation()

        await MainActor.run {
          notes = loadedNotes
          personalGoals = loadedGoals
          motivation = loadedMotivation
          isLoading = false
        }
      } catch {
        await MainActor.run {
          errorMessage = String(
            format: "habits.secureDetail.error.loadFailed".localized,
            error.localizedDescription)
          isLoading = false
        }
      }
    }
  }

  private func saveChanges() {
    isLoading = true
    errorMessage = nil

    Task {
      do {
        var updatedHabit = habit
        try await updatedHabit.setNotes(notes)
        try await updatedHabit.setPersonalGoals(personalGoals)
        try await updatedHabit.setMotivation(motivation)

        try await SecureHabitRepository.shared.updateHabit(updatedHabit)

        await MainActor.run {
          habit = updatedHabit
          isLoading = false
        }
      } catch {
        await MainActor.run {
          errorMessage = String(
            format: "habits.secureDetail.error.saveFailed".localized,
            error.localizedDescription)
          isLoading = false
        }
      }
    }
  }

  private func calculateCompletionRate() -> Int {
    let totalDays = Calendar.current.dateComponents([.day], from: habit.startDate, to: Date())
      .day ?? 0
    guard totalDays > 0 else { return 0 }

    let completedDays = habit.completionHistory.count
    return (completedDays * 100) / totalDays
  }

  private func habitTypeDisplayName(_ type: HabitType) -> String {
    switch type {
    case .formation:
      return "habits.type.habitBuilding".localized
    case .breaking:
      return "habits.type.habitBreaking".localized
    }
  }
}

// MARK: - EncryptionStatusView

struct EncryptionStatusView: View {
  // MARK: Internal

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: isEncryptionAvailable
        ? "lock.shield.fill"
        : "exclamationmark.triangle.fill")
        .font(.system(size: 48))
        .foregroundColor(isEncryptionAvailable ? .green : .orange)

      Text(isEncryptionAvailable
        ? "habits.secureDetail.encryptionStatus.available".localized
        : "habits.secureDetail.encryptionStatus.unavailable".localized)
        .font(.title2)
        .fontWeight(.bold)

      if let error = encryptionError {
        Text(error)
          .font(.caption)
          .foregroundColor(.red)
          .multilineTextAlignment(.center)
      }

      if !isEncryptionAvailable {
        Button("habits.secureDetail.encryptionStatus.checkAgain".localized) {
          checkEncryptionStatus()
        }
        .buttonStyle(.bordered)
      }
    }
    .padding()
    .onAppear {
      checkEncryptionStatus()
    }
  }

  // MARK: Private

  @State private var isEncryptionAvailable = false
  @State private var encryptionError: String?

  private func checkEncryptionStatus() {
    Task {
      do {
        let encryptionManager = FieldLevelEncryptionManager.shared
        // Try to encrypt a test string to verify encryption is working
        _ = try await encryptionManager.encryptField("test")

        await MainActor.run {
          isEncryptionAvailable = true
          encryptionError = nil
        }
      } catch {
        await MainActor.run {
          isEncryptionAvailable = false
          encryptionError = error.localizedDescription
        }
      }
    }
  }
}

// MARK: - SecureHabitDetailsView_Previews

struct SecureHabitDetailsView_Previews: PreviewProvider {
  static var previews: some View {
    SecureHabitDetailsView(habit: SecureHabit(
      name: "Morning Exercise",
      description: "Daily morning workout routine",
      icon: "🏃‍♂️",
      color: .blue,
      habitType: .formation,
      schedule: "daily",
      goal: "30 minutes",
      reminder: "7:00 AM",
      startDate: Date(),
      notes: "Focus on cardio and strength training",
      personalGoals: "Lose 10 pounds and build muscle",
      motivation: "Feel healthier and more confident"))
  }
}
