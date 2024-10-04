//
//  ImagePicker.swift
//  fluxBoom
//
//  Created by Sam Roman on 10/3/24.
//

import SwiftUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var errorMessage: String
    
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        let maxDimension: CGFloat = 2048 // Adjust as needed
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            defer {
                parent.presentationMode.wrappedValue.dismiss()
            }
            
            guard let originalImage = info[.originalImage] as? UIImage else {
                parent.errorMessage = "Failed to load the selected image."
                return
            }
            
            // Resize the image if needed
            let resizedImage = resizeImageIfNeeded(image: originalImage, maxDimension: maxDimension)
            
            // Convert to JPEG data
            guard let jpegData = resizedImage.jpegData(compressionQuality: 0.8) else {
                parent.errorMessage = "Failed to process the selected image."
                return
            }
            
            // Check the size of the JPEG data
            let imageSizeInMB = Double(jpegData.count) / (1024.0 * 1024.0)
            if imageSizeInMB > 30.0 {
                parent.errorMessage = "Selected image exceeds 30MB after resizing."
                return
            }
            
            // Set the image and clear any previous error message
            parent.image = resizedImage
            parent.errorMessage = ""
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func resizeImageIfNeeded(image: UIImage, maxDimension: CGFloat) -> UIImage {
            let width = image.size.width
            let height = image.size.height

            // Calculate new dimensions that are multiples of 64
            let newWidth = CGFloat(Int(min(width, maxDimension) / 64) * 64)
            let newHeight = CGFloat(Int(min(height, maxDimension) / 64) * 64)

            let newSize = CGSize(width: newWidth, height: newHeight)

            UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return resizedImage ?? image
        }

        private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
            UIGraphicsBeginImageContextWithOptions(targetSize, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: targetSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return resizedImage ?? image
        }
    }
}
