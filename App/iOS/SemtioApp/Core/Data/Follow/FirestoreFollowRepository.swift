//
//  FirestoreFollowRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import FirebaseFirestore

class FirestoreFollowRepository: FollowRepositoryProtocol {
    
    private let db = Firestore.firestore()
    
    func follow(userId: String, targetUserId: String) async throws {
        let followerRef = db.collection("followers").document(targetUserId).collection("list").document(userId)
        let followingRef = db.collection("following").document(userId).collection("list").document(targetUserId)
        
        let batch = db.batch()
        
        let data: [String: Any] = [
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        batch.setData(data, forDocument: followerRef)
        batch.setData(data, forDocument: followingRef)
        
        try await batch.commit()
    }
    
    func unfollow(userId: String, targetUserId: String) async throws {
        let followerRef = db.collection("followers").document(targetUserId).collection("list").document(userId)
        let followingRef = db.collection("following").document(userId).collection("list").document(targetUserId)
        
        let batch = db.batch()
        
        batch.deleteDocument(followerRef)
        batch.deleteDocument(followingRef)
        
        try await batch.commit()
    }
    
    func isFollowing(userId: String, targetUserId: String) async throws -> Bool {
        let doc = try await db.collection("following").document(userId).collection("list").document(targetUserId).getDocument()
        return doc.exists
    }
    
    func fetchFollowerCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection("followers").document(userId).collection("list").count.getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    func fetchFollowingCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection("following").document(userId).collection("list").count.getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }

    func fetchFollowingIds(userId: String) async throws -> [String] {
        let snapshot = try await db.collection("following").document(userId).collection("list").getDocuments()
        return snapshot.documents.map { $0.documentID }
    }

    func fetchFollowerIds(userId: String) async throws -> [String] {
        let snapshot = try await db.collection("followers").document(userId).collection("list").getDocuments()
        return snapshot.documents.map { $0.documentID }
    }
}
