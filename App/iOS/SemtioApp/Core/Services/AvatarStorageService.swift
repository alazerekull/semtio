//
//  AvatarStorageService.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import UIKit
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

class AvatarStorageService {
    static let shared = AvatarStorageService()
    
    // Max dimension for avatar resizing
    private let maxDimension: CGFloat = 1024
    // JPEG quality
    private let compressionQuality: CGFloat = 0.75
    
    func uploadAvatar(uid: String, image: UIImage) async throws -> String {
        // 1. Resize and Compress
        guard let data = processImage(image) else {
            throw NSError(domain: "AvatarStorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Image processing failed"])
        }
        
        #if canImport(FirebaseStorage)
        let path = "avatars/\(uid).jpg"
        let storageRef = Storage.storage().reference().child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // 2. Upload
        let _ = try await storageRef.putDataAsync(data, metadata: metadata)
        
        // 3. Get URL
        let url = try await storageRef.downloadURL()
        return url.absoluteString
        #else
        print("⚠️ AvatarStorageService: FirebaseStorage not linked, returning mock URL.")
        // Simulate network
        try? await Task.sleep(nanoseconds: 500_000_000)
        return "mock://avatar/\(uid)"
        #endif
    }
    
    private func processImage(_ image: UIImage) -> Data? {
        let originalSize = image.size
        let ratio = min(maxDimension / originalSize.width, maxDimension / originalSize.height)
        
        let newSize: CGSize
        if ratio < 1 {
            newSize = CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        } else {
            newSize = originalSize
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage.jpegData(compressionQuality: compressionQuality)
    }
}
