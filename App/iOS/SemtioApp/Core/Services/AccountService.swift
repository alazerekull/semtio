//
//  AccountService.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Account management service for sign out and account deletion.
//  Firebase imports are ONLY in this file.
//

import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Account Service Protocol

protocol AccountServiceProtocol {
    /// Signs out the current user.
    func signOut() async throws
    
    /// Deletes the current user's account and associated data.
    /// May throw re-authentication required error.
    func deleteAccount() async throws
}

// MARK: - Account Service Errors

enum AccountError: LocalizedError {
    case notSignedIn
    case reAuthRequired
    case deletionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Giriş yapmış bir kullanıcı bulunamadı."
        case .reAuthRequired:
            return "Bu işlem için yeniden giriş yapmanız gerekiyor."
        case .deletionFailed(let reason):
            return "Hesap silinemedi: \(reason)"
        }
    }
}

// MARK: - Default Account Service

final class DefaultAccountService: AccountServiceProtocol {
    
    func signOut() async throws {
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
            print("✅ AccountService: User signed out")
        } catch {
            print("❌ AccountService: Sign out failed: \(error.localizedDescription)")
            throw error
        }
        #endif
    }
    
    func deleteAccount() async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let user = Auth.auth().currentUser else {
            throw AccountError.notSignedIn
        }
        
        let uid = user.uid
        let db = Firestore.firestore()
        
        // STEP 1: Delete Firestore data
        do {
            try await deleteFirestoreData(uid: uid, db: db)
            print("✅ AccountService: Firestore data deleted for \(uid)")
        } catch {
            print("⚠️ AccountService: Firestore cleanup partial/failed: \(error.localizedDescription)")
            // Continue with auth deletion even if Firestore cleanup fails
        }
        
        // STEP 2: Delete Firebase Auth user
        do {
            try await user.delete()
            print("✅ AccountService: Auth user deleted")
        } catch let error as NSError {
            // Check if re-auth is required
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                throw AccountError.reAuthRequired
            }
            throw AccountError.deletionFailed(error.localizedDescription)
        }
        #else
        print("⚠️ AccountService: Firebase not available, mock deletion")
        #endif
    }
    
    // MARK: - Firestore Cleanup
    
    #if canImport(FirebaseFirestore)
    private func deleteFirestoreData(uid: String, db: Firestore) async throws {
        let batch = db.batch()
        
        // 1. Delete users/{uid}
        let userRef = db.collection("users").document(uid)
        batch.deleteDocument(userRef)
        
        // 2. Delete friend_requests where fromUid == uid
        let outgoingRequests = try await db.collection("friend_requests")
            .whereField("fromUid", isEqualTo: uid)
            .getDocuments()
        
        for doc in outgoingRequests.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // 3. Delete friend_requests where toUid == uid
        let incomingRequests = try await db.collection("friend_requests")
            .whereField("toUid", isEqualTo: uid)
            .getDocuments()
        
        for doc in incomingRequests.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // Commit batch for requests
        try await batch.commit()
        
        // 4. Delete friends/{uid}/list/* subcollection
        let friendsList = try await db.collection("friends")
            .document(uid)
            .collection("list")
            .getDocuments()
        
        let friendBatch = db.batch()
        for doc in friendsList.documents {
            friendBatch.deleteDocument(doc.reference)
        }
        
        // Delete the friends/{uid} document itself
        let friendsDocRef = db.collection("friends").document(uid)
        friendBatch.deleteDocument(friendsDocRef)
        
        try await friendBatch.commit()
        
        // TODO: Clean up chats where user is participant
        // Decision needed: Delete messages or just remove from participants?
        
        // TODO: Clean up events created by user
        // Decision needed: Transfer ownership or delete events?
    }
    #endif
}

// MARK: - Mock Account Service (for testing)

final class MockAccountService: AccountServiceProtocol {
    func signOut() async throws {
        print("🧪 MockAccountService: Sign out simulated")
    }
    
    func deleteAccount() async throws {
        print("🧪 MockAccountService: Account deletion simulated")
    }
}
