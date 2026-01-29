//
//  ProfileMediaService.swift
//  SemtioApp
//
//  Profile photo upload service with Firebase Storage and Firestore integration.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import UIKit
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum ProfileMediaError: LocalizedError {
    case notAuthenticated
    case imageProcessingFailed
    case uploadFailed(Error)
    case urlFetchFailed
    case firestoreWriteFailed(Error)
    case uploadAlreadyInProgress
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Kullanıcı oturumu bulunamadı."
        case .imageProcessingFailed:
            return "Fotoğraf işlenemedi."
        case .uploadFailed(let error):
            return "Yükleme başarısız: \(error.localizedDescription)"
        case .urlFetchFailed:
            return "Fotoğraf URL'si alınamadı."
        case .firestoreWriteFailed(let error):
            return "Profil güncellenemedi: \(error.localizedDescription)"
        case .uploadAlreadyInProgress:
            return "Yükleme zaten devam ediyor."
        }
    }
}

@MainActor
class ProfileMediaService {
    static let shared = ProfileMediaService()
    
    private let maxDimension: CGFloat = 1024
    private let compressionQuality: CGFloat = 0.82
    
    /// Single-flight guard for uploads
    private(set) var isUploading: Bool = false
    
    /// Uploads avatar image to Firebase Storage and writes avatarURL to Firestore.
    /// - Parameter image: The UIImage to upload
    /// - Returns: The download URL of the uploaded avatar
    /// - Throws: ProfileMediaError if upload fails or already in progress
    func uploadAvatar(image: UIImage) async throws -> URL {
        // Single-flight guard
        guard !isUploading else {
            #if DEBUG
            print("⚠️ ProfileMediaService: Upload already in progress, skipping duplicate request")
            #endif
            throw ProfileMediaError.uploadAlreadyInProgress
        }
        
        isUploading = true
        defer { isUploading = false }
        
        #if canImport(FirebaseAuth)
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            throw ProfileMediaError.notAuthenticated
        }
        #else
        let uid = "mock-uid"
        #endif
        
        // 1. Process image (resize + compress)
        #if DEBUG
        print("📷 ProfileMediaService: Processing image for user \(uid)")
        #endif
        
        guard let data = processImage(image) else {
            throw ProfileMediaError.imageProcessingFailed
        }
        
        #if canImport(FirebaseStorage)
        // 2. Upload to Storage
        let path = "users/\(uid)/avatar.jpg"
        let storageRef = Storage.storage().reference().child(path)
        
        #if DEBUG
        print("📤 ProfileMediaService: Uploading to \(path)")
        #endif
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            let _ = try await storageRef.putDataAsync(data, metadata: metadata)
            #if DEBUG
            print("✅ ProfileMediaService: Upload complete")
            #endif
        } catch {
            throw ProfileMediaError.uploadFailed(error)
        }
        
        // 3. Get download URL
        #if DEBUG
        print("🔗 ProfileMediaService: Fetching download URL")
        #endif
        
        let downloadURL: URL
        do {
            downloadURL = try await storageRef.downloadURL()
            #if DEBUG
            print("✅ ProfileMediaService: Got URL: \(downloadURL.absoluteString)")
            #endif
        } catch {
            throw ProfileMediaError.urlFetchFailed
        }
        
        #if canImport(FirebaseFirestore)
        // 4. Write to Firestore
        let db = Firestore.firestore()
        do {
            try await db.collection("users").document(uid).setData([
                "avatarURL": downloadURL.absoluteString,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            #if DEBUG
            print("✅ ProfileMediaService: Firestore updated")
            #endif
        } catch {
            throw ProfileMediaError.firestoreWriteFailed(error)
        }
        #endif
        
        return downloadURL
        #else
        // Mock mode - return nil-safe placeholder
        print("⚠️ ProfileMediaService: FirebaseStorage not linked")
        try? await Task.sleep(nanoseconds: 500_000_000)
        // Return a placeholder that will be filtered by safeHTTPURL
        throw ProfileMediaError.uploadFailed(NSError(domain: "ProfileMediaService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase Storage not available"]))
        #endif
    }
    
    /// Saves profile fields to Firestore (merge).
    /// - Parameters:
    ///   - displayName: User's display name
    ///   - username: User's unique username
    ///   - bio: User's bio text
    func saveProfileFields(displayName: String, username: String?, bio: String?) async throws {
        #if canImport(FirebaseAuth)
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            throw ProfileMediaError.notAuthenticated
        }
        #else
        let uid = "mock-uid"
        #endif
        
        #if canImport(FirebaseFirestore)
        var data: [String: Any] = [
            "displayName": displayName,
            "bio": bio ?? "",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let username = username, !username.isEmpty {
            data["username"] = username
        }
        
        let db = Firestore.firestore()
        do {
            try await db.collection("users").document(uid).setData(data, merge: true)
        } catch {
            throw ProfileMediaError.firestoreWriteFailed(error)
        }
        #else
        print("⚠️ ProfileMediaService: FirebaseFirestore not linked, skipping save.")
        #endif
    }
    
    // MARK: - Private
    
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

// MARK: - Firestore/Storage Rules Guidance (DEV)
/*
 Firestore Rules (recommended):
 
 rules_version = '2';
 service cloud.firestore {
   match /databases/{database}/documents {
     match /users/{userId} {
       allow read: if true; // Public profiles
       allow write: if request.auth != null && request.auth.uid == userId;
     }
   }
 }
 
 Storage Rules (recommended):
 
 rules_version = '2';
 service firebase.storage {
   match /b/{bucket}/o {
     match /users/{userId}/{allPaths=**} {
       allow read: if true; // Public avatars
       allow write: if request.auth != null && request.auth.uid == userId;
     }
   }
 }
*/
