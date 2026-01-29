//
//  MockPostRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

class MockPostRepository: PostRepositoryProtocol {
    
    // Shared storage to simulate persistent DB across instances
    static var sharedPosts: [Post] = []
    static var sharedComments: [String: [PostComment]] = [:]
    
    var mockPosts: [Post] {
        get { return Self.sharedPosts }
        set { Self.sharedPosts = newValue }
    }
    
    var mockComments: [String: [PostComment]] {
        get { return Self.sharedComments }
        set { Self.sharedComments = newValue }
    }
    
    init() {
        // Only generate if empty (first init)
        if Self.sharedPosts.isEmpty {
            var posts: [Post] = []
            
            // Generate some dummy data
            for i in 1...10 {
                posts.append(Post(
                    id: "post_\(i)",
                    ownerId: "user_\(i)",
                    ownerUsername: "user\(i)",
                    ownerDisplayName: "User \(i)",
                    ownerAvatarURL: nil,
                    caption: "This is a mock post caption number \(i). #mock #semtio",
                    mediaURLs: ["mock://image/random=\(i)"],
                    createdAt: Date().addingTimeInterval(TimeInterval(-i * 3600)),
                    updatedAt: Date(),
                    likeCount: Int.random(in: 0...100),
                    commentCount: Int.random(in: 0...10),
                    visibility: "public"
                ))
            }
            
            // Add some mock activity posts
            posts.append(Post(
                id: "activity_1",
                ownerId: "user_2",
                ownerUsername: "user2",
                ownerDisplayName: "User 2",
                ownerAvatarURL: nil,
                caption: "",
                mediaURLs: [],
                createdAt: Date().addingTimeInterval(-1000),
                updatedAt: Date(),
                likeCount: 0,
                commentCount: 0,
                visibility: "public",
                type: .userJoinedEvent,
                eventId: "event_1",
                eventName: "Rock Konseri"
            ))
            
            posts.append(Post(
                id: "activity_2",
                ownerId: "user_3",
                ownerUsername: "user3",
                ownerDisplayName: "User 3",
                ownerAvatarURL: nil,
                caption: "",
                mediaURLs: [],
                createdAt: Date().addingTimeInterval(-5000),
                updatedAt: Date(),
                likeCount: 0,
                commentCount: 0,
                visibility: "public",
                type: .userCreatedEvent,
                eventId: "event_2",
                eventName: "Doğa Yürüyüşü"
            ))
            
            // Sort by date
            posts.sort(by: { $0.createdAt > $1.createdAt })
            
            Self.sharedPosts = posts
        }
    }
    
    func fetchFeedPosts(limit: Int, cursor: Any?) async throws -> (posts: [Post], cursor: Any?, hasMore: Bool) {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let startIndex: Int
        if let cursorId = cursor as? String, let index = mockPosts.firstIndex(where: { $0.id == cursorId }) {
            startIndex = index + 1
        } else {
            startIndex = 0
        }
        
        let endIndex = min(startIndex + limit, mockPosts.count)
        guard startIndex < mockPosts.count else {
            return ([], nil, false)
        }
        
        let page = Array(mockPosts[startIndex..<endIndex])
        let nextCursor = page.last?.id
        let hasMore = endIndex < mockPosts.count
        
        return (page, nextCursor, hasMore)
    }
    
    func fetchPostsByAuthors(authorIds: [String], limit: Int, cursor: Any?) async throws -> (posts: [Post], cursor: Any?, hasMore: Bool) {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let filteredPosts = mockPosts
            .filter { authorIds.contains($0.ownerId) }
            .sorted(by: { $0.createdAt > $1.createdAt })
        
        let startIndex: Int
        if let cursorId = cursor as? String, let index = filteredPosts.firstIndex(where: { $0.id == cursorId }) {
            startIndex = index + 1
        } else {
            startIndex = 0
        }
        
        let endIndex = min(startIndex + limit, filteredPosts.count)
        guard startIndex < filteredPosts.count else {
            return ([], nil, false)
        }
        
        let page = Array(filteredPosts[startIndex..<endIndex])
        let nextCursor = page.last?.id
        let hasMore = endIndex < filteredPosts.count
        
        return (page, nextCursor, hasMore)
    }
    
