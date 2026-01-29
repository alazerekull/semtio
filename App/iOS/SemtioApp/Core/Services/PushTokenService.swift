//
//  PushTokenService.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Manages FCM token registration and Firestore persistence.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class PushTokenService {
    
    // MARK: - Singleton
    
    static let shared = PushTokenService()
    
    // MARK: - State
    
    private var currentUserId: String?
    private var currentToken: String?
    private var lastWrittenToken: String?
    private var lastWriteTime: Date?
    
    private let isPreview: Bool
    private let deviceId: String
    private let cooldownSeconds: TimeInterval = 60 // Avoid spamming writes
    
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
    
    // MARK: - Init
    
    private init() {
        self.isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        self.deviceId = DeviceIdProvider.shared.deviceId
        
        if isPreview {
            print("📱 PushTokenService: Running in preview mode (no-op)")
        }
    }
    
    // MARK: - Public API
    
    /// Sets the current authenticated user ID
    func setUser(uid: String?) {
        guard !isPreview else { return }
        
        let previousUid = currentUserId
        currentUserId = uid
        
        if uid != previousUid {
            // User changed - reset write tracking
            lastWrittenToken = nil
            lastWriteTime = nil
        }
        
        if let uid = uid {
            print("📱 PushTokenService: User set to \(uid)")
            attemptTokenWrite()
        } else {
            print("📱 PushTokenService: User cleared")
        }
    }
    
    /// Updates the FCM token (called from AppDelegate/MessagingDelegate)
    func updateToken(_ token: String) {
        guard !isPreview else { return }
        
        currentToken = token
        print("📱 PushTokenService: Token updated")
        attemptTokenWrite()
    }
    
    // MARK: - Private
    
    private func attemptTokenWrite() {
        guard let uid = currentUserId,
              let token = currentToken else {
            return
        }
        
        // Dedupe: skip if same token was recently written
        if let lastToken = lastWrittenToken,
           let lastTime = lastWriteTime,
           lastToken == token,
           Date().timeIntervalSince(lastTime) < cooldownSeconds {
            print("📱 PushTokenService: Skipping write (cooldown)")
            return
        }
        
        writeTokenToFirestore(uid: uid, token: token)
    }
    
    private func writeTokenToFirestore(uid: String, token: String) {
        #if canImport(FirebaseFirestore)
        let deviceDoc = db.collection("users")
            .document(uid)
            .collection("devices")
            .document(deviceId)
        
        let data: [String: Any] = [
            "fcmToken": token,
            "platform": "ios",
            "locale": Locale.current.identifier,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        deviceDoc.setData(data, merge: true) { [weak self] error in
            if let error = error {
                print("❌ PushTokenService: Failed to write token: \(error)")
            } else {
                print("✅ PushTokenService: Token written for device \(self?.deviceId ?? "?")")
                self?.lastWrittenToken = token
                self?.lastWriteTime = Date()
            }
        }
        #endif
    }
    
    /// Removes current device token from Firestore (call on sign out if desired)
    func removeToken() {
        guard !isPreview,
              let uid = currentUserId else { return }
        
        #if canImport(FirebaseFirestore)
        let deviceDoc = db.collection("users")
            .document(uid)
            .collection("devices")
            .document(deviceId)
        
        deviceDoc.delete { error in
            if let error = error {
                print("⚠️ PushTokenService: Failed to remove token: \(error)")
            } else {
                print("✅ PushTokenService: Token removed for device")
            }
        }
        #endif
    }
}
