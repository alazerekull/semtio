//
//  FirestoreFeedRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import FirebaseFirestore

final class FirestoreFeedRepository: FeedRepositoryProtocol {
    private let db = Firestore.firestore()
    
    // Dependencies to help with mapping if needed, 
    // but for performance we might do raw batch fetches here.
    // For now, let's implement raw batch fetches to avoid circular dependencies or overhead.
    
    func fetchFeed(limit: Int, startAfter: DocumentSnapshot?) async throws -> FeedPage {
        // 1. Query feed_items
        var query = db.collection("feed_items")
            .whereField("visibility", isEqualTo: "public")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        
        if let startAfter = startAfter {
            query = query.start(afterDocument: startAfter)
        }
        
        let snapshot = try await query.getDocuments()
        let feedItems = snapshot.documents.compactMap { FeedItem.fromDoc($0) }
        
        if feedItems.isEmpty {
            return FeedPage(items: [], lastSnapshot: snapshot.documents.last, hasMore: false)
        }
        
        // 2. Separate IDs by type
        let postIds = feedItems.filter { $0.type == .post }.map { $0.refId }
        let eventIds = feedItems.filter { $0.type == .event }.map { $0.refId }
        
        // 3. Batch Fetch (Fan-out on Read)
        // Note: Firestore 'in' query is limited to 30 items. 
        // If limit is 20, we are safe. 
        // If limit > 30, we must chunk. pageSize is typically 20.
        
        async let postsMap = fetchPosts(ids: postIds)
        async let eventsMap = fetchEvents(ids: eventIds)
        
        let (posts, events) = try await (postsMap, eventsMap)
        
        // 4. Merge and preserve order
        var unifiedItems: [UnifiedFeedItem] = []
        
        for item in feedItems {
            switch item.type {
            case .post:
                if let post = posts[item.refId] {
                    unifiedItems.append(.post(post))
                }
            case .event:
                if let event = events[item.refId] {
                    unifiedItems.append(.event(event))
                }
            case .sponsor:
                break // TODO: Implement ads
            }
        }
        
        let hasMore = snapshot.documents.count == limit
        return FeedPage(items: unifiedItems, lastSnapshot: snapshot.documents.last, hasMore: hasMore)
    }
    
    func refreshFeed(limit: Int) async throws -> FeedPage {
        return try await fetchFeed(limit: limit, startAfter: nil)
    }
    
    // MARK: - Private Helpers
    
    // Helper to reuse the mapping logic from other repositories would be ideal,
    // but duplicating simple mapping here prevents tight coupling with big Repositories.
    // Ideally we'd use a shared Mapper class.
    // For this task, I'll rely on our known mapDocumentToEvent/Post logic or helpers.
    // Assuming EventRepository/PostRepository have static mappers or we just copy logic.
    // Copying logic for now to ensure this file is self-contained and performant.
    
    private func fetchPosts(ids: [String]) async throws -> [String: Post] {
        guard !ids.isEmpty else { return [:] }
        let chunks = ids.chunked(into: 10)
        var results: [String: Post] = [:]
        
        for chunk in chunks {
            let snapshot = try await db.collection("posts")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            
            for doc in snapshot.documents {
                if let post = mapDocumentToPost(doc) {
                    results[post.id] = post
                }
            }
        }
        return results
    }
    
    private func fetchEvents(ids: [String]) async throws -> [String: Event] {
        guard !ids.isEmpty else { return [:] }
        let chunks = ids.chunked(into: 10)
        var results: [String: Event] = [:]
        
        for chunk in chunks {
            let snapshot = try await db.collection("events")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            
            for doc in snapshot.documents {
                if let event = mapDocumentToEvent(doc) {
                    results[event.id] = event
                }
            }
        }
        return results
    }
    
    // Minimal Mappers (Duplicated for isolation/performance optimization)
    // In a real refactor, move these to `Post+Firestore.swift` etc.
    
    private func mapDocumentToPost(_ doc: DocumentSnapshot) -> Post? {
        // ... (Basic mapping leveraging existing model init)
        // Need to be careful to parse correctly.
        // Importing Post/Event models implicitly.
        guard let data = doc.data() else { return nil }
        // Simplified mapping for brevity/speed - ensure critical fields
        let id = doc.documentID
        return Post(
            id: id,
            ownerId: data["ownerId"] as? String ?? "",
            ownerUsername: data["ownerUsername"] as? String ?? "User",
            ownerDisplayName: data["ownerDisplayName"] as? String ?? "User",
            ownerAvatarURL: data["ownerAvatarURL"] as? String,
            caption: data["caption"] as? String ?? "",
            mediaURLs: data["mediaURLs"] as? [String] ?? [],
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            likeCount: data["likeCount"] as? Int ?? 0,
            commentCount: data["commentCount"] as? Int ?? 0,
            visibility: data["visibility"] as? String ?? "public",
            type: Post.PostType(rawValue: data["type"] as? String ?? "standard") ?? .standard,
            eventId: data["eventId"] as? String,
            eventName: data["eventName"] as? String,
            isLiked: false // User specific - needs separate query or state
        )
    }
    
    private func mapDocumentToEvent(_ doc: DocumentSnapshot) -> Event? {
        guard let data = doc.data() else { return nil }
        return Event(
            id: doc.documentID,
            title: data["title"] as? String ?? "",
            description: data["description"] as? String,
            startDate: (data["startAt"] as? Timestamp)?.dateValue() ?? Date(),
            endDate: (data["endAt"] as? Timestamp)?.dateValue(),
            locationName: data["locationName"] as? String,
            semtName: data["semtName"] as? String,
            hostUserId: data["hostUserId"] as? String,
            participantCount: data["participantCount"] as? Int ?? 0,
            coverColorHex: data["coverColorHex"] as? String,
            category: EventCategory(rawValue: data["category"] as? String ?? "other") ?? .other,
            lat: data["locationLat"] as? Double ?? 0.0,
            lon: data["locationLng"] as? Double ?? 0.0,
            coverImageURL: data["coverImageURL"] as? String,
            capacityLimit: data["capacityLimit"] as? Int,
            tags: data["tags"] as? [String] ?? [],
            isFeatured: data["isFeatured"] as? Bool ?? false,
            createdBy: data["createdBy"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            district: data["district"] as? String,
            visibility: EventVisibility(rawValue: data["visibility"] as? String ?? "public") ?? .public
        )
    }
}


