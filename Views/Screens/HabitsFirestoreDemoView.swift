//
//  HabitsFirestoreDemoView.swift
//  Habitto
//
//  Demo screen showing Firestore integration with real-time updates
//

import SwiftUI

struct HabitsFirestoreDemoView: View {
  // MARK: Internal
  
  @StateObject private var firestoreService = FirestoreService.shared
  @StateObject private var authManager = AuthenticationManager.shared
  
  @State private var newHabitName = ""
  @State private var newHabitColor = "green"
  @State private var showAddHabit = false
  @State private var isLoading = false
  @State private var errorMessage: String?
  
  let availableColors = ["green", "blue", "purple", "red", "yellow", "pink"]
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Status Banner
        statusBanner
        
        // User Info
        userInfoSection
        
        // Habits List
        if isLoading {
          ProgressView("Loading habits...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if firestoreService.habits.isEmpty {
          emptyState
        } else {
          habitsList
        }
      }
      .navigationTitle("Firestore Demo")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            showAddHabit = true
          } label: {
            Image(systemName: "plus.circle.fill")
              .font(.title2)
          }
        }
      }
      .sheet(isPresented: $showAddHabit) {
        addHabitSheet
      }
      .alert("Error", isPresented: .constant(errorMessage != nil)) {
        Button("OK") {
          errorMessage = nil
        }
      } message: {
        Text(errorMessage ?? "")
      }
      .task {
        await loadHabits()
        firestoreService.startListening()
      }
      .onDisappear {
        firestoreService.stopListening()
      }
    }
  }
  
  // MARK: Private
  
  private var statusBanner: some View {
    Group {
      if !AppEnvironment.isFirebaseConfigured {
        VStack(spacing: 8) {
          HStack {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundColor(.yellow)
            Text("Firebase not configured")
              .font(.subheadline)
              .fontWeight(.medium)
          }
          Text("Add GoogleService-Info.plist to enable cloud sync")
            .font(.caption)
            .foregroundColor(.secondary)
          Text("Demo running with mock data")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.yellow.opacity(0.1))
      }
    }
  }
  
  private var userInfoSection: some View {
    VStack(spacing: 8) {
      HStack {
        Image(systemName: "person.circle.fill")
          .font(.title2)
        VStack(alignment: .leading, spacing: 2) {
          Text("Current User")
            .font(.caption)
            .foregroundColor(.secondary)
          Text(authManager.currentUserId ?? "Not authenticated")
            .font(.caption)
            .fontWeight(.medium)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        Spacer()
        if authManager.isAnonymous {
          Text("Anonymous")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
      }
      .padding()
      .background(Color(.systemGray6))
    }
  }
  
  private var habitsList: some View {
    List {
      ForEach(firestoreService.habits) { habit in
        HabitRow(habit: habit) {
          Task {
            await deleteHabit(habit)
          }
        }
      }
    }
    .listStyle(.plain)
  }
  
  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "tray")
        .font(.system(size: 60))
        .foregroundColor(.gray)
      Text("No habits yet")
        .font(.title2)
        .fontWeight(.semibold)
      Text("Tap + to add your first habit")
        .font(.subheadline)
        .foregroundColor(.secondary)
      
      Button {
        showAddHabit = true
      } label: {
        Text("Add Habit")
          .font(.headline)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(12)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
  private var addHabitSheet: some View {
    NavigationStack {
      Form {
        Section("Habit Details") {
          TextField("Habit name", text: $newHabitName)
            .autocorrectionDisabled()
          
          Picker("Color", selection: $newHabitColor) {
            ForEach(availableColors, id: \.self) { color in
              HStack {
                Circle()
                  .fill(colorForName(color))
                  .frame(width: 20, height: 20)
                Text(color.capitalized)
              }
              .tag(color)
            }
          }
        }
      }
      .navigationTitle("New Habit")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            showAddHabit = false
            newHabitName = ""
            newHabitColor = "green"
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Add") {
            Task {
              await addHabit()
            }
          }
          .disabled(newHabitName.isEmpty)
        }
      }
    }
  }
  
  private func loadHabits() async {
    isLoading = true
    defer { isLoading = false }
    
    do {
      try await firestoreService.fetchHabits()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
  
  private func addHabit() async {
    do {
      let habit = Habit(
        name: newHabitName,
        description: "",
        icon: "star.fill",
        color: CodableColor(Color(hex: newHabitColor)),
        habitType: .formation,
        schedule: "Daily",
        goal: "1 time",
        reminder: "9:00 AM",
        startDate: Date()
      )
      _ = try await firestoreService.createHabit(habit)
      showAddHabit = false
      newHabitName = ""
      newHabitColor = "green"
    } catch {
      errorMessage = error.localizedDescription
    }
  }
  
  private func deleteHabit(_ habit: Habit) async {
    do {
      try await firestoreService.deleteHabit(id: habit.id.uuidString)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
  
  private func colorForName(_ name: String) -> Color {
    switch name {
    case "green": return .green
    case "blue": return .blue
    case "purple": return .purple
    case "red": return .red
    case "yellow": return .yellow
    case "pink": return .pink
    default: return .gray
    }
  }
}

// MARK: - HabitRow

struct HabitRow: View {
  let habit: Habit
  let onDelete: () -> Void
  
  var body: some View {
    HStack {
      Circle()
        .fill(habit.colorValue)
        .frame(width: 12, height: 12)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(habit.name)
          .font(.body)
          .fontWeight(.medium)
        Text(habit.id.uuidString)
          .font(.caption2)
          .foregroundColor(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      
      Spacer()
      
      Button(action: onDelete) {
        Image(systemName: "trash")
          .foregroundColor(.red)
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 8)
  }
  
  private func colorForName(_ name: String) -> Color {
    switch name {
    case "green": return .green
    case "blue": return .blue
    case "purple": return .purple
    case "red": return .red
    case "yellow": return .yellow
    case "pink": return .pink
    default: return .gray
    }
  }
}

// MARK: - Preview

#Preview {
  HabitsFirestoreDemoView()
}

