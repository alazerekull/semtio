//
//  AuthManager.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import Combine
import SwiftUI // For UIWindowScene access
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
import FirebaseCore
#endif

@MainActor
final class AuthManager: NSObject, ObservableObject {
    @Published var uid: String? = nil
    @Published private(set) var isReady: Bool = false
    @Published var errorMessage: String? = nil
    
    // Internal cache
    private var cachedEmail: String? = nil
    
    #if canImport(FirebaseAuth)
    private var authStateListener: AuthStateDidChangeListenerHandle?
    #endif
    
    var email: String? {
        if let local = cachedEmail { return local }
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.email
        #else
        return nil
        #endif
    }
    
    var displayName: String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.displayName
        #else
        return nil
        #endif
    }
    
    func bootstrap() {
        #if canImport(FirebaseAuth)
        if let u = Auth.auth().currentUser?.uid {
            uid = u
        }
        #else
        uid = "mock-auth-uid"
        #endif
        
        // Fix: Call with empty closure to satisfy requirement
        #if canImport(FirebaseAuth)
        startAuthStateListener { _ in }
        #endif
        
        isReady = true
    }
    
    /// Starts listening to Auth state changes and notifies listeners.
    #if canImport(FirebaseAuth)
    func startAuthStateListener(onUserChanged: @escaping (FirebaseAuth.User?) -> Void) {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.uid = user?.uid
            if let u = user {
                self?.cachedEmail = u.email
            }
            onUserChanged(user)
        }
    }
    #else
    // Mock implementation for previews or non-firebase builds
    func startAuthStateListener(onUserChanged: @escaping (Any?) -> Void) {
        // No-op
    }
    #endif
    
    // MARK: - Sign In Methods
    
    #if canImport(GoogleSignIn)
    func signInWithGoogle() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Google Sign-In requires a visible window."
            return
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing ID Token"])
            }
            let accessToken = result.user.accessToken.tokenString
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            let authResult = try await Auth.auth().signIn(with: credential)
            uid = authResult.user.uid
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    #else
    func signInWithGoogle() async {
        print("⚠️ Google Sign-In not available (Framework missing) - Simulating Mock Login")
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        uid = "mock-google-uid"
        errorMessage = nil
    }
    #endif
    
    func signInWithApple(idToken: String, nonce: String) async {
        #if canImport(FirebaseAuth)
        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: nil)
        do {
            let result = try await Auth.auth().signIn(with: credential)
            uid = result.user.uid
        } catch {
            let nsError = error as NSError
            if nsError.code == 17012 { // accountExistsWithDifferentCredential
                 errorMessage = "Bu e-posta adresiyle ilişkili başka bir hesap var. Lütfen önce o yöntemle giriş yapın."
            } else {
                 errorMessage = error.localizedDescription
            }
        }
        #endif
    }
    
    // MARK: - Email/Password Authentication
    
    /// Creates a new user account with email and password.
    func signUpWithEmail(email: String, password: String) async -> Bool {
        #if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            uid = result.user.uid
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        #else
        uid = "mock-email-uid"
        return true
        #endif
    }
    
    /// Signs in an existing user with email and password.
    func signInWithEmail(email: String, password: String) async -> Bool {
        #if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            uid = result.user.uid
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        #else
        uid = "mock-email-uid"
        return true
        #endif
    }
    
    func signOut() async {
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
            uid = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        #else
        uid = nil
        #endif
    }
    
    // MARK: - Password Management
    
    /// Checks if current user has password provider (email/password auth).
    var hasPasswordProvider: Bool {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return false }
        return user.providerData.contains { $0.providerID == "password" }
        #else
        return true // Mock
        #endif
    }
    
    /// Returns the auth provider type for display.
    var authProviderName: String {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return "Bilinmiyor" }
        for providerData in user.providerData {
            switch providerData.providerID {
            case "apple.com": return "Apple"
            case "google.com": return "Google"
            case "password": return "E-posta"
            default: continue
            }
        }
        return "Bilinmiyor"
        #else
        return "Mock"
        #endif
    }
    
    /// Re-authenticates user with current password (required before password change).
    func reauthenticateWithPassword(currentPassword: String) async throws {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            throw PasswordError.noEmailUser
        }
        
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        try await user.reauthenticate(with: credential)
        #endif
    }
    
    /// Changes user's password after successful re-authentication.
    func updatePassword(newPassword: String) async throws {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            throw PasswordError.noEmailUser
        }
        try await user.updatePassword(to: newPassword)
        #endif
    }
    
    // MARK: - Account Management
    
    /// Links Apple ID credential to current account (e.g. after merging conflict).
    func linkAppleAccount(idToken: String, nonce: String) async throws {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return }
        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: nil)
        
        let result = try await user.link(with: credential)
        uid = result.user.uid
        #endif
    }
    
    /// Deletes the user account permanently (Auth).
    /// Note: Caller must handle Firestore soft-deletion before calling this.
    func deleteAccount() async throws {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
        self.uid = nil
        #else
        self.uid = nil
        #endif
    }
}

// MARK: - Password Errors

enum PasswordError: LocalizedError {
    case noEmailUser
    case passwordTooShort
    case passwordMismatch
    case wrongCurrentPassword
    
    var errorDescription: String? {
        switch self {
        case .noEmailUser:
            return "E-posta/şifre hesabı bulunamadı."
        case .passwordTooShort:
            return "Şifre en az 8 karakter olmalı."
        case .passwordMismatch:
            return "Şifreler eşleşmiyor."
        case .wrongCurrentPassword:
            return "Mevcut şifre yanlış."
        }
    }
}
