import AVFoundation
import SwiftUI

struct CameraView: UIViewControllerRepresentable {
  @Environment(\.dismiss) private var dismiss
  let onPhotoTaken: (UIImage) -> Void

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.delegate = context.coordinator
    picker.sourceType = .camera
    picker.cameraDevice = .front // Use front camera for selfies
    picker.allowsEditing = true
    picker.cameraOverlayView = createOverlayView()
    return picker
  }

  func updateUIViewController(_: UIImagePickerController, context _: Context) { }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  private func createOverlayView() -> UIView {
    let overlayView = UIView()
    overlayView.backgroundColor = UIColor.clear

    // Add a circular mask overlay to guide the user
    let maskLayer = CAShapeLayer()
    let circlePath = UIBezierPath(ovalIn: CGRect(x: 50, y: 200, width: 300, height: 300))
    let path = UIBezierPath(rect: overlayView.bounds)
    path.append(circlePath.reversing())
    maskLayer.path = path.cgPath
    maskLayer.fillRule = .evenOdd
    overlayView.layer.mask = maskLayer

    return overlayView
  }

  class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: Lifecycle

    init(_ parent: CameraView) {
      self.parent = parent
    }

    // MARK: Internal

    let parent: CameraView

    func imagePickerController(
      _: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any])
    {
      if let editedImage = info[.editedImage] as? UIImage {
        parent.onPhotoTaken(editedImage)
      } else if let originalImage = info[.originalImage] as? UIImage {
        parent.onPhotoTaken(originalImage)
      }
      parent.dismiss()
    }

    func imagePickerControllerDidCancel(_: UIImagePickerController) {
      parent.dismiss()
    }
  }
}

#Preview {
  CameraView { image in
    print("Photo taken: \(image)")
  }
}
