//
//  StoryRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import FirebaseFirestore

protocol StoryRepositoryProtocol {
    func createStory(_ story: Story) async throws
    func fetchStories(userIds: [String]) async throws -> [Story]
    func deleteStory(storyId: String, userId: String) async throws

    /// Records a view for a story (increments viewCount and adds viewer to list)
    func recordView(storyId: String, storyOwnerId: String, viewerId: String, viewerName: String?, viewerAvatar: String?) async throws

    /// Fetches list of viewers for a story
    func fetchViewers(storyId: String, storyOwnerId: String) async throws -> [StoryViewer]
}

class FirestoreStoryRepository: StoryRepositoryProtocol {
    private let db = Firestore.firestore()
    
    // Create new story
    func createStory(_ story: Story) async throws {
        let ref = db.collection("users").document(story.ownerId).collection("stories").document(story.id)
        
        // Manual map for tighter control or Codable
        try ref.setData(from: story)
    }
    
    // Fetch stories for given users (Fan-in)
    // Fetches valid (non-expired) stories
    func fetchStories(userIds: [String]) async throws -> [Story] {
        guard !userIds.isEmpty else { return [] }
        
        // We can only query one collection at a time or use collectionGroup.
        // Queries by multiple paths are hard.
        // Strategy: "Fan-out Read" similar to Posts if limit is small (e.g. top 20 friends).
        // Or fetch active story *metadata* from a user field if available?
        // Assuming we iterate userIds (Top friends).
        
        // Optimization: Use `activeStoryCount` on User profile to skip users without stories?
        // For now, simpler Fan-out Read.
        
        var allStories: [Story] = []
        let now = Date()
        
        // Limit concurrency
        await withTaskGroup(of: [Story].self) { group in
            for uid in userIds.prefix(20) { // Limit to top 20 for simple implementation
                group.addTask {
                    let snapshot = try? await self.db.collection("users").document(uid).collection("stories")
                        .whereField("expiresAt", isGreaterThan: now)
                        .order(by: "expiresAt", descending: false) // Expiring soonest? or CreatedAt?
                        // Actually order by createdAt
                        .getDocuments()
                    
                    guard let docs = snapshot?.documents else { return [] }
                    
                    return docs.compactMap { doc in
                        try? doc.data(as: Story.self)
                    }
                }
            }
            
            for await stories in group {
                allStories.append(contentsOf: stories)
            }
        }
        
        return allStories.sorted(by: { $0.createdAt < $1.createdAt }) // Chronological
    }
    
    func deleteStory(storyId: String, userId: String) async throws {
        try await db.collection("users").document(userId).collection("stories").document(storyId).delete()
    }

    /// Records a view for a story
    func recordView(storyId: String, storyOwnerId: String, viewerId: String, viewerName: String?, viewerAvatar: String?) async throws {
        // Don't record owner's own view
        guard storyOwnerId != viewerId else { return }

        let storyRef = db.collection("users").document(storyOwnerId).collection("stories").document(storyId)
        let viewerRef = storyRef.collection("viewers").document(viewerId)

        // Check if already viewed
        let existingView = try? await viewerRef.getDocument()
        if existingView?.exists == true {
            return // Already viewed, don't increment again
        }

        // Use batch to atomically update viewCount and add viewer
        let batch = db.batch()

        // Increment view count
        batch.updateData(["viewCount": FieldValue.increment(Int64(1))], forDocument: storyRef)

        // Add viewer document
        var viewerData: [String: Any] = [
            "viewerId": viewerId,
            "viewedAt": FieldValue.serverTimestamp()
        ]
        if let name = viewerName { viewerData["viewerName"] = name }
        if let avatar = viewerAvatar { viewerData["viewerAvatar"] = avatar }

        batch.setData(viewerData, forDocument: viewerRef)

        try await batch.commit()
    }

    /// Fetches list of viewers for a story
    func fetchViewers(storyId: String, storyOwnerId: String) async throws -> [StoryViewer] {
        let snapshot = try await db.collection("users")
            .document(storyOwnerId)
            .collection("stories")
            .document(storyId)
            .collection("viewers")
            .order(by: "viewedAt", descending: true)
            .limit(to: 100)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> StoryViewer? in
            let data = doc.data()
            guard let viewerId = data["viewerId"] as? String else { return nil }

            let viewedAt = (data["viewedAt"] as? Timestamp)?.dateValue()

            return StoryViewer(
                id: doc.documentID,
                viewerId: viewerId,
                viewerName: data["viewerName"] as? String,
                viewerAvatar: data["viewerAvatar"] as? String,
                viewedAt: viewedAt,
                reaction: data["reaction"] as? String
            )
        }
    }
}

// MARK: - Story Viewer Model
struct StoryViewer: Identifiable, Equatable {
    let id: String
    let viewerId: String
    let viewerName: String?
    let viewerAvatar: String?
    let viewedAt: Date?
    var reaction: String?
}
