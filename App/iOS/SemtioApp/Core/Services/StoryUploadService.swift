//
//  StoryUploadService.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import UIKit // for UIImage

class StoryUploadService {
    
    static let shared = StoryUploadService()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let transcoder = VideoTranscoder()
    private let thumbnailer = VideoThumbnailer()
    
    private init() {}
    
    enum UploadError: Error, LocalizedError {
        case notAuthenticated
        case processingFailed(String)
        case uploadFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "Oturum açmalısınız."
            case .processingFailed(let msg): return "İşlem başarısız: \(msg)"
            case .uploadFailed(let msg): return "Yükleme başarısız: \(msg)"
            }
        }
    }
    
    /// Create Image Story
    func uploadImageStory(image: UIImage, caption: String, visibility: Story.StoryVisibility, context: Story.StoryContext) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw UploadError.notAuthenticated }
        let storyId = UUID().uuidString
        
        // 1. Process Image
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw UploadError.processingFailed("Görsel hazırlanamadı")
        }
        
        // 2. Upload
        let path = "stories/\(uid)/\(storyId)/image.jpg"
        let ref = storage.reference().child(path)
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        
        let _ = try await ref.putDataAsync(imageData, metadata: meta)
        let url = try await ref.downloadURL().absoluteString
        
        // 3. Create Document
        try await createStoryDoc(uid: uid, storyId: storyId, mediaUrl: url, thumbUrl: url, type: .image, caption: caption, visibility: visibility, context: context)
    }
    
    /// Create Video Story
    func uploadVideoStory(videoURL: URL, caption: String, visibility: Story.StoryVisibility, context: Story.StoryContext) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw UploadError.notAuthenticated }
        let storyId = UUID().uuidString
        
        // 1. Process (Thumbnail Only - Transcoding optional if we trust source or enforce limits)
        // Stories are short -> Transcode to safe format (720p/1080p, H.264).
        // Reuse VideoTranscoder
        
        let thumbData = try await thumbnailer.generateThumbnail(from: videoURL)
        let transcodeResult = try await transcoder.transcode(inputURL: videoURL) // Use default preset
        
        // 2. Upload
        // Upload Thumb
        let thumbPath = "stories/\(uid)/\(storyId)/thumb.jpg"
        let thumbRef = storage.reference().child(thumbPath)
        let thumbMeta = StorageMetadata()
        thumbMeta.contentType = "image/jpeg"
        let _ = try await thumbRef.putDataAsync(thumbData, metadata: thumbMeta)
        let thumbDownloadUrl = try await thumbRef.downloadURL().absoluteString
        
        // Upload Video
        let videoPath = "stories/\(uid)/\(storyId)/video.mp4"
        let videoRef = storage.reference().child(videoPath)
        let videoMeta = StorageMetadata()
        videoMeta.contentType = "video/mp4"
        let _ = try await videoRef.putFileAsync(from: transcodeResult.outputURL, metadata: videoMeta)
        let videoDownloadUrl = try await videoRef.downloadURL().absoluteString
        
        // Cleanup
        try? FileManager.default.removeItem(at: transcodeResult.outputURL)
        
        // 3. Create Document
        try await createStoryDoc(uid: uid, storyId: storyId, mediaUrl: videoDownloadUrl, thumbUrl: thumbDownloadUrl, type: .video, caption: caption, visibility: visibility, context: context)
    }
    
    private func createStoryDoc(uid: String, storyId: String, mediaUrl: String, thumbUrl: String, type: Story.MediaType, caption: String, visibility: Story.StoryVisibility, context: Story.StoryContext) async throws {
        
        let now = Date()
        let expiresAt = Calendar.current.date(byAdding: .hour, value: 24, to: now)!
        
        // Create Story Object manually to control layout or use Codable
        let story = Story(
            id: storyId,
            ownerId: uid,
            mediaURL: mediaUrl,
            thumbURL: thumbUrl,
            mediaType: type,
            caption: caption,
            context: context,
            visibility: visibility,
            createdAt: now,
            expiresAt: expiresAt,
            viewCount: 0
        )
        
         let ref = db.collection("users").document(uid).collection("stories").document(storyId)
         try ref.setData(from: story)
    }
}
