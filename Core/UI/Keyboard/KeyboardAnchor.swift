import UIKit

final class KeyboardAnchor: NSObject, UITextFieldDelegate {
  static let shared = KeyboardAnchor()

  private var window: UIWindow?
  private weak var textField: UITextField?

  // Present an invisible text field as first responder to bring up the emoji keyboard ASAP
  func prewarmEmoji() {
    DispatchQueue.main.async {
      guard self.textField?.isFirstResponder != true else { return }
      guard let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive })
      else { return }

      let overlay = UIWindow(windowScene: scene)
      overlay.windowLevel = .normal + 1
      overlay.backgroundColor = .clear
      overlay.isHidden = false

      let host = UIViewController()
      host.view.backgroundColor = .clear
      overlay.rootViewController = host

      let tf = EmojiPreferringTextField()
      tf.delegate = self
      tf.autocorrectionType = .no
      tf.autocapitalizationType = .none
      tf.spellCheckingType = .no
      tf.textColor = .clear
      tf.tintColor = .clear
      tf.backgroundColor = .clear
      tf.frame = CGRect(x: -1000, y: -1000, width: 1, height: 1)
      host.view.addSubview(tf)

      let success = tf.becomeFirstResponder()
      if success == false {
        DispatchQueue.main.async {
          _ = tf.becomeFirstResponder()
        }
      }

      self.window = overlay
      self.textField = tf
    }
  }

  // Release the temporary anchor once the real text field is focused
  func release() {
    DispatchQueue.main.async {
      if let tf = self.textField, tf.isFirstResponder {
        tf.resignFirstResponder()
      }
      self.textField?.removeFromSuperview()
      self.textField = nil
      self.window?.isHidden = true
      self.window = nil
    }
  }
}






