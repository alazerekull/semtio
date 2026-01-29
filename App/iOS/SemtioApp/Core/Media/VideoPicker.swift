//
//  VideoPicker.swift
//  SemtioApp
//
//  Created for Video Upload Flow
//

import SwiftUI
import PhotosUI
import AVFoundation

/// A helper to manage video selection from the photo library.
@MainActor
class VideoPickerViewModel: ObservableObject {
    @Published var selectedItem: PhotosPickerItem? = nil {
        didSet {
            if let item = selectedItem {
                loadVideo(from: item)
            }
        }
    }
    
    @Published var selectedVideoURL: URL? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private func loadVideo(from item: PhotosPickerItem) {
        isLoading = true
        errorMessage = nil
        
        // Load as a transferable representation (File URL)
        item.loadTransferable(type: VideoFile.self) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let videoFile):
                    if let videoFile = videoFile {
                        // Copy to a stable temp location so we can use it
                        do {
                            let tempURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString)
                                .appendingPathExtension("mov") // Source might be mov
                            
                            try FileManager.default.copyItem(at: videoFile.url, to: tempURL)
                            self.selectedVideoURL = tempURL
                        } catch {
                            self.errorMessage = "Failed to process video: \(error.localizedDescription)"
                        }
                    } else {
                        self.errorMessage = "Could not load video."
                    }
                case .failure(let error):
                    self.errorMessage = "Video selection failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func clearSelection() {
        selectedItem = nil
        selectedVideoURL = nil
        errorMessage = nil
    }
}

// Helper for Transferable
struct VideoFile: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("\(UUID().uuidString).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}

/// A wrapper view for selecting a video from the library.
struct VideoPicker: View {
    @Binding var selectedVideoURL: URL?
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var viewModel = VideoPickerViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Video hazırlanıyor...")
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Tekrar Dene") {
                        viewModel.clearSelection()
                    }
                } else {
                    ContentUnavailableView("Video Seçin", systemImage: "video.badge.plus", description: Text("Galerinizden bir video seçin."))
                }
            }
            .navigationTitle("Video Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $viewModel.selectedItem, matching: .videos, photoLibrary: .shared()) {
                        Text("Seç")
                            .fontWeight(.bold)
                    }
                }
            }
            .onChange(of: viewModel.selectedVideoURL) { _, url in
                if let url = url {
                    selectedVideoURL = url
                    dismiss()
                }
            }
        }
    }
}
