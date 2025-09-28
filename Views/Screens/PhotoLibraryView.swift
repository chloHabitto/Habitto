import SwiftUI
import PhotosUI

struct PhotoLibraryView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onPhotoSelected: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryView
        
        init(_ parent: PhotoLibraryView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else {
                print("📷 PhotoLibraryView: No image selected")
                parent.dismiss()
                return
            }
            
            print("📷 PhotoLibraryView: Image selected, loading...")
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    DispatchQueue.main.async {
                        if let uiImage = image as? UIImage {
                            print("✅ PhotoLibraryView: Image loaded successfully - \(uiImage.size)")
                            self?.parent.onPhotoSelected(uiImage)
                        } else if let error = error {
                            print("❌ PhotoLibraryView: Error loading image - \(error.localizedDescription)")
                        }
                        self?.parent.dismiss()
                    }
                }
            } else {
                print("❌ PhotoLibraryView: Cannot load image from provider")
                parent.dismiss()
            }
        }
    }
}

#Preview {
    PhotoLibraryView { image in
        print("Photo selected: \(image)")
    }
}
