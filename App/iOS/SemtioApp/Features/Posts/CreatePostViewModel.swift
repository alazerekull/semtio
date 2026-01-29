//
//  CreatePostViewModel.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import Combine
import PhotosUI

enum PostUploadState: Equatable {
    case idle
    case uploading
    case success
    case failed(PostUploadError)
    
    static func == (lhs: PostUploadState, rhs: PostUploadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.uploading, .uploading): return true
        case (.success, .success): return true
        case (.failed(let e1), .failed(let e2)): return e1.localizedDescription == e2.localizedDescription
        default: return false
        }
    }
}

class CreatePostViewModel: ObservableObject {
    // Services
    private let postRepository: PostRepositoryProtocol
    private let storageService: StorageService
    
    // State
    @Published var selectedItem: PhotosPickerItem? = nil
    @Published var selectedImageData: Data? = nil
    @Published var selectedVideoURL: URL? = nil
    @Published var mediaType: Post.MediaType = .image
    @Published var selectedImage: Image? = nil
    @Published var caption: String = ""
    @Published var uploadState: PostUploadState = .idle
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String? = nil
    
    init(postRepository: PostRepositoryProtocol, storageService: StorageService = .shared) {
        self.postRepository = postRepository
        self.storageService = storageService
    }
    
    func selectItem(_ item: PhotosPickerItem?) {
        selectedItem = item
        guard let item = item else { return }
        
        Task {
            // Try loading video first if it's a video
            if let videoURL = try? await item.loadTransferable(type: URL.self) {
                 await MainActor.run {
                     self.setMedia(videoURL: videoURL)
                 }
                 return
            }
            
            // Fallback to image
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.setMedia(image: uiImage)
                }
            } else {
                await MainActor.run {
                    self.errorMessage = PostUploadError.imageCompressionFailed.localizedDescription
                }
            }
        }
    }
    
    func setMedia(image: UIImage) {
        self.selectedImageData = storageService.compressImage(image)
        self.selectedImage = Image(uiImage: image)
        self.selectedVideoURL = nil
        self.mediaType = .image
    }
    
    func setMedia(videoURL: URL) {
        self.selectedVideoURL = videoURL
        self.selectedImageData = nil
        self.mediaType = .video
        
        // Generate a thumbnail for preview if possible
        // For now, we'll just show a placeholder or the first frame if we were using AVFoundation
        // But for the simple implementation, we'll assume the view handles video preview.
    }
    
    func clearSelection() {
        selectedItem = nil
        selectedImageData = nil
        selectedVideoURL = nil
        selectedImage = nil
        mediaType = .image
        caption = ""
        uploadState = .idle
        uploadProgress = 0.0
        errorMessage = nil
    }
    
    func publishPost(currentUser: AppUser?) async {
        guard let uid = currentUser?.id, let currentUser = currentUser else {
            print("❌ CreatePostVM: No authenticated user (uid=nil)")
            handleError(.notAuthenticated)
            return
        }

        // 0. Guard against double-tap
        if uploadState == .uploading {
            print("⚠️ CreatePostVM: Upload already in progress, ignoring duplicate tap.")
            return
        }

        // Ensure we have something to upload
        if mediaType == .image && selectedImageData == nil {
            print("❌ CreatePostVM: Image data is nil")
            handleError(.unknown)
            return
        }
        if mediaType == .video && selectedVideoURL == nil {
            print("❌ CreatePostVM: Video URL is nil")
            handleError(.unknown)
            return
        }

        await MainActor.run {
            uploadState = .uploading
            uploadProgress = 0.0
        }

        do {
            if mediaType == .video {
                // Use PostUploadService for Videos
                let _ = try await PostUploadService.shared.uploadVideoPost(
                    caption: caption,
                    videoLocalURL: selectedVideoURL!
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.uploadProgress = progress
                    }
                }
                
                // Success handled by service (it writes to Firestore)
                // But we need to update UI state
                print("✅ CreatePostVM: Video uploaded via Service")
                 await MainActor.run {
                    self.uploadState = .success
                }
                
            } else {
                // Image Upload (Legacy Path)
                let postId = UUID().uuidString
                // Path: posts/{uid}/{postId}/{uuid}.jpg
                let storagePath = "posts/\(uid)/\(postId)/\(UUID().uuidString).jpg"
                
                print("📤 CreatePostVM: Starting image publish postId=\(postId)")
                
                let downloadURL = try await storageService.uploadImage(data: selectedImageData!, path: storagePath)
                
                let post = Post(
                    id: postId,
                    ownerId: uid,
                    ownerUsername: currentUser.username,
                    ownerDisplayName: currentUser.fullName,
                    ownerAvatarURL: currentUser.avatarURL,
                    caption: caption,
                    mediaURLs: [downloadURL],
                    mediaType: .image,
                    createdAt: Date(),
                    updatedAt: Date(),
                    likeCount: 0,
                    commentCount: 0,
                    visibility: "public"
                )
                
                try await postRepository.createPost(post)
                
                print("✅ CreatePostVM: Image Post saved to Firestore postId=\(postId)")
                
                 await MainActor.run {
                    self.uploadState = .success
                }
            }

        } catch let error as StorageError {
            print("❌ CreatePostVM: Storage error: \(error)")
            handleError(.uploadFailed(error))
        } catch let error as PostUploadService.UploadError {
             print("❌ CreatePostVM: Service error: \(error)")
             // Map to local error type or just use localized description
             handleError(.uploadFailed(StorageError.uploadFailed)) // Simplified mapping
        } catch {
            print("❌ CreatePostVM: Firestore/unknown error: \(error)")
            handleError(.firestoreWriteFailed(error))
        }
    }
    
    private func handleError(_ error: PostUploadError) {
        Task { @MainActor in
            self.uploadState = .failed(error)
            self.errorMessage = error.localizedDescription
            
            #if DEBUG
            print("❌ CreatePostViewModel Error: \(error)")
            #endif
        }
    }
}
