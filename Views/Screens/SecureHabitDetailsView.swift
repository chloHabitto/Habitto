import SwiftUI

// MARK: - Secure Habit Details View
// View for managing habit details with encrypted sensitive fields

struct SecureHabitDetailsView: View {
    @State private var habit: SecureHabit
    @State private var notes: String = ""
    @State private var personalGoals: String = ""
    @State private var motivation: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingEncryptionInfo = false
    
    init(habit: SecureHabit) {
        self._habit = State(initialValue: habit)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information Section
                Section("Basic Information") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(habit.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Description")
                        Spacer()
                        Text(habit.description)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(habit.habitType.rawValue)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Encrypted Fields Section
                Section("Personal Notes") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Notes")
                                .font(.headline)
                            Spacer()
                            Button("Encryption Info") {
                                showingEncryptionInfo = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        if isLoading {
                            ProgressView("Loading encrypted data...")
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
                        Text("Personal Goals")
                            .font(.headline)
                        
                        if isLoading {
                            ProgressView("Loading encrypted data...")
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
                        Text("Motivation")
                            .font(.headline)
                        
                        if isLoading {
                            ProgressView("Loading encrypted data...")
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
                Section("Statistics") {
                    HStack {
                        Text("Current Streak")
                        Spacer()
                        Text("\(habit.streak) days")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Baseline")
                        Spacer()
                        Text("\(habit.baseline)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Target")
                        Spacer()
                        Text("\(habit.target)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Completion Rate")
                        Spacer()
                        Text("\(calculateCompletionRate())%")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Security Information Section
                Section("Security") {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.green)
                        Text("Sensitive fields are encrypted")
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.blue)
                        Text("Encryption key stored in Keychain")
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "faceid")
                            .foregroundColor(.purple)
                        Text("Biometric authentication required")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Habit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                loadEncryptedData()
            }
            .alert("Encryption Information", isPresented: $showingEncryptionInfo) {
                Button("OK") { }
            } message: {
                Text("Your personal notes, goals, and motivation are encrypted using AES-256-GCM encryption. The encryption key is stored securely in the iOS Keychain and requires biometric authentication (Face ID or Touch ID) to access.")
            }
        }
    }
    
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
                    self.notes = loadedNotes
                    self.personalGoals = loadedGoals
                    self.motivation = loadedMotivation
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load encrypted data: \(error.localizedDescription)"
                    self.isLoading = false
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
                    self.habit = updatedHabit
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save changes: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func calculateCompletionRate() -> Int {
        let totalDays = Calendar.current.dateComponents([.day], from: habit.startDate, to: Date()).day ?? 0
        guard totalDays > 0 else { return 0 }
        
        let completedDays = habit.completionHistory.count
        return (completedDays * 100) / totalDays
    }
}

// MARK: - Encryption Status View

struct EncryptionStatusView: View {
    @State private var isEncryptionAvailable = false
    @State private var encryptionError: String?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isEncryptionAvailable ? "lock.shield.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(isEncryptionAvailable ? .green : .orange)
            
            Text(isEncryptionAvailable ? "Encryption Available" : "Encryption Unavailable")
                .font(.title2)
                .fontWeight(.bold)
            
            if let error = encryptionError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            if !isEncryptionAvailable {
                Button("Check Again") {
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
    
    private func checkEncryptionStatus() {
        Task {
            do {
                let encryptionManager = FieldLevelEncryptionManager.shared
                // Try to encrypt a test string to verify encryption is working
                _ = try await encryptionManager.encryptField("test")
                
                await MainActor.run {
                    self.isEncryptionAvailable = true
                    self.encryptionError = nil
                }
            } catch {
                await MainActor.run {
                    self.isEncryptionAvailable = false
                    self.encryptionError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Preview

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
            motivation: "Feel healthier and more confident"
        ))
    }
}
