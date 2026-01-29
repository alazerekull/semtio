//
//  FeedRepositoryProtocol.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import FirebaseFirestore

struct FeedPage {
    let items: [UnifiedFeedItem]
    let lastSnapshot: DocumentSnapshot?
    let hasMore: Bool
}

protocol FeedRepositoryProtocol {
    /// Fetches the unified feed with pagination
    func fetchFeed(limit: Int, startAfter: DocumentSnapshot?) async throws -> FeedPage
    
    /// Pull-to-refresh: fetches the latest items (startAfter nil)
    func refreshFeed(limit: Int) async throws -> FeedPage
}
