//
//  StorageService.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import SwiftUI

#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

enum StorageError: Error {
    case uploadFailed
    case downloadURLFailed
    case serviceUnavailable // For previews/mock
}

class StorageService {
    
    // Singleton access if needed, but AppState can also own it
    static let shared = StorageService()
    
    private let isPreview: Bool
    
    init() {
        self.isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    /// Uploads image data to the specified path and returns the download URL.
    func uploadImage(data: Data, path: String) async throws -> String {
        if isPreview || AppConfig.dataSource == .mock {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return "mock://storage/\(UUID().uuidString).jpg"
        }
        
        #if canImport(FirebaseStorage)
        let storageRef = Storage.storage().reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            _ = try await storageRef.putDataAsync(data, metadata: metadata)
            let url = try await storageRef.downloadURL()
            return url.absoluteString
        } catch {
            print("❌ StorageService: Image upload failed: \(error)")
            throw StorageError.uploadFailed
        }
        #else
        throw StorageError.serviceUnavailable
        #endif
    }
    
    /// Uploads a file from a local URL to storage (useful for videos).
    func uploadFile(localURL: URL, path: String, contentType: String) async throws -> String {
        if isPreview || AppConfig.dataSource == .mock {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // Videos take longer
            return "mock://storage/\(UUID().uuidString).mp4"
        }
        
        #if canImport(FirebaseStorage)
        let storageRef = Storage.storage().reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        
        do {
            _ = try await storageRef.putFileAsync(from: localURL, metadata: metadata)
            let url = try await storageRef.downloadURL()
            return url.absoluteString
        } catch {
            print("❌ StorageService: File upload failed: \(error)")
            throw StorageError.uploadFailed
        }
        #else
        throw StorageError.serviceUnavailable
        #endif
    }
    
    /// Helper to compress UIImage to JPEG Data
    func compressImage(_ image: UIImage, quality: CGFloat = 0.7) -> Data? {
        return image.jpegData(compressionQuality: quality)
    }
}
