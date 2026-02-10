import AVKit
import SwiftUI

// MARK: - OnboardingVideoPlayer

struct OnboardingVideoPlayer: View {
  let videoName: String
  @State private var player: AVPlayer?
  @State private var loopObserver: NSObjectProtocol?

  var body: some View {
    Group {
      if let player = player {
        VideoPlayer(player: player)
          .disabled(true)
          .aspectRatio(contentMode: .fit)
          .clipShape(RoundedRectangle(cornerRadius: 20))
      } else {
        RoundedRectangle(cornerRadius: 20)
          .fill(Color.white.opacity(0.1))
          .aspectRatio(9 / 16, contentMode: .fit)
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
