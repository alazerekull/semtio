//
//  FirestoreAnnouncementRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  FINAL FIRESTORE ANNOUNCEMENT SCHEMA:
//  announcements/{announcementId}
//  - title: String
//  - body: String
//  - isActive: Bool
//  - priority: Int (higher = more important)
//  - createdAt: serverTimestamp
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore

final class FirestoreAnnouncementRepository: AnnouncementRepositoryProtocol {
    private let db = Firestore.firestore()
    
    // MARK: - Fetch Active Announcements
    
    func fetchActiveAnnouncements() async throws -> [Announcement] {
        let snapshot = try await db.collection("announcements")
            .whereField("isActive", isEqualTo: true)
            // .order(by: "priority", descending: true) -- Removed
            .limit(to: 10)
            .getDocuments()
        
        return snapshot.documents.compactMap { mapDocumentToAnnouncement($0) }
            .sorted { ($0.priority ?? 0) > ($1.priority ?? 0) }
    }
    
    // MARK: - Fetch Latest (for banner)
    
    func fetchLatestAnnouncement() async throws -> Announcement? {
        let snapshot = try await db.collection("announcements")
            .whereField("isActive", isEqualTo: true)
            // .order(by: "priority", descending: true) -- Removed
            .limit(to: 10) // Limit increased to allow in-memory sort finding the top one
            .getDocuments()
        
        // Manual sort and take first
        return snapshot.documents.compactMap { mapDocumentToAnnouncement($0) }
            .sorted { ($0.priority ?? 0) > ($1.priority ?? 0) }
            .first
    }
    
    // MARK: - Fetch by ID
    
    func fetchAnnouncement(id: String) async throws -> Announcement? {
        let doc = try await db.collection("announcements").document(id).getDocument()
        guard doc.exists else { return nil }
        return mapDocumentToAnnouncement(doc)
    }
    
    // MARK: - Mapping
    
    private func mapDocumentToAnnouncement(_ doc: DocumentSnapshot) -> Announcement? {
        guard let data = doc.data() else { return nil }
        
        let actionURLString = data["actionURL"] as? String
        let actionURL = actionURLString != nil ? URL(string: actionURLString!) : nil
        
        return Announcement(
            id: doc.documentID,
            title: data["title"] as? String ?? "",
            body: data["body"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            isActive: data["isActive"] as? Bool ?? true,
            priority: data["priority"] as? Int,
            actionURL: actionURL
        )
    }
    
    private func mapDocumentToAnnouncement(_ doc: QueryDocumentSnapshot) -> Announcement? {
        let data = doc.data()
        
        let actionURLString = data["actionURL"] as? String
        let actionURL = actionURLString != nil ? URL(string: actionURLString!) : nil
        
        return Announcement(
            id: doc.documentID,
            title: data["title"] as? String ?? "",
            body: data["body"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            isActive: data["isActive"] as? Bool ?? true,
            priority: data["priority"] as? Int,
            actionURL: actionURL
        )
    }
}
#endif
