//
//  BiometricAuth.swift
//  SemtioApp
//
//  Copyright © 2026 Oguzhan Cankaya ve Fikir Creative. All rights reserved.
//
//  Biometric authentication (FaceID/TouchID) wrapper.
//

import Foundation
import LocalAuthentication

enum BiometricType {
    case none
    case touchID
    case faceID
}

enum BiometricError: LocalizedError {
    case notAvailable
    case notEnrolled
    case userCancel
    case userFallback
    case systemCancel
    case lockout
    case invalidContext
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biyometrik kimlik dogrulama bu cihazda kullanilabilir degil."
        case .notEnrolled:
            return "Biyometrik kimlik dogrulama ayarlanmamis."
        case .userCancel:
            return "Kimlik dogrulama iptal edildi."
        case .userFallback:
            return "Sifre ile devam et."
        case .systemCancel:
            return "Sistem kimlik dogrulamayi iptal etti."
        case .lockout:
            return "Biyometrik kimlik dogrulama kilitlendi. Cihaz sifresiyle dogrulama gerekli."
        case .invalidContext:
            return "Gecersiz kimlik dogrulama durumu."
        case .unknown(let message):
            return message
        }
    }
}

final class BiometricAuth: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = BiometricAuth()

    private init() {}

    // MARK: - Public Properties

    /// Returns the type of biometric available on this device
    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .opticID:
            return .faceID // Treat opticID as faceID for UI purposes
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    /// Checks if biometric authentication is available
    var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Returns the localized name for the biometric type
    var biometricName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .none:
            return "Biyometrik"
        }
    }

    /// System image name for the biometric type
    var biometricIcon: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .none:
            return "lock.fill"
        }
    }

    // MARK: - Authentication

    /// Authenticates using biometrics
    /// - Parameter reason: The reason shown to the user
    /// - Returns: True if authentication succeeded
    func authenticate(reason: String = "Gizli sohbetlere erisim icin dogrulayin") async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Sifre Kullan"
        context.localizedCancelTitle = "Iptal"

        var error: NSError?

        // Check if biometrics are available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("⚠️ BiometricAuth: Biometrics not available: \(error?.localizedDescription ?? "unknown")")
            return false
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, authError in
                if success {
                    continuation.resume(returning: true)
                } else {
                    if let error = authError as? LAError {
                        print("⚠️ BiometricAuth: Authentication failed: \(error.localizedDescription)")

                        switch error.code {
                        case .userFallback:
                            // User wants to use password instead
                            break
                        case .userCancel:
                            // User cancelled
                            break
                        case .biometryLockout:
                            // Too many failed attempts
                            break
                        default:
                            break
                        }
                    }
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Authenticates using biometrics with detailed error handling
    /// - Parameter reason: The reason shown to the user
    /// - Returns: Result with success or specific error
    func authenticateWithResult(reason: String = "Gizli sohbetlere erisim icin dogrulayin") async -> Result<Void, BiometricError> {
        let context = LAContext()
        context.localizedFallbackTitle = "Sifre Kullan"
        context.localizedCancelTitle = "Iptal"

        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let laError = error as? LAError {
                return .failure(mapLAError(laError))
            }
            return .failure(.notAvailable)
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, authError in
                if success {
                    continuation.resume(returning: .success(()))
                } else if let laError = authError as? LAError {
                    continuation.resume(returning: .failure(self.mapLAError(laError)))
                } else {
                    continuation.resume(returning: .failure(.unknown(authError?.localizedDescription ?? "Bilinmeyen hata")))
                }
            }
        }
    }

    /// Authenticates with biometrics, falling back to device passcode if needed
    func authenticateWithPasscodeFallback(reason: String = "Gizli sohbetlere erisim icin dogrulayin") async -> Bool {
        let context = LAContext()

        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            ) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    // MARK: - Private

    private func mapLAError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .userCancel:
            return .userCancel
        case .userFallback:
            return .userFallback
        case .systemCancel:
            return .systemCancel
        case .biometryLockout:
            return .lockout
        case .invalidContext:
            return .invalidContext
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
