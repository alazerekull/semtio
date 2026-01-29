//
//  MockFeedRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import FirebaseFirestore

final class MockFeedRepository: FeedRepositoryProtocol {
    
    func fetchFeed(limit: Int, startAfter: DocumentSnapshot?) async throws -> FeedPage {
        try? await Task.sleep(nanoseconds: 500_000_000) // Simulate latency
        
        var items: [UnifiedFeedItem] = []
        
        for i in 0..<limit {
            if i % 3 == 0 {
                // Event
                items.append(.event(Event(
                    id: UUID().uuidString,
                    title: "Mock Event \(i)",
                    description: "An event description",
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(3600),
                    locationName: "Mock Location",
                    semtName: nil,
                    hostUserId: "mock_user",
                    participantCount: 5,
                    coverColorHex: nil,
                    category: .meetup,
                    lat: 0,
                    lon: 0,
                    coverImageURL: nil,
                    capacityLimit: nil,
                    tags: [],
                    isFeatured: false,
                    createdBy: "mock_user",
                    createdAt: Date(),
                    district: nil,
                    visibility: .public
                )))
            } else {
                // Post
                items.append(.post(Post(
                    id: UUID().uuidString,
                    ownerId: "mock_user",
                    ownerUsername: "mock_user",
                    ownerDisplayName: "Mock User",
                    ownerAvatarURL: nil,
                    caption: "This is a mock post #\(i)",
                    mediaURLs: [],
                    createdAt: Date(),
                    updatedAt: Date(),
                    likeCount: 10,
                    commentCount: 2,
                    visibility: "public",
                    type: .standard,
                    eventId: nil,
                    eventName: nil
                )))
            }
        }
        
        return FeedPage(items: items, lastSnapshot: nil, hasMore: true)
    }
    
    func refreshFeed(limit: Int) async throws -> FeedPage {
        return try await fetchFeed(limit: limit, startAfter: nil)
    }
}
