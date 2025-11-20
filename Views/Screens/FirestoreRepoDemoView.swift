//
//  FirestoreRepoDemoView.swift
//  Habitto
//
//  Demo screen for Step 2: Full Firestore repository with goals, completions, XP, streaks
//

import SwiftUI

struct FirestoreRepoDemoView: View {
  // MARK: Internal
  
  @StateObject private var repository = FirestoreRepository.shared
  @StateObject private var authManager = AuthenticationManager.shared
  @State private var selectedDate: String
  @State private var showAddHabit = false
  @State private var showSetGoal = false
  @State private var selectedHabit: FirestoreHabit?
  @State private var newHabitName = ""
  @State private var newHabitColor = "green"
  @State private var newGoal = 1
  @State private var errorMessage: String?
  
  let availableColors = ["green", "blue", "purple", "red", "yellow"]
  
  init() {
    // Initialize with today's date
    let formatter = LocalDateFormatter()
    _selectedDate = State(initialValue: formatter.today())
  }
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // User & Date Section
        userInfoSection
        datePickerSection
        
        // XP Display
        xpSection
        
        // Habits List
        ScrollView {
          LazyVStack(spacing: 12) {
            ForEach(repository.habits) { habit in
              habitCard(habit)
            }
            
            if repository.habits.isEmpty {
              emptyState
            }
          }
          .padding()
        }
      }
      .navigationTitle("Firestore Repo Demo")
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
      .sheet(isPresented: $showSetGoal) {
        setGoalSheet
      }
      .alert("Error", isPresented: .constant(errorMessage != nil)) {
        Button("OK") {
          errorMessage = nil
        }
      } message: {
        Text(errorMessage ?? "")
      }
      .task {
        // Start all streams
        repository.streamHabits()
        repository.streamCompletions(for: selectedDate)
        repository.streamXPState()
      }
      .onDisappear {
        repository.stopListening()
      }
    }
  }
  
  // MARK: Private
  
  private var userInfoSection: some View {
    let isAnonymous = authManager.isAnonymous
    return VStack(spacing: 8) {
      HStack {
        Image(systemName: "person.circle.fill")
          .font(.title2)
        VStack(alignment: .leading, spacing: 2) {
          Text("User ID")
            .font(.caption)
            .foregroundColor(.secondary)
          Text(authManager.currentUserId ?? "Not authenticated")
            .font(.caption)
            .fontWeight(.medium)
            .lineLimit(1)
        }
        Spacer()
        if isAnonymous {
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
  
  private var datePickerSection: some View {
    VStack(spacing: 4) {
      HStack {
        Text("Selected Date")
          .font(.caption)
          .foregroundColor(.secondary)
        Spacer()
        Text(selectedDate)
          .font(.body)
          .fontWeight(.semibold)
      }
      
      HStack {
        Button {
          changeDate(by: -1)
        } label: {
          Image(systemName: "chevron.left")
        }
        
        Spacer()
        
        Button("Today") {
          setToday()
        }
        .font(.caption)
        
        Spacer()
        
        Button {
          changeDate(by: 1)
        } label: {
          Image(systemName: "chevron.right")
        }
      }
    }
    .padding()
    .background(Color(.systemGray6))
  }
  
  private var xpSection: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("Total XP")
          .font(.caption)
          .foregroundColor(.secondary)
        Text("\(repository.xpState?.totalXP ?? 0)")
          .font(.title2)
          .fontWeight(.bold)
      }
      
      Spacer()
      
      VStack(alignment: .trailing, spacing: 4) {
        Text("Level")
          .font(.caption)
          .foregroundColor(.secondary)
        Text("\(repository.xpState?.level ?? 1)")
          .font(.title2)
          .fontWeight(.bold)
      }
      
      Spacer()
      
      VStack(alignment: .trailing, spacing: 4) {
        Text("Current Level XP")
          .font(.caption)
          .foregroundColor(.secondary)
        Text("\(repository.xpState?.currentLevelXP ?? 0) / 100")
          .font(.caption)
          .fontWeight(.medium)
      }
    }
    .padding()
    .background(Color.blue.opacity(0.1))
    .cornerRadius(12)
    .padding(.horizontal)
  }
  
  private func habitCard(_ habit: FirestoreHabit) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      HStack {
        Circle()
          .fill(colorForName(habit.color))
          .frame(width: 16, height: 16)
        
        Text(habit.name)
          .font(.headline)
        
        Spacer()
        
        Text(habit.habitType.capitalized)
          .font(.caption)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.gray.opacity(0.2))
          .cornerRadius(8)
      }
      
      // Stats Row
      HStack(spacing: 20) {
        statItem(
          icon: "target",
          label: "Goal",
          value: "1") // Will be dynamic after goal versioning
        
        statItem(
          icon: "checkmark.circle.fill",
          label: "Today",
          value: "\(repository.completions[habit.id ?? ""]?.count ?? 0)")
        
        if let streak = repository.streaks[habit.id ?? ""] {
          statItem(
            icon: "flame.fill",
            label: "Streak",
            value: "\(streak.current)")
        }
      }
      
      // Actions
      HStack(spacing: 12) {
        Button {
          Task {
            await completeHabit(habit)
          }
        } label: {
          Label("Complete", systemImage: "plus.circle.fill")
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.2))
            .foregroundColor(.green)
            .cornerRadius(8)
        }
        
        Button {
          selectedHabit = habit
          showSetGoal = true
        } label: {
          Label("Set Goal", systemImage: "target")
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.2))
            .foregroundColor(.blue)
            .cornerRadius(8)
        }
        
        Spacer()
        
        Button {
          Task {
            await deleteHabit(habit)
          }
        } label: {
          Image(systemName: "trash")
            .foregroundColor(.red)
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.1), radius: 4)
  }
  
  private func statItem(icon: String, label: String, value: String) -> some View {
    VStack(spacing: 4) {
      Image(systemName: icon)
        .font(.caption)
        .foregroundColor(.secondary)
      Text(value)
        .font(.caption)
        .fontWeight(.semibold)
      Text(label)
        .font(.caption2)
        .foregroundColor(.secondary)
    }
  }
  
  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "tray")
        .font(.system(size: 50))
        .foregroundColor(.gray)
      Text("No habits yet")
        .font(.title3)
        .fontWeight(.semibold)
      Text("Tap + to create your first habit")
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
    .padding(.top, 60)
  }
  
  private var addHabitSheet: some View {
    NavigationStack {
      Form {
        Section("Habit Details") {
          TextField("Habit name", text: $newHabitName)
          
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
            resetForm()
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Create") {
            Task {
              await addHabit()
            }
          }
          .disabled(newHabitName.isEmpty)
        }
      }
    }
  }
  
  private var setGoalSheet: some View {
    NavigationStack {
      Form {
        Section("Goal Configuration") {
          if let habit = selectedHabit {
            Text("Habit: \(habit.name)")
              .font(.headline)
          }
          
          Stepper("Goal: \(newGoal)", value: $newGoal, in: 1...10)
          
          Text("Effective from: \(selectedDate)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .navigationTitle("Set Goal")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            showSetGoal = false
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Save") {
            Task {
              await saveGoal()
            }
          }
        }
      }
    }
  }
  
  private func changeDate(by days: Int) {
    if let newDate = repository.dateFormatter.addDays(days, to: selectedDate) {
      selectedDate = newDate
      repository.streamCompletions(for: selectedDate)
    }
  }
  
  private func setToday() {
    selectedDate = repository.dateFormatter.today()
    repository.streamCompletions(for: selectedDate)
  }
  
  private func addHabit() async {
    do {
      let habitId = try await repository.createHabit(
        name: newHabitName,
        color: newHabitColor,
        type: "formation")
      
      // Set initial goal
      try await repository.setGoal(
        habitId: habitId,
        effectiveLocalDate: repository.dateFormatter.today(),
        goal: 1)
      
      showAddHabit = false
      resetForm()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
  
  private func saveGoal() async {
    guard let habit = selectedHabit, let habitId = habit.id else { return }
    
    do {
      try await repository.setGoal(
        habitId: habitId,
        effectiveLocalDate: selectedDate,
        goal: newGoal)
      
      showSetGoal = false
      newGoal = 1
    } catch {
      errorMessage = error.localizedDescription
    }
  }
  
  private func completeHabit(_ habit: FirestoreHabit) async {
    guard let habitId = habit.id else { return }
    
    do {
      // Increment completion
      try await repository.incrementCompletion(habitId: habitId, localDate: selectedDate)
      
      // Update streak
      try await repository.updateStreak(habitId: habitId, localDate: selectedDate, completed: true)
      
      // Award XP
      try await repository.awardXP(delta: 10, reason: "Completed \(habit.name) on \(selectedDate)")
      
    } catch {
      errorMessage = error.localizedDescription
    }
  }
  
  private func deleteHabit(_ habit: FirestoreHabit) async {
    guard let habitId = habit.id else { return }
    
    do {
      try await repository.deleteHabit(id: habitId)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
  
  private func resetForm() {
    newHabitName = ""
    newHabitColor = "green"
  }
  
  private func colorForName(_ name: String) -> Color {
    switch name {
    case "green": return .green
    case "blue": return .blue
    case "purple": return .purple
    case "red": return .red
    case "yellow": return .yellow
    default: return .gray
    }
  }
}

#Preview {
  FirestoreRepoDemoView()
}