    func fetchPost(postId: String) async throws -> Post {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        if let post = mockPosts.first(where: { $0.id == postId }) {
            return post
        }
        
        throw NSError(domain: "MockPostRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Mock Post not found"])
    }
    
    func fetchPost(postId: String, userId: String) async throws -> Post {
        // Forward to normal fetch for mock
        return try await fetchPost(postId: postId)
    }
    
    func fetchPostsByUser(userId: String, limit: Int, cursor: Any?) async throws -> (posts: [Post], cursor: Any?, hasMore: Bool) {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Filter by user
        let userPosts = mockPosts.filter { $0.ownerId == userId }.sorted(by: { $0.createdAt > $1.createdAt })
        
        let startIndex: Int
        if let cursorId = cursor as? String, let index = userPosts.firstIndex(where: { $0.id == cursorId }) {
            startIndex = index + 1
        } else {
            startIndex = 0
        }
        
        let endIndex = min(startIndex + limit, userPosts.count)
        guard startIndex < userPosts.count else {
            return ([], nil, false)
        }
        
        let page = Array(userPosts[startIndex..<endIndex])
        let nextCursor = page.last?.id
        let hasMore = endIndex < userPosts.count
        
        return (page, nextCursor, hasMore)
    }
    
    func createPost(_ post: Post) async throws {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        mockPosts.insert(post, at: 0)
    }
    
    var likedPostsState: Set<String> = [] // "postId_uid"
    
    func likePost(postId: String, ownerId: String, uid: String) async throws {
        try? await Task.sleep(nanoseconds: 300_000_000)
        likedPostsState.insert("\(postId)_\(uid)")
        if let _ = mockPosts.firstIndex(where: { $0.id == postId }) {
            // Mock increment for current session
            print("Mock: Liked post \(postId)")
        }
    }
    
    func unlikePost(postId: String, ownerId: String, uid: String) async throws {
        try? await Task.sleep(nanoseconds: 300_000_000)
        likedPostsState.remove("\(postId)_\(uid)")
        print("Mock: Unliked post \(postId)")
    }
    
    func isPostLiked(postId: String, uid: String) async throws -> Bool {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return likedPostsState.contains("\(postId)_\(uid)")
    }
    
    func fetchComments(postId: String, limit: Int) async throws -> [PostComment] {
        try? await Task.sleep(nanoseconds: 500_000_000)
        return mockComments[postId] ?? []
    }
    
    func addComment(postId: String, uid: String, text: String, username: String?, userDisplayName: String?, userAvatarURL: String?) async throws -> PostComment {
        try? await Task.sleep(nanoseconds: 800_000_000)
        
        let comment = PostComment(
            id: UUID().uuidString,
            postId: postId,
            uid: uid,
            username: username,
            userDisplayName: userDisplayName,
            userAvatarURL: userAvatarURL,
            text: text,
            createdAt: Date()
        )
        
        var comments = mockComments[postId] ?? []
        comments.append(comment)
        mockComments[postId] = comments
        
        return comment
    }

    
    func fetchPostCount(userId: String) async throws -> Int {
        return Int.random(in: 5...50)
    }
    
    // MARK: - Delete Post
    
    func deletePost(postId: String, userId: String) async throws {
        MockPostRepository.sharedPosts.removeAll { $0.id == postId }
        print("🗑️ MockPostRepository: Post deleted: \(postId)")
    }
    
    // MARK: - Saved Posts
    
    private static var savedPostIds: Set<String> = []
    
    func savePost(postId: String, userId: String) async throws {
        MockPostRepository.savedPostIds.insert(postId)
        print("🔖 MockPostRepository: Post saved: \(postId)")
    }
    
    func unsavePost(postId: String, userId: String) async throws {
        MockPostRepository.savedPostIds.remove(postId)
        print("🔖 MockPostRepository: Post unsaved: \(postId)")
    }
    
    func isPostSaved(postId: String, userId: String) async throws -> Bool {
        return MockPostRepository.savedPostIds.contains(postId)
    }
    
    func fetchSavedPosts(userId: String) async throws -> [Post] {
        return MockPostRepository.sharedPosts.filter { MockPostRepository.savedPostIds.contains($0.id) }
    }
}
