//
//  CachedRemoteImage.swift
//  SemtioApp
//
//  Created for Performance Optimization on 2026-01-27.
//

import SwiftUI

struct CachedRemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    var targetSize: CGSize = CGSize(width: 500, height: 500) // Default conservative max
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    AppColor.surface
                    if isLoading {
                        ProgressView()
                    } else {
                         // Placeholder or empty
                        Color.clear
                    }
                }
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _, _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        // Fast Check Memory (Synchronous-ish check via singleton if we exposed it, but actor is async)
        // Just launch task
        
        isLoading = true
        Task {
            if let loaded = try? await ImagePipeline.shared.image(for: url, targetSize: targetSize) {
                await MainActor.run {
                    self.image = loaded
                    self.isLoading = false
                }
            } else {
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}
