import AVKit
import SwiftUI
import UIKit

// MARK: - OnboardingVideoPlayer

struct OnboardingVideoPlayer: View {
  let videoName: String
  var contentMode: ContentMode = .fit
  @State private var player: AVPlayer?
  @State private var loopObserver: NSObjectProtocol?

  var body: some View {
    Group {
      if let player = player {
        if contentMode == .fill {
          OnboardingVideoLayerView(player: player, fill: true)
        } else {
          VideoPlayer(player: player)
            .disabled(true)
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
      } else {
        RoundedRectangle(cornerRadius: contentMode == .fill ? 0 : 20)
          .fill(Color.white.opacity(0.1))
          .aspectRatio(9 / 16, contentMode: contentMode)
      }
    }
    .frame(maxWidth: contentMode == .fill ? .infinity : nil, maxHeight: contentMode == .fill ? .infinity : nil)
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

// MARK: - OnboardingVideoLayerView (AVPlayerLayer with resizeAspectFill for true full-screen fill)

struct OnboardingVideoLayerView: UIViewRepresentable {
  let player: AVPlayer
  let fill: Bool

  func makeUIView(context: Context) -> OnboardingVideoLayerUIView {
    let view = OnboardingVideoLayerUIView()
    let layer = AVPlayerLayer(player: player)
    layer.videoGravity = fill ? .resizeAspectFill : .resizeAspect
    view.playerLayer = layer
    return view
  }

  func updateUIView(_ uiView: OnboardingVideoLayerUIView, context: Context) {
    uiView.playerLayer?.videoGravity = fill ? .resizeAspectFill : .resizeAspect
  }
}

final class OnboardingVideoLayerUIView: UIView {
  var playerLayer: AVPlayerLayer? {
    didSet {
      oldValue?.removeFromSuperlayer()
      guard let layer = playerLayer else { return }
      self.layer.addSublayer(layer)
      setNeedsLayout()
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if let playerLayer = playerLayer, !bounds.isEmpty {
      playerLayer.frame = bounds
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
