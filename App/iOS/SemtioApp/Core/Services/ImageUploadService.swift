//
//  ImageUploadService.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import UIKit
import FirebaseStorage

protocol ImageUploadServiceProtocol {
    func uploadImage(_ image: UIImage, path: String) async throws -> String
}

final class ImageUploadService: ImageUploadServiceProtocol {
    private let storage = Storage.storage()
    
    enum UploadError: Error, LocalizedError {
        case compressionFailed
        case invalidURL
        
        var errorDescription: String? {
            switch self {
            case .compressionFailed: return "Görüntü sıkıştırılamadı."
            case .invalidURL: return "Yükleme URL'si alınamadı."
            }
        }
    }
    
    func uploadImage(_ image: UIImage, path: String) async throws -> String {
        // Compress image (JPEG 0.7 quality is usually good balance)
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw UploadError.compressionFailed
        }
        
        // Create reference
        let ref = storage.reference().child(path)
        
        // Metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload (using async/await wrapper for putData)
        _ = try await ref.putDataAsync(data, metadata: metadata)
        
        // Get Download URL
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
}
