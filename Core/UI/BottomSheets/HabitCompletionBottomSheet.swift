import SwiftUI
import AVKit

// MARK: - HabitCompletionBottomSheet

struct HabitCompletionBottomSheet: View {
  @Binding var isPresented: Bool
  let habit: Habit
  let completionDate: Date
  @State private var selectedDifficulty: HabitDifficulty?
  @State private var hasChangedDifficulty = false
  let onDismiss: (() -> Void)?
  let onSave: ((Int) -> Void)?
  let initialDifficulty: HabitDifficulty?
  let isEditMode: Bool
  @Environment(\.colorScheme) var colorScheme

  init(
    isPresented: Binding<Bool>,
    habit: Habit,
    completionDate: Date,
    onDismiss: (() -> Void)?,
    onSave: ((Int) -> Void)? = nil,
    initialDifficulty: HabitDifficulty? = nil,
    isEditMode: Bool = false
  ) {
    self._isPresented = isPresented
    self.habit = habit
    self.completionDate = completionDate
    self.onDismiss = onDismiss
    self.onSave = onSave
    self.initialDifficulty = initialDifficulty
    self.isEditMode = isEditMode
  }

  enum HabitDifficulty: Int, CaseIterable {
    case veryEasy = 1
    case easy = 2
    case medium = 3
    case hard = 4
    case veryHard = 5

    // MARK: Internal

    @MainActor
    var displayName: String {
      switch self {
      case .veryEasy: "habits.difficulty.veryEasy".localized
      case .easy: "habits.difficulty.easy".localized
      case .medium: "habits.difficulty.medium".localized
      case .hard: "habits.difficulty.hard".localized
      case .veryHard: "habits.difficulty.veryHard".localized
      }
    }

    var color: Color {
      switch self {
      case .veryEasy: .green
      case .easy: .mint
      case .medium: .orange
      case .hard: .red
      case .veryHard: .purple
      }
    }
  }

