//
//  HiddenPinManager.swift
//  SemtioApp
//
//  Copyright © 2026 Oguzhan Cankaya ve Fikir Creative. All rights reserved.
//
//  Manages hidden chat PIN with Keychain caching and Firestore persistence.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class HiddenPinManager: ObservableObject {

    // MARK: - Singleton

    static let shared = HiddenPinManager()

    // MARK: - Published State

    @Published private(set) var hasPinSet: Bool = false
    @Published private(set) var isLocked: Bool = false
    @Published private(set) var failCount: Int = 0

    // MARK: - Constants

    private let maxFailAttempts = 5
    private let lockoutDuration: TimeInterval = 300 // 5 minutes

    // MARK: - Private

    private var cachedHash: String?
    private var cachedSalt: String?
    private var lockedUntil: Date?

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif

    private init() {
        Task {
            await loadFromKeychain()
        }
    }

    // MARK: - Public API

    /// Checks if PIN is set (from cache or Firestore)
    func checkPinStatus() async -> Bool {
        // First check Keychain cache
        if cachedHash != nil && cachedSalt != nil {
            hasPinSet = true
            return true
        }

        // Then check Firestore
        guard let uid = currentUid else {
            hasPinSet = false
            return false
        }

        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("users").document(uid)
                .collection("private").document("security")
                .getDocument()
                
            if let data = doc.data(),
               let hash = data["hiddenPinHash"] as? String,
               let salt = data["hiddenPinSalt"] as? String,
               !hash.isEmpty, !salt.isEmpty {
                // Sync to Keychain
                await syncToKeychain(hash: hash, salt: salt, uid: uid)
                hasPinSet = true
                return true
            }
        } catch {
            print("⚠️ HiddenPinManager: Failed to check Firestore: \(error)")
        }
        #endif

        hasPinSet = false
        return false
    }

    /// Sets a new PIN
    /// - Parameter pin: The new PIN (6 digits recommended)
    /// - Returns: True if successful
    func setPin(_ pin: String) async -> Bool {
        guard let uid = currentUid else {
            print("⚠️ HiddenPinManager: No user logged in")
            return false
        }

        guard isValidPin(pin) else {
            print("⚠️ HiddenPinManager: Invalid PIN format")
            return false
        }

        // Generate hash and salt
        guard let result = PinCrypto.hashPin(pin) else {
            print("⚠️ HiddenPinManager: Failed to hash PIN")
            return false
        }

        let hash = result.hash
        let salt = result.salt

        // Save to Firestore (Secure Subcollection)
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("users").document(uid)
                .collection("private").document("security")
                .setData([
                    "hiddenPinHash": hash,
                    "hiddenPinSalt": salt,
                    "hiddenPinAlgo": "pbkdf2_sha256",
                    "hiddenPinSetAt": FieldValue.serverTimestamp(),
                    "hiddenPinFailCount": 0,
                    "hiddenPinLockedUntil": NSNull()
                ], merge: true)
        } catch {
            print("⚠️ HiddenPinManager: Failed to save to Firestore: \(error)")
            return false
        }
        #endif

        // Cache in Keychain
        await syncToKeychain(hash: hash, salt: salt, uid: uid)

        hasPinSet = true
        failCount = 0
        isLocked = false
        lockedUntil = nil

        return true
    }

    /// Verifies a PIN
    /// - Parameter pin: The PIN to verify
    /// - Returns: True if correct
    func verifyPin(_ pin: String) async -> Bool {
        // Check lockout
        if let lockTime = lockedUntil, Date() < lockTime {
            isLocked = true
            return false
        }

        isLocked = false

        guard let uid = currentUid else { return false }

        // Try Keychain first
        if let hash = cachedHash, let salt = cachedSalt {
            let isValid = PinCrypto.verifyPin(pin, storedHash: hash, storedSalt: salt)

            if isValid {
                await resetFailCount(uid: uid)
                return true
            } else {
                await incrementFailCount(uid: uid)
                return false
            }
        }

        // Fallback to Firestore
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("users").document(uid)
                .collection("private").document("security")
                .getDocument()
            
            guard let data = doc.data(),
                  let hash = data["hiddenPinHash"] as? String,
                  let salt = data["hiddenPinSalt"] as? String else {
                return false
            }

            // Sync to Keychain for next time
            await syncToKeychain(hash: hash, salt: salt, uid: uid)

            let isValid = PinCrypto.verifyPin(pin, storedHash: hash, storedSalt: salt)

            if isValid {
                await resetFailCount(uid: uid)
                return true
            } else {
                await incrementFailCount(uid: uid)
                return false
            }
        } catch {
            print("⚠️ HiddenPinManager: Failed to verify from Firestore: \(error)")
            return false
        }
        #else
        return false
        #endif
    }

    /// Resets the local PIN cache (forces re-fetch from Firestore)
    func resetLocalPinCache() {
        guard let uid = currentUid else { return }

        KeychainService.shared.delete(
            service: KeychainService.Service.hiddenPinHash,
            account: uid
        )
        KeychainService.shared.delete(
            service: KeychainService.Service.hiddenPinSalt,
            account: uid
        )

        cachedHash = nil
        cachedSalt = nil
        hasPinSet = false
    }

    /// Changes the PIN (requires current PIN verification first)
    func changePin(currentPin: String, newPin: String) async -> Bool {
        guard await verifyPin(currentPin) else {
            return false
        }

        return await setPin(newPin)
    }

    /// Removes the PIN entirely (requires current PIN verification)
    func removePin(currentPin: String) async -> Bool {
        guard await verifyPin(currentPin) else {
            return false
        }

        guard let uid = currentUid else { return false }

        // Remove from Firestore
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("users").document(uid)
                .collection("private").document("security")
                .updateData([
                    "hiddenPinHash": FieldValue.delete(),
                    "hiddenPinSalt": FieldValue.delete(),
                    "hiddenPinAlgo": FieldValue.delete(),
                    "hiddenPinSetAt": FieldValue.delete(),
                    "hiddenPinFailCount": FieldValue.delete(),
                    "hiddenPinLockedUntil": FieldValue.delete()
                ])
        } catch {
            print("⚠️ HiddenPinManager: Failed to remove from Firestore: \(error)")
            return false
        }
        #endif

        // Remove from Keychain
        resetLocalPinCache()

        return true
    }

    /// Returns remaining lockout time in seconds
    var remainingLockoutTime: TimeInterval {
        guard let lockTime = lockedUntil else { return 0 }
        let remaining = lockTime.timeIntervalSince(Date())
        return max(0, remaining)
    }

    // MARK: - Private Helpers

    private var currentUid: String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }

    private func loadFromKeychain() async {
        guard let uid = currentUid else { return }

        cachedHash = KeychainService.shared.getString(
            service: KeychainService.Service.hiddenPinHash,
            account: uid
        )

        cachedSalt = KeychainService.shared.getString(
            service: KeychainService.Service.hiddenPinSalt,
            account: uid
        )

        hasPinSet = cachedHash != nil && cachedSalt != nil

        // If not in Keychain, check Firestore
        if !hasPinSet {
            _ = await checkPinStatus()
        }
    }

    private func syncToKeychain(hash: String, salt: String, uid: String) async {
        KeychainService.shared.set(
            hash,
            service: KeychainService.Service.hiddenPinHash,
            account: uid
        )

        KeychainService.shared.set(
            salt,
            service: KeychainService.Service.hiddenPinSalt,
            account: uid
        )

        cachedHash = hash
        cachedSalt = salt
    }

    private func incrementFailCount(uid: String) async {
        failCount += 1

        if failCount >= maxFailAttempts {
            lockedUntil = Date().addingTimeInterval(lockoutDuration)
            isLocked = true
        }

        // Update Firestore
        #if canImport(FirebaseFirestore)
        do {
            var updateData: [String: Any] = [
                "hiddenPinFailCount": failCount
            ]

            if let lockTime = lockedUntil {
                updateData["hiddenPinLockedUntil"] = Timestamp(date: lockTime)
            }

            try await db.collection("users").document(uid)
                .collection("private").document("security")
                .updateData(updateData)
        } catch {
            print("⚠️ HiddenPinManager: Failed to update fail count: \(error)")
        }
        #endif
    }

    private func resetFailCount(uid: String) async {
        failCount = 0
        lockedUntil = nil
        isLocked = false

        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("users").document(uid)
                .collection("private").document("security")
                .updateData([
                    "hiddenPinFailCount": 0,
                    "hiddenPinLockedUntil": NSNull()
                ])
        } catch {
            print("⚠️ HiddenPinManager: Failed to reset fail count: \(error)")
        }
        #endif
    }

    private func isValidPin(_ pin: String) -> Bool {
        // PIN must be 4-8 digits
        let range = 4...8
        return range.contains(pin.count) && pin.allSatisfy { $0.isNumber }
    }
}
