//
//  StoryCreationSheet.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import PhotosUI

struct StoryCreationSheet: View {
    @Environment(\.dismiss) var dismiss
    
    // State for media selection
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    
    // Sheets for Gallery
    @State private var showPhotoLibrary = false
    
    // Editor State
    @State private var showEditor = false
    
    // Context passed from outside (e.g. sharing an event)
    var contextEvent: Event? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Default: Camera View
                StoryCameraView(
                    selectedImage: $selectedImage,
                    selectedVideoURL: $selectedVideoURL,
                    onGallery: {
                        showPhotoLibrary = true
                    }
                )
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissStorySheet"))) { _ in
                    dismiss()
                }
            }
            // Logic to transition to Editor when media is captured/selected
            .onChange(of: selectedImage) { _, image in
                if image != nil { showEditor = true }
            }
            .onChange(of: selectedVideoURL) { _, url in
                if url != nil { showEditor = true }
            }
            // Navigate to Editor
            .navigationDestination(isPresented: $showEditor) {
                if let image = selectedImage {
                    StoryEditorView(image: image, videoURL: nil, contextEvent: contextEvent)
                        .navigationBarBackButtonHidden(true)
                } else if let url = selectedVideoURL {
                    StoryEditorView(image: nil, videoURL: url, contextEvent: contextEvent)
                        .navigationBarBackButtonHidden(true)
                }
            }
            .sheet(isPresented: $showPhotoLibrary) {
                ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
                    .ignoresSafeArea()
            }
        }
    }
}
