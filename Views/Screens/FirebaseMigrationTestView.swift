//
//  FirebaseMigrationTestView.swift
//  Habitto
//
//  Test view for Firebase migration and dual-write functionality
//

import SwiftUI

struct FirebaseMigrationTestView: View {
  // MARK: Internal
  
  @StateObject private var firestoreService = FirestoreService.shared
  @StateObject private var featureFlags = FeatureFlagManager.shared
  @StateObject private var backfillJob = BackfillJob.shared
  
  @State private var testHabitName = "Test Habit"
  @State private var testHabitDescription = "Testing Firebase migration"
  @State private var showAlert = false
  @State private var alertMessage = ""
  @State private var isLoading = false
  
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          // Status Section
          statusSection
          
          // Feature Flags Section
          featureFlagsSection
          
          // Firestore Service Section
          firestoreServiceSection
          
          // Backfill Job Section
          backfillJobSection
          
          // Test Actions Section
          testActionsSection
          
          // Telemetry Section
          telemetrySection
        }
        .padding()
      }
      .navigationTitle("Firebase Migration Test")
      .navigationBarTitleDisplayMode(.large)
      .alert("Test Result", isPresented: $showAlert) {
        Button("OK") { }
      } message: {
        Text(alertMessage)
      }
    }
  }
  
  // MARK: Private
  
  private var statusSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("System Status")
        .font(.headline)
      
      HStack {
        Image(systemName: AppEnvironment.isFirebaseConfigured ? "checkmark.circle.fill" : "xmark.circle.fill")
          .foregroundColor(AppEnvironment.isFirebaseConfigured ? .green : .red)
        Text("Firebase Configured")
        Spacer()
        Text(AppEnvironment.isFirebaseConfigured ? "Yes" : "No")
          .foregroundColor(.secondary)
      }
      
      HStack {
        Image(systemName: FirebaseConfiguration.currentUserId != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
          .foregroundColor(FirebaseConfiguration.currentUserId != nil ? .green : .red)
        Text("User Authenticated")
        Spacer()
        Text(FirebaseConfiguration.currentUserId?.prefix(8) ?? "None")
          .foregroundColor(.secondary)
      }
      
      HStack {
        Image(systemName: firestoreService.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
          .foregroundColor(firestoreService.isConnected ? .green : .red)
        Text("Firestore Connected")
        Spacer()
        Text(firestoreService.isConnected ? "Yes" : "No")
          .foregroundColor(.secondary)
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
  
  private var featureFlagsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Feature Flags")
        .font(.headline)
      
      HStack {
        Text("Firestore Sync")
        Spacer()
        Text(FeatureFlags.enableFirestoreSync ? "Enabled" : "Disabled")
          .foregroundColor(FeatureFlags.enableFirestoreSync ? .green : .red)
      }
      
      HStack {
        Text("Backfill")
        Spacer()
        Text(FeatureFlags.enableBackfill ? "Enabled" : "Disabled")
          .foregroundColor(FeatureFlags.enableBackfill ? .green : .red)
      }
      
      HStack {
        Text("Legacy Fallback")
        Spacer()
        Text(FeatureFlags.enableLegacyReadFallback ? "Enabled" : "Disabled")
          .foregroundColor(FeatureFlags.enableLegacyReadFallback ? .green : .red)
      }
      
      Button("Refresh Flags") {
        // Feature flags are refreshed automatically via Remote Config
      }
      .buttonStyle(.bordered)
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
  
  private var firestoreServiceSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Firestore Service")
        .font(.headline)
      
      HStack {
        Text("Habits Count")
        Spacer()
        Text("\(firestoreService.habits.count)")
          .foregroundColor(.secondary)
      }
      
      if let error = firestoreService.error {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.red)
          Text("Error: \(error.localizedDescription)")
            .foregroundColor(.red)
        }
      }
      
      HStack {
        Button("Fetch Habits") {
          Task {
            do {
              try await firestoreService.fetchHabits()
              showAlert = true
              alertMessage = "Fetched \(firestoreService.habits.count) habits"
            } catch {
              showAlert = true
              alertMessage = "Error: \(error.localizedDescription)"
            }
          }
        }
        .buttonStyle(.bordered)
        
        Button("Start Listening") {
          firestoreService.startListening()
        }
        .buttonStyle(.bordered)
        
        Button("Stop Listening") {
          firestoreService.stopListening()
        }
        .buttonStyle(.bordered)
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
  
  private var backfillJobSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Backfill Job")
        .font(.headline)
      
      HStack {
        Text("Status")
        Spacer()
        Text(backfillJob.status)
          .foregroundColor(.secondary)
      }
      
      if backfillJob.isRunning {
        ProgressView(value: backfillJob.progress)
          .progressViewStyle(LinearProgressViewStyle())
      }
      
      if let error = backfillJob.error {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.red)
          Text("Error: \(error)")
            .foregroundColor(.red)
        }
      }
      
      Button("Run Backfill") {
        Task {
          await backfillJob.runIfEnabled()
        }
      }
      .buttonStyle(.bordered)
      .disabled(backfillJob.isRunning)
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
  
  private var testActionsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Test Actions")
        .font(.headline)
      
      VStack(spacing: 8) {
        TextField("Habit Name", text: $testHabitName)
          .textFieldStyle(.roundedBorder)
        
        TextField("Description", text: $testHabitDescription)
          .textFieldStyle(.roundedBorder)
      }
      
      Button("Create Test Habit") {
        Task {
          await createTestHabit()
        }
      }
      .buttonStyle(.borderedProminent)
      .disabled(isLoading)
      
      Button("Test Dual Write") {
        Task {
          await testDualWrite()
        }
      }
      .buttonStyle(.bordered)
      .disabled(isLoading)
      
      Button("Test Offline Mode") {
        Task {
          await testOfflineMode()
        }
      }
      .buttonStyle(.bordered)
      .disabled(isLoading)
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
  
  private var telemetrySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Telemetry")
        .font(.headline)
      
      let counters = firestoreService.getTelemetryCounters()
      ForEach(counters.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
        HStack {
          Text(key)
            .font(.caption)
          Spacer()
          Text("\(value)")
            .foregroundColor(.secondary)
        }
      }
      
      Button("Log Telemetry") {
        firestoreService.logTelemetry()
        showAlert = true
        alertMessage = "Telemetry logged to console"
      }
      .buttonStyle(.bordered)
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
  
  // MARK: - Test Methods
  
  private func createTestHabit() async {
    isLoading = true
    defer { isLoading = false }
    
    do {
      let habit = Habit(
        name: testHabitName,
        description: testHabitDescription,
        icon: "star.fill",
        color: .blue,
        habitType: .formation,
        schedule: "daily",
        goal: "1 time per day",
        reminder: "Morning",
        startDate: Date()
      )
      
      _ = try await firestoreService.createHabit(habit)
      
      showAlert = true
      alertMessage = "Test habit created successfully!"
    } catch {
      showAlert = true
      alertMessage = "Error creating test habit: \(error.localizedDescription)"
    }
  }
  
  private func testDualWrite() async {
    isLoading = true
    defer { isLoading = false }
    
    // This would test the dual-write functionality
    // For now, just show a message
    showAlert = true
    alertMessage = "Dual-write test would be implemented here"
  }
  
  private func testOfflineMode() async {
    isLoading = true
    defer { isLoading = false }
    
    // This would test offline functionality
    // For now, just show a message
    showAlert = true
    alertMessage = "Offline mode test would be implemented here"
  }
}

// MARK: - Preview

#Preview {
  FirebaseMigrationTestView()
}