  var body: some View {
    VStack(spacing: 20) {
      // Header Section
      headerSection

      // Difficulty Rating Section
      difficultyRatingSection

      // Action Buttons
      Spacer()

      actionButtons
    }
    .onAppear {
      // Use initial difficulty if editing, otherwise default to very easy
      selectedDifficulty = initialDifficulty ?? .veryEasy
      hasChangedDifficulty = false

      // Haptic feedback for completion celebration
      let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
      impactFeedback.impactOccurred()
    }
    .padding(.horizontal, 24)
    .padding(.top, 8)
    .padding(.bottom, 24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.surface01Variant)
    .ignoresSafeArea(edges: .bottom)
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 4) {
      // Close button and title row
      HStack {
        Spacer()
        
        // Close button
        Button(action: {
          isPresented = false
        }) {
          Image(systemName: "xmark")
            .font(.system(size: 16, weight: .heavy))
            .foregroundColor(.text07)
            .frame(width: 44, height: 44)
        }
        .padding(.trailing, -12)
      }
      .padding(.top, 8)

      // Title
      Text(isEditMode ? "Edit Difficulty" : "Good job!")
        .font(Font.appHeadlineSmallEmphasised)
        .foregroundColor(.text01)
        .frame(maxWidth: .infinity, alignment: .center)

      // Difficulty question
      Text(isEditMode ? "Change how difficult this felt" : "How difficult was this habit today?")
        .font(Font.appBodyMediumEmphasised)
        .foregroundColor(.text05)
        .frame(maxWidth: .infinity, alignment: .center)
    }
  }

  // MARK: - Habit Info Section

  private var habitInfoSection: some View {
    VStack(spacing: 16) {
      // Habit icon and name
      HStack(spacing: 16) {
        HabitIconView(habit: habit)
          .frame(width: 48, height: 48)

        VStack(alignment: .leading, spacing: 4) {
          Text(habit.name)
            .font(Font.appTitleMediumEmphasised)
            .foregroundColor(.text01)

          if !habit.description.isEmpty {
            Text(habit.description)
              .font(Font.appBodyMedium)
              .foregroundColor(.text03)
              .lineLimit(2)
          }

          // Progress context
          HStack(spacing: 8) {
            if habit.computedStreak() > 0 {
              HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                  .font(.caption)
                  .foregroundColor(.orange)
                Text("\(habit.computedStreak()) day streak")
                  .font(Font.appBodySmall)
                  .foregroundColor(.text03)
              }
            }

            if habit.computedStreak() > 0 {
              Text("•")
                .font(.appBodySmall)
                .foregroundColor(.text04)
            }

            Text("Completed today!")
              .font(.appBodySmall)
              .foregroundColor(.green)
          }
        }

        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .background(.surface2)
      .cornerRadius(20)
      .overlay(
        RoundedRectangle(cornerRadius: 20)
          .stroke(.outline3, lineWidth: 1))
    }
  }

  // MARK: - Difficulty Rating Section

  private var difficultyRatingSection: some View {
    VStack(spacing: 24) {
      // Difficulty slider
      VStack(spacing: 16) {
        // Character image with chat bubble
        if let difficulty = selectedDifficulty {
          HStack(alignment: .center, spacing: 0) {
            // Character image
            Group {
              switch difficulty {
              case .veryEasy:
                DifficultyVideoView(videoName: colorScheme == .dark ? "01VeryEasy_Dark" : "01VeryEasy_Light")
                  .frame(width: 180, height: 180)
                  .aspectRatio(contentMode: .fit)
                  .id(colorScheme) // Force recreation when color scheme changes

              case .easy:
                DifficultyVideoView(videoName: colorScheme == .dark ? "02Easy_Dark" : "02Easy_Light")
                  .frame(width: 180, height: 180)
                  .aspectRatio(contentMode: .fit)
                  .id(colorScheme) // Force recreation when color scheme changes

              case .medium:
                DifficultyVideoView(videoName: colorScheme == .dark ? "03Normal_Dark" : "03Normal_Light")
                  .frame(width: 180, height: 180)
                  .aspectRatio(contentMode: .fit)
                  .id(colorScheme) // Force recreation when color scheme changes

              case .hard:
                DifficultyVideoView(videoName: colorScheme == .dark ? "04Hard_Dark" : "04Hard_Light")
                  .frame(width: 180, height: 180)
                  .aspectRatio(contentMode: .fit)
                  .id(colorScheme) // Force recreation when color scheme changes

              case .veryHard:
                DifficultyVideoView(videoName: colorScheme == .dark ? "05VeryHard_Dark" : "05VeryHard_Light")
                  .frame(width: 180, height: 180)
                  .aspectRatio(contentMode: .fit)
                  .id(colorScheme) // Force recreation when color scheme changes
              }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .id("\(difficulty.rawValue)-\(colorScheme)") // Unique ID for each difficulty and color scheme
            
            // Chat bubble
            ZStack {
              // Chat bubble image
              Image("Chatbubble-stroke")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 60)
                .foregroundColor(.appOutline02)
              
              // Text overlay on chat bubble
              Text(difficulty.displayName + "!")
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.text03)
                .padding(.leading, 10)
            }
          }
          .animation(.easeInOut(duration: 0.25), value: difficulty)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.bottom, 8)
        }

        // Slider
        Slider(
          value: Binding(
            get: {
              if let difficulty = selectedDifficulty {
                return Double(difficulty.rawValue)
              }
              return 1.0 // Default to very easy
            },
            set: { value in
              let difficultyValue = Int(round(value))
              let newDifficulty = HabitDifficulty(rawValue: difficultyValue) ?? .veryEasy

              if selectedDifficulty != newDifficulty {
                withAnimation(.easeInOut(duration: 0.25)) {
                  selectedDifficulty = newDifficulty
                }

                if isEditMode {
                  hasChangedDifficulty = (newDifficulty != initialDifficulty)
                }

                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
              }
            }),
          in: 1 ... 5,
          step: 1)
          .accentColor(.primary)

        // Difficulty labels
        HStack {
          Text("Very Easy")
            .font(.appBodySmallEmphasised)
            .foregroundColor(.text02)

          Spacer()

          Text("Very Hard")
            .font(.appBodySmallEmphasised)
            .foregroundColor(.text02)
        }
      }
    }
  }

  // MARK: - Action Buttons

  private var saveButtonEnabled: Bool {
    if isEditMode {
      return hasChangedDifficulty && selectedDifficulty != nil
    } else {
      return selectedDifficulty != nil
    }
  }

  private var actionButtons: some View {
    HStack(spacing: 16) {
      Button(action: {
        isPresented = false
        onDismiss?()
      }) {
        Text(isEditMode ? "Cancel" : "Skip")
          .font(Font.appButtonText1)
          .foregroundColor(.text04)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(.badgeBackground)
          .cornerRadius(30)
      }
      .buttonStyle(PlainButtonStyle())

      Button(action: {
        if let difficulty = selectedDifficulty {
          saveDifficultyRating(difficulty)
          onSave?(difficulty.rawValue)
        }
        isPresented = false
        onDismiss?()
      }) {
        Text(isEditMode ? "Save" : "Submit")
          .font(Font.appButtonText1)
          .foregroundColor(.onPrimary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(saveButtonEnabled ? .primary : .disabledBackground)
          .cornerRadius(30)
      }
      .buttonStyle(PlainButtonStyle())
      .disabled(!saveButtonEnabled)
    }
  }

  // MARK: - Save Difficulty Rating

  private func saveDifficultyRating(_ difficulty: HabitDifficulty) {
    // Convert difficulty to integer (1-5 scale)
    let difficultyValue = Int32(difficulty.rawValue)

    // Save to Core Data using HabitRepository with the actual completion date
    HabitRepository.shared.saveDifficultyRating(
      habitId: habit.id,
      date: completionDate,
      difficulty: difficultyValue)
  }
}

// MARK: - DifficultyVideoView

struct DifficultyVideoView: UIViewRepresentable {
  let videoName: String
  
  func makeCoordinator() -> Coordinator {
    Coordinator()
  }
  
