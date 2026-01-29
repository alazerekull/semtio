//
//  UniversalMediaPicker.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct UniversalMediaPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    var mediaTypes: [String] = [UTType.image.identifier, UTType.movie.identifier]
    var onMediaPicked: (URL?, UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.mediaTypes = mediaTypes
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: UniversalMediaPicker
        
        init(_ parent: UniversalMediaPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let mediaType = info[.mediaType] as? String
            
            if mediaType == UTType.movie.identifier {
                if let videoURL = info[.mediaURL] as? URL {
                    parent.onMediaPicked(videoURL, nil)
                }
            } else {
                if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage {
                    parent.onMediaPicked(nil, image)
                }
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
