//
//  PostRepositoryProtocol.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

protocol PostRepositoryProtocol {
    func fetchFeedPosts(limit: Int, cursor: Any?) async throws -> (posts: [Post], cursor: Any?, hasMore: Bool)
    func fetchPostsByAuthors(authorIds: [String], limit: Int, cursor: Any?) async throws -> (posts: [Post], cursor: Any?, hasMore: Bool)
    func fetchPost(postId: String) async throws -> Post
    func fetchPost(postId: String, userId: String) async throws -> Post
    func fetchPostsByUser(userId: String, limit: Int, cursor: Any?) async throws -> (posts: [Post], cursor: Any?, hasMore: Bool)
    func createPost(_ post: Post) async throws
    func deletePost(postId: String, userId: String) async throws
    func likePost(postId: String, ownerId: String, uid: String) async throws
    func unlikePost(postId: String, ownerId: String, uid: String) async throws
    func isPostLiked(postId: String, uid: String) async throws -> Bool
    func fetchComments(postId: String, postOwnerId: String, limit: Int) async throws -> [PostComment]
    func addComment(postId: String, postOwnerId: String, uid: String, text: String, username: String?, userDisplayName: String?, userAvatarURL: String?) async throws -> PostComment
    func fetchPostCount(userId: String) async throws -> Int
    
    // Saved Posts
    func savePost(postId: String, userId: String) async throws
    func unsavePost(postId: String, userId: String) async throws
    func isPostSaved(postId: String, userId: String) async throws -> Bool
    func fetchSavedPosts(userId: String) async throws -> [Post]
}

