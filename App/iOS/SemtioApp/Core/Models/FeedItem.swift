//
//  FeedItem.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import FirebaseFirestore

enum FeedItemType: String, Codable {
    case event
    case post
    case sponsor
}

/// Represents a pointer in the global 'feed_items' collection.
/// This is used for indexing and ranking the unified feed.
struct FeedItem: Identifiable, Codable {
    let id: String
    let type: FeedItemType
    let refId: String
    let authorId: String
    let createdAt: Date
    let visibility: String // "public" | "private"
    let score: Double? // For ranking algorithms
    
    // Optional: Denormalized data for quicker feed rendering (Activity Feed pattern)
    // If these are present, we might skip fetching the full object for simple views.
    // The requirement suggests resolving, but having some data here helps performance.
    
    #if canImport(FirebaseFirestore)
    static func fromDoc(_ doc: DocumentSnapshot) -> FeedItem? {
        guard let data = doc.data() else { return nil }
        
        guard
            let typeRaw = data["type"] as? String,
            let type = FeedItemType(rawValue: typeRaw),
            let refId = data["refId"] as? String,
            let authorId = data["authorId"] as? String
        else { return nil }
        
        let id = doc.documentID
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let visibility = data["visibility"] as? String ?? "public"
        let score = data["score"] as? Double
        
        return FeedItem(
            id: id,
            type: type,
            refId: refId,
            authorId: authorId,
            createdAt: createdAt,
            visibility: visibility,
            score: score
        )
    }
    #endif
}
