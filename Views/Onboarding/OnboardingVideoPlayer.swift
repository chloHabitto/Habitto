import AVKit
import SwiftUI

// MARK: - OnboardingVideoPlayer

struct OnboardingVideoPlayer: View {
  let videoName: String
  var contentMode: ContentMode = .fit
  @State private var player: AVPlayer?
  @State private var loopObserver: NSObjectProtocol?

  var body: some View {
    Group {
      if let player = player {
        VideoPlayer(player: player)
          .disabled(true)
          .aspectRatio(contentMode: contentMode)
          .clipShape(RoundedRectangle(cornerRadius: contentMode == .fill ? 0 : 20))
      } else {
        RoundedRectangle(cornerRadius: contentMode == .fill ? 0 : 20)
          .fill(Color.white.opacity(0.1))
          .aspectRatio(9 / 16, contentMode: contentMode)
      }
    }
    .onAppear {
      guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else { return }
      let item = AVPlayerItem(url: url)
      let newPlayer = AVPlayer(playerItem: item)
      newPlayer.isMuted = true
      player = newPlayer
      newPlayer.play()

      loopObserver = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime,
        object: item,
        queue: .main
      ) { _ in
        newPlayer.seek(to: .zero)
        newPlayer.play()
      }
    }
    .onDisappear {
      player?.pause()
      if let observer = loopObserver {
        NotificationCenter.default.removeObserver(observer)
      }
    }
  }
}