  func makeUIView(context: Context) -> UIView {
    let videoView = VideoPlayerView()
    let coordinator = context.coordinator
    
    // Try multiple ways to load the video
    var videoURL: URL?
    
    // Method 1: Try path-based loading (mp4)
    if let path = Bundle.main.path(forResource: videoName, ofType: "mp4") {
      videoURL = URL(fileURLWithPath: path)
    }
    // Method 2: Try URL-based loading (mp4)
    else if let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") {
      videoURL = url
    }
    // Method 3: Try with subdirectory (mp4)
    else if let url = Bundle.main.url(forResource: videoName, withExtension: "mp4", subdirectory: "Animations") {
      videoURL = url
    }
    // Method 4: Fallback to mov for backward compatibility
    else if let path = Bundle.main.path(forResource: videoName, ofType: "mov") {
      videoURL = URL(fileURLWithPath: path)
    }
    else if let url = Bundle.main.url(forResource: videoName, withExtension: "mov") {
      videoURL = url
    }
    else if let url = Bundle.main.url(forResource: videoName, withExtension: "mov", subdirectory: "Animations") {
      videoURL = url
    }
    else {
      print("❌ DifficultyVideoView: Failed to find video file: \(videoName).mp4 or \(videoName).mov")
      print("   Searched in Bundle.main")
      return videoView
    }
    
    guard let url = videoURL else {
      print("❌ DifficultyVideoView: URL is nil")
      return videoView
    }
    
    let playerItem = AVPlayerItem(url: url)
    let player = AVPlayer(playerItem: playerItem)
    
    // Set up looping - automatically restart when video ends
    player.actionAtItemEnd = .none
    
    // Create player layer
    let playerLayer = AVPlayerLayer(player: player)
    playerLayer.videoGravity = .resizeAspect
    
    // Store references
    coordinator.player = player
    coordinator.playerLayer = playerLayer
    coordinator.playerItem = playerItem
    
    // Add player layer to view
    videoView.playerLayer = playerLayer
    
    // Monitor player item status
    playerItem.addObserver(coordinator, forKeyPath: "status", options: [.new], context: nil)
    
    // Set up notification observer for looping
    NotificationCenter.default.addObserver(
      coordinator,
      selector: #selector(Coordinator.playerItemDidReachEnd),
      name: .AVPlayerItemDidPlayToEndTime,
      object: playerItem
    )
    
    // Wait for view to be laid out before playing
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      // Force layout update
      videoView.setNeedsLayout()
      videoView.layoutIfNeeded()
      
      // Update player layer frame after layout - ensure it's not zero
      if !videoView.bounds.isEmpty {
        playerLayer.frame = videoView.bounds
        
        // Start playing only if bounds are valid
        player.play()
      } else {
        // Retry after another delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          if !videoView.bounds.isEmpty {
            playerLayer.frame = videoView.bounds
            player.play()
          }
        }
      }
    }
    
    return videoView
  }
  
  func updateUIView(_ uiView: UIView, context: Context) {
    // Frame will be updated in VideoPlayerView's layoutSubviews
  }
  
  class Coordinator: NSObject {
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var playerItem: AVPlayerItem?
    
    @objc func playerItemDidReachEnd(notification: Notification) {
      guard let player = player else { return }
      player.seek(to: .zero)
      player.play()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
      if keyPath == "status" {
        if let playerItem = object as? AVPlayerItem {
          switch playerItem.status {
          case .readyToPlay:
            break
          case .failed:
            print("❌ DifficultyVideoView: Player item failed: \(playerItem.error?.localizedDescription ?? "Unknown error")")
          case .unknown:
            break
          @unknown default:
            break
          }
        }
      }
    }
    
    deinit {
      playerItem?.removeObserver(self, forKeyPath: "status")
      NotificationCenter.default.removeObserver(self)
    }
  }
}

// MARK: - VideoPlayerView

class VideoPlayerView: UIView {
  var playerLayer: AVPlayerLayer? {
    didSet {
      if let layer = playerLayer {
        self.layer.addSublayer(layer)
        // Update frame immediately
        layer.frame = bounds
        setNeedsLayout()
        print("✅ VideoPlayerView: Player layer added with frame: \(bounds)")
      }
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    if let playerLayer = playerLayer {
      // Ensure frame matches bounds exactly
      if !bounds.isEmpty {
        playerLayer.frame = bounds
      }
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    clipsToBounds = true
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    backgroundColor = .clear
    clipsToBounds = true
  }
}

// MARK: - Corner Radius Extension

extension View {
  func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
    clipShape(RoundedCorner(radius: radius, corners: corners))
  }
}

#Preview {
  HabitCompletionBottomSheet(
    isPresented: .constant(true),
    habit: Habit(
      name: "Read Books",
      description: "Read at least one chapter every day",
      icon: "📚",
      color: .blue,
      habitType: .formation,
      schedule: "Everyday",
      goal: "1 chapter",
      reminder: "No reminder",
      startDate: Date(),
      endDate: nil),
    completionDate: Date(),
    onDismiss: { },
    onSave: nil)
    .background(.surface2)
}
