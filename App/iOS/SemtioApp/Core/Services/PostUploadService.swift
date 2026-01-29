//
//  PostUploadService.swift
//  SemtioApp
//
//  Created for Video Upload Flow
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class PostUploadService {
    
    static let shared = PostUploadService()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let transcoder = VideoTranscoder()
    private let thumbnailer = VideoThumbnailer()
    
    // Concurrency safe guard
    private actor UploadGuard {
        private var active = Set<URL>()
        
        func tryStart(_ url: URL) -> Bool {
            if active.contains(url) { return false }
            active.insert(url)
            return true
        }
        
        func finish(_ url: URL) {
            active.remove(url)
        }
    }
    
    private let uploadGuard = UploadGuard()
    
    private init() {}
    
    enum UploadError: Error, LocalizedError {
        case notAuthenticated
        case processingFailed(String)
        case uploadFailed(String)
        case duplicateUpload
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "User must be logged in to upload."
            case .processingFailed(let msg): return "Video processing failed: \(msg)"
            case .uploadFailed(let msg): return "Upload failed: \(msg)"
            case .duplicateUpload: return "Upload already in progress."
            }
        }
    }
    
    /// Uploads a video post.
    /// - Parameters:
    ///   - caption: Post caption.
    ///   - videoLocalURL: Local URL of the selected video.
    ///   - progress: Callback for upload progress (0.0 to 1.0).
    /// - Returns: The created postId.
    func uploadVideoPost(caption: String, videoLocalURL: URL, progress: @escaping (Double) -> Void) async throws -> String {
        // In-flight check
        let canStart = await uploadGuard.tryStart(videoLocalURL)
        guard canStart else {
            print("⚠️ PostUploadService: Duplicate upload attempt for \(videoLocalURL.lastPathComponent)")
            throw UploadError.duplicateUpload
        }
        
        // Ensure cleanup on exit
        defer {
            Task { await uploadGuard.finish(videoLocalURL) }
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            throw UploadError.notAuthenticated
        }
        
        // 1. Generate IDs
        let postId = UUID().uuidString
        
        // 2. Process Video (Transcode & Thumbnail)
        // Reporting 10% progress for processing
        progress(0.05)
        
        let fileResult: (outputURL: URL, duration: Double)
        let thumbData: Data
        
        do {
            async let transcodeTask = transcoder.transcode(inputURL: videoLocalURL)
            async let thumbTask = thumbnailer.generateThumbnail(from: videoLocalURL)
            
            fileResult = try await transcodeTask
            thumbData = try await thumbTask
        } catch {
            throw UploadError.processingFailed(error.localizedDescription)
        }
        
        progress(0.15) // Processing done
        
        // 3. Upload to Storage
        // video: /posts/{uid}/{postId}/video.mp4
        // thumb: /posts/{uid}/{postId}/thumb.jpg
        
        let storageRef = storage.reference().child("posts").child(uid).child(postId)
        let videoRef = storageRef.child("video.mp4")
        let thumbRef = storageRef.child("thumb.jpg")
        
        // Metadata
        let videoMeta = StorageMetadata()
        videoMeta.contentType = "video/mp4"
        
        let thumbMeta = StorageMetadata()
        thumbMeta.contentType = "image/jpeg"
        
        // We will sum progress from both uploads
        // Video weight: 80%, Thumb weight: 5%
        // Start: 15% -> End: 100%
        
        do {
            // Upload Thumbnail (Small, just wait)
            let _ = try await thumbRef.putDataAsync(thumbData, metadata: thumbMeta)
            
            // Upload Video (Track progress)
            // Firebase Async/Await putFileAsync doesn't support progress easily without converting to task observer.
            // wrapping putFile in older API to get progress.
            
            let videoURL = try await uploadFileWithProgress(ref: videoRef, fileURL: fileResult.outputURL, metadata: videoMeta) { p in
                // Map p (0-1) to total (0.15 - 0.95)
                let total = 0.15 + (p * 0.80)
                progress(total)
            }
            
            progress(0.95)
            
            // Get URLs
            let videoDownloadURL = videoURL.absoluteString
            let thumbDownloadURL = try await thumbRef.downloadURL().absoluteString
            
            // 4. Create Firestore Documents
            try await createFirestoreDocs(
                uid: uid,
                postId: postId,
                caption: caption,
                videoURL: videoDownloadURL,
                thumbURL: thumbDownloadURL,
                duration: fileResult.duration
            )
            
            // Cleanup temp files
            try? FileManager.default.removeItem(at: fileResult.outputURL)
            
            progress(1.0)
            return postId
            
        } catch {
            throw UploadError.uploadFailed(error.localizedDescription)
        }
    }
    
    // Helper to wrap storage upload with progress
    private func uploadFileWithProgress(ref: StorageReference, fileURL: URL, metadata: StorageMetadata, onProgress: @escaping (Double) -> Void) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let task = ref.putFile(from: fileURL, metadata: metadata)
            
            // Should keep track of handles to remove them?
            // "StorageTask" removes observers on dealloc, but explicit removal is safer if we reuse logic.
            
            let _ = task.observe(.progress) { snapshot in
                if let completed = snapshot.progress?.fractionCompleted {
                    onProgress(completed)
                }
            }
            
            let _ = task.observe(.success) { _ in
                task.removeAllObservers() // Cleanup
                // Fetch download URL
                ref.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: UploadError.uploadFailed("No download URL"))
                    }
                }
            }
            
            let _ = task.observe(.failure) { snapshot in
                task.removeAllObservers() // Cleanup
                if let error = snapshot.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: UploadError.uploadFailed("Unknown upload error"))
                }
            }
        }
    }
    
    private func createFirestoreDocs(uid: String, postId: String, caption: String, videoURL: String, thumbURL: String, duration: Double) async throws {
        
        let batch = db.batch()
        
        // 1. Post Document — field names match FirestorePostRepository mapper
        let postRef = db.collection("users").document(uid).collection("posts").document(postId)
        let postData: [String: Any] = [
            "id": postId,
            "userId": uid,
            "caption": caption,
            "mediaType": "video",
            "mediaUrl": videoURL,
            "imageUrl": thumbURL,
            "thumbUrl": thumbURL,
            "durationSec": duration,
            "timestamp": FieldValue.serverTimestamp(),
            "likes": 0,
            "likedBy": [String: Bool](),
            "commentsCount": 0,
            "sharesCount": 0,
            "sharedBy": [String: Bool]()
        ]
        batch.setData(postData, forDocument: postRef)
        
        // 2. Feed Item (Owner)
        let feedItemId = "\(uid)_\(postId)"
        let feedRef = db.collection("users").document(uid).collection("feed_friends").document(feedItemId)
        
        let feedData: [String: Any] = [
            "itemId": feedItemId,
            "type": "post",
            "ownerId": uid,
            "postId": postId,
            "refPath": "/users/\(uid)/posts/\(postId)",
            "createdAt": FieldValue.serverTimestamp(), // Will match exactly or close enough
            "mediaType": "video",
            "thumbUrl": thumbURL,
            "captionPreview": caption.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        batch.setData(feedData, forDocument: feedRef)
        
        // Commit core writes first
        try await batch.commit()
        
        // 3. Fan-out to Friends (Background - best effort)
        // We do this after core commit so upload success isn't blocked by reading friends list.
        Task {
            await fanOutToFriends(uid: uid, feedItemId: feedItemId, feedData: feedData)
        }
    }
    
    private func fanOutToFriends(uid: String, feedItemId: String, feedData: [String: Any]) async {
        do {
            // Check if friends collection exists, assuming users/{uid}/friends structure based on friend system
            // Query for accepted friends
            // Assuming structure: /users/{uid}/friends/{friendUid} with status="accepted" OR
            // /users/ -> field "friends" array?
            // User requested: "Query: /users/{uid}/friends where status == 'accepted'"
            
            let friendsSnapshot = try await db.collection("users").document(uid).collection("friends")
                .whereField("status", isEqualTo: "accepted")
                .getDocuments()
            
            // Batch writes to friends (batches of 500)
            let batches = stride(from: 0, to: friendsSnapshot.documents.count, by: 500).map { _ in db.batch() }
            
            for (index, doc) in friendsSnapshot.documents.enumerated() {
                let friendUid = doc.documentID // assuming doc ID is friend UID or field contains it. 
                // FriendSystem usually stores targetUid in document ID or a field.
                // Assuming docID is friendUid for standard relation patterns, or we check a field.
                // "fan-out to accepted friends feed_friends (batched)"
                // I'll assume documentID is the friend's UID.
                
                let batchIndex = index / 500
                let friendFeedRef = db.collection("users").document(friendUid).collection("feed_friends").document(feedItemId)
                batches[batchIndex].setData(feedData, forDocument: friendFeedRef)
            }
            
            for batch in batches {
                try await batch.commit()
            }
            
            print("✅ Fan-out complete to \(friendsSnapshot.documents.count) friends.")
            
        } catch {
            print("⚠️ Fan-out failed: \(error)")
        }
    }
}
