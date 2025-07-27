import SwiftUI

struct HabitDetailView: View {
    let habit: Habit
    @Environment(\.dismiss) private var dismiss
    @State private var todayProgress: Int = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top navigation bar
                topNavigationBar
                
                // Main content card
                mainContentCard
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                Spacer()
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        VStack(spacing: 0) {
            HStack {
                // Back button
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // More options button
                Button(action: {
                    // TODO: Add more options
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                Text("Habit details")
                    .font(.appHeadlineMediumEmphasised)
                    .foregroundColor(.text01)
                
                Text("View and edit your habit details.")
                    .font(.appTitleSmall)
                    .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
//        .background(.surface)
    }
    
    // MARK: - Main Content Card
    private var mainContentCard: some View {
        VStack(spacing: 0) {
            // Habit Summary Section
            habitSummarySection
            
            Divider()
                .padding(.horizontal, 16)
            
            // Habit Details Section
            habitDetailsSection
            
            Divider()
                .padding(.horizontal, 16)
            
            // Today's Progress Section
            todayProgressSection
        }
        .background(.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Habit Summary Section
    private var habitSummarySection: some View {
        HStack(spacing: 12) {
            // Habit Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.surfaceContainer)
                    .frame(width: 48, height: 48)
                
                if habit.icon.hasPrefix("Icon-") {
                    Image(habit.icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.primary)
                } else {
                    Text(habit.icon)
                        .font(.system(size: 24))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.primary)
                
                Text(habit.description.isEmpty ? "Description" : habit.description)
                    .font(.appBodyMedium)
                    .foregroundColor(.text05)
            }
            
            Spacer()
            
            // Active status tag
                            Text("Active")
                    .font(.appLabelSmall)
                    .foregroundColor(.onPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Habit Details Section
    private var habitDetailsSection: some View {
        VStack(spacing: 16) {
            // Schedule
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(.text05)
                
                Text("Schedule")
                    .font(.appBodyMedium)
                    .foregroundColor(.text05)
                
                Spacer()
                
                Text(habit.schedule)
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.primary)
            }
            
            // Goal
            HStack {
                Image(systemName: "flag")
                    .font(.system(size: 16))
                    .foregroundColor(.text05)
                
                Text("Goal")
                    .font(.appBodyMedium)
                    .foregroundColor(.text05)
                
                Spacer()
                
                Text(habit.goal)
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Today's Progress Section
    private var todayProgressSection: some View {
        VStack(spacing: 16) {
            // Progress header
            HStack {
                Text("Today's progress")
                    .font(.appBodyMedium)
                    .foregroundColor(.text05)
                
                Spacer()
                
                Text("\(todayProgress)/1")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.primary)
            }
            
            // Progress bar
            progressBar
            
            // Increment/Decrement controls
            HStack(spacing: 16) {
                Spacer()
                
                // Decrement button
                Button(action: {
                    if todayProgress > 0 {
                        todayProgress -= 1
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.onPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.primary)
                        .clipShape(Circle())
                }
                
                // Current count
                Text("\(todayProgress)")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.primary)
                    .frame(width: 40)
                
                // Increment button
                Button(action: {
                    todayProgress += 1
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.onPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.primary)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.surfaceContainer)
                        .frame(height: 4)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary)
                        .frame(width: geometry.size.width * CGFloat(todayProgress) / 1.0, height: 4)
                }
            }
            .frame(height: 4)
            
            // Progress numbers
            HStack {
                Text("0")
                    .font(.appLabelSmall)
                    .foregroundColor(.text05)
                
                Spacer()
                
                Text("1")
                    .font(.appLabelSmall)
                    .foregroundColor(.text05)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE dd MMMM"
        return formatter.string(from: Date())
    }
}

#Preview {
    HabitDetailView(habit: Habit(
        name: "Read a book",
        description: "Read for 30 minutes",
        icon: "📚",
        color: .blue,
        habitType: .formation,
        schedule: "Every 2 days",
        goal: "1 time a day",
        reminder: "9:00 AM",
        startDate: Date(),
        endDate: nil,
        isCompleted: false,
        streak: 5
    ))
} 
