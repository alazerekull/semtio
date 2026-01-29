//
//  FirestorePostRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  FIREBASE SCHEMA (Optimized):
//  - Posts are stored under: /users/{uid}/posts/{postId}
//  - Fields: userId, timestamp, imageUrl, likes, likedBy, commentsCount, sharesCount, sharedBy
//  - Uses collectionGroup("posts") for feed queries across all users
//

import Foundation
import FirebaseFirestore

class FirestorePostRepository: PostRepositoryProtocol {

    private let db = Firestore.firestore()

    // MARK: - Feed Posts (Collection Group Query)

    /// Fetches public feed posts from ALL users using collectionGroup
    /// This queries /users/*/posts across all user documents
    func fetchFeedPosts(limit: Int, cursor: Any?) async throws -> (posts: [Post], cursor: Any?, hasMore: Bool) {
        // Collection group query - searches all "posts" subcollections across all users
        // Collection group query - searches all "posts" subcollections across all users
        var query = db.collectionGroup("posts")
            // .order(by: "timestamp", descending: true) // Disabled to avoid Collection Group Index requirement
            .limit(to: limit)

        if let lastSnapshot = cursor as? DocumentSnapshot {
            query = query.start(afterDocument: lastSnapshot)
        }

        let snapshot = try await query.getDocuments()
        var posts: [Post] = []

        for doc in snapshot.documents {
            do {
                let post = try await mapDocumentToPost(doc)
                posts.append(post)
            } catch {
                print("⚠️ FirestorePostRepo: feedPosts map error doc=\(doc.documentID): \(error)")
            }
        }

        let lastDoc = snapshot.documents.last
        let hasMore = snapshot.documents.count == limit

        return (posts, lastDoc, hasMore)
    }

    /// Fetches posts from specific authors (friends feed)
    /// Optimized to avoid Composite Index requirement by Fan-out Reading.
    func fetchPostsByAuthors(authorIds: [String], limit: Int, cursor: Any?) async throws -> (posts: [Post], cursor: Any?, hasMore: Bool) {
        let safeIds = Array(authorIds.prefix(20)) // Limit filtering to top 20 friends for performance
        
        guard !safeIds.isEmpty else {
            return ([], nil, false)
        }
        
        // Strategy: "Fan-out Read"
        // Query each user's `posts` subcollection individually. 
        // This uses standard single-field indexes (userId + timestamp) which exist by default.
        // We do NOT use collectionGroup() here to avoid the composite index error.
        
        // We have to ignore the cursor for true pagination across multiple collections without an index.
        // Instead, we fetch the latest N posts from ALL friends, merge in memory.
        // Limitation: Deep pagination is hard without an index or complex cursor logic.
        // For this "Feed", we'll just fetch the top items.
        
        var allPosts: [Post] = []
        
        // Parallel execution
        await withTaskGroup(of: [Post].self) { group in
            for uid in safeIds {
                group.addTask {
                    do {
                        // Direct subcollection query: /users/{uid}/posts
                        // Index needed: Single field timestamp DESC (Default exists)
                        let snapshot = try await self.db.collection("users").document(uid).collection("posts")
                            .order(by: "timestamp", descending: true)
                            .limit(to: 5) // Fetch top 5 from each friend to mix
                            .getDocuments()
                        
                        var userPosts: [Post] = []
                        // We need user data for mapping. 
                        // Optimization: Pass nil now, fetch distinct owners later or use what we have.
                        // Ideally we'd have a user cache.
                        
                        for doc in snapshot.documents {
                            if let post = try? await self.mapDocumentToPost(doc) {
                                userPosts.append(post)
                            }
                        }
                        return userPosts
                    } catch {
                        print("⚠️ Failed to fetch posts for user \(uid): \(error)")
                        return []
                    }
                }
            }
            
            for await userPosts in group {
                allPosts.append(contentsOf: userPosts)
            }
        }
        
        // Sort in memory by timestamp descending
        allPosts.sort { $0.createdAt > $1.createdAt }
        
        // Apply limit
        let finalPosts = Array(allPosts.prefix(limit))
        let hasMore = allPosts.count > limit // Rough estimate
        
        // Cursor is not really usable in this fan-out model easily, so we return nil or last doc
        // For infinite scroll, we'd need a timestamp-based cursor logic, but let's stick to simple feed for now.
        
        return (finalPosts, nil, hasMore)
    }

    /// Fetches a single post by ID
    /// Since we don't know the user, we use collection group
    /// Fetches a single post by ID
    /// Since we don't know the user, we use collection group
    func fetchPost(postId: String) async throws -> Post {
        // Collection group query to find post by ID
        // Note: FieldPath.documentID() in collectionGroup requires full path, so we use "id" field.
        let snapshot = try await db.collectionGroup("posts")
            .whereField("id", isEqualTo: postId)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            throw NSError(domain: "FirestorePostRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"])
        }

        return try await mapDocumentToPost(doc)
    }
    
    /// Fetches a single post by ID directly from user path (No Index Required)
    func fetchPost(postId: String, userId: String) async throws -> Post {
        let doc = try await db.collection("users").document(userId).collection("posts").document(postId).getDocument()
        
        guard doc.exists else {
             throw NSError(domain: "FirestorePostRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found or unavailable"])
        }
        
        return try await mapDocumentToPost(doc)
    }

    /// Fetches posts by a specific user - DIRECT PATH (most efficient)
    func fetchPostsByUser(userId: String, limit: Int, cursor: Any?) async throws -> (posts: [Post], cursor: Any?, hasMore: Bool) {
        print("🔍 FirestorePostRepo: fetchPostsByUser userId=\(userId), limit=\(limit)")

        // Direct path query - most efficient
        var query = db.collection("users").document(userId).collection("posts")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)

        if let lastSnapshot = cursor as? DocumentSnapshot {
            query = query.start(afterDocument: lastSnapshot)
        }

        let snapshot = try await query.getDocuments()
        print("✅ FirestorePostRepo: Got \(snapshot.documents.count) documents for userId=\(userId)")

        var posts: [Post] = []

        // Fetch user info once for denormalization
        let userDoc = try? await db.collection("users").document(userId).getDocument()
        let userData = userDoc?.data()

        for doc in snapshot.documents {
            do {
                let post = try mapDocumentToPostWithUserData(doc, userData: userData)
                posts.append(post)
            } catch {
                print("⚠️ FirestorePostRepo: Failed to map doc \(doc.documentID): \(error)")
            }
        }

        let lastDoc = snapshot.documents.last
        let hasMore = snapshot.documents.count == limit

        return (posts, lastDoc, hasMore)
    }

    // MARK: - Create Post

    func createPost(_ post: Post) async throws {
        let userId = post.ownerId

        let data: [String: Any] = [
            "id": post.id,
            "userId": userId,
            "timestamp": Timestamp(date: post.createdAt),
            "imageUrl": post.mediaURLs.first ?? "",
            "likes": post.likeCount,
            "likedBy": post.likedBy,
            "commentsCount": post.commentCount,
            "sharesCount": post.sharesCount,
            "sharedBy": post.sharedBy
        ]

        // Write to /users/{uid}/posts/{postId}
        try await db.collection("users").document(userId).collection("posts").document(post.id).setData(data)
        print("✅ FirestorePostRepo: Post created at /users/\(userId)/posts/\(post.id)")
    }

    // MARK: - Like/Unlike

    func likePost(postId: String, ownerId: String, uid: String) async throws {
        // Direct update at specific path - No Index Required
        let postRef = db.collection("users").document(ownerId).collection("posts").document(postId)

        // Atomic update using likedBy map
        try await postRef.updateData([
            "likedBy.\(uid)": true,
            "likes": FieldValue.increment(Int64(1))
        ])

        print("❤️ FirestorePostRepo: Post \(postId) owned by \(ownerId) liked by \(uid)")
    }

    func unlikePost(postId: String, ownerId: String, uid: String) async throws {
        // Direct update
        let postRef = db.collection("users").document(ownerId).collection("posts").document(postId)

        // Atomic update
        try await postRef.updateData([
            "likedBy.\(uid)": FieldValue.delete(),
            "likes": FieldValue.increment(Int64(-1))
        ])

        print("💔 FirestorePostRepo: Post \(postId) owned by \(ownerId) unliked by \(uid)")
    }

    // MARK: - Comments

    func fetchComments(postId: String, limit: Int) async throws -> [PostComment] {
        // Find the post's owner first
        let postSnapshot = try await db.collectionGroup("posts")
            .whereField("id", isEqualTo: postId)
            .limit(to: 1)
            .getDocuments()

        guard let postDoc = postSnapshot.documents.first,
              let userId = postDoc.data()["userId"] as? String else {
            return []
        }

        let snapshot = try await db.collection("users").document(userId)
            .collection("posts").document(postId)
            .collection("comments")
            .order(by: "timestamp", descending: false)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { try? mapDocumentToComment($0) }
    }

    func addComment(postId: String, uid: String, text: String, username: String?, userDisplayName: String?, userAvatarURL: String?) async throws -> PostComment {
        // Find the post's owner first
        let postSnapshot = try await db.collectionGroup("posts")
            .whereField("id", isEqualTo: postId)
            .limit(to: 1)
            .getDocuments()

        guard let postDoc = postSnapshot.documents.first,
              let postOwnerId = postDoc.data()["userId"] as? String else {
            throw NSError(domain: "FirestorePostRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"])
        }

        let postRef = db.collection("users").document(postOwnerId).collection("posts").document(postId)
        let commentsRef = postRef.collection("comments")
        let commentId = UUID().uuidString
        let now = Date()

        let commentData: [String: Any] = [
            "id": commentId,
            "postId": postId,
            "uid": uid,
            "text": text,
            "username": username ?? "",
            "userDisplayName": userDisplayName ?? "",
            "userAvatarURL": userAvatarURL ?? "",
            "timestamp": Timestamp(date: now)
        ]

        let batch = db.batch()
        let newCommentRef = commentsRef.document(commentId)

        batch.setData(commentData, forDocument: newCommentRef)
        batch.updateData(["commentsCount": FieldValue.increment(Int64(1))], forDocument: postRef)

        try await batch.commit()

        return PostComment(
            id: commentId,
            postId: postId,
            uid: uid,
            username: username,
            userDisplayName: userDisplayName,
            userAvatarURL: userAvatarURL,
            text: text,
            createdAt: now
        )
    }

    // MARK: - Mappers

    /// Maps a post document and fetches owner info if needed
    private func mapDocumentToPost(_ doc: DocumentSnapshot) async throws -> Post {
        guard let data = doc.data() else {
            throw NSError(domain: "FirestorePostRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Document data missing"])
        }

        let userId = data["userId"] as? String ?? ""

        // Fetch user data for denormalized fields
        var userData: [String: Any]?
        if !userId.isEmpty {
            let userDoc = try? await db.collection("users").document(userId).getDocument()
            userData = userDoc?.data()
        }

        return try mapDocumentToPostWithUserData(doc, userData: userData)
    }

    /// Maps a post document with pre-fetched user data (more efficient for batch operations)
    private func mapDocumentToPostWithUserData(_ doc: DocumentSnapshot, userData: [String: Any]?) throws -> Post {
        guard let data = doc.data() else {
            throw NSError(domain: "FirestorePostRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Document data missing"])
        }

        let userId = data["userId"] as? String ?? ""

        // Extract user info for UI display
        let username = userData?["username"] as? String
        let displayName = userData?["fullName"] as? String ?? userData?["nickname"] as? String
        let avatarURL = userData?["profilePicture"] as? String

        // Map likedBy from object to dictionary
        let likedByRaw = data["likedBy"] as? [String: Any] ?? [:]
        let likedBy = likedByRaw.compactMapValues { $0 as? Bool }

        // Map sharedBy from object to dictionary
        let sharedByRaw = data["sharedBy"] as? [String: Any] ?? [:]
        let sharedBy = sharedByRaw.compactMapValues { $0 as? Bool }

        // Determine Media Type
        let typeString = data["mediaType"] as? String ?? "image"
        let mediaType = Post.MediaType(rawValue: typeString) ?? .image
        
        var mediaURLs: [String] = []
        
        if mediaType == .video {
            // Video: try 'mediaUrl', 'videoUrl', 'imageUrl'
            if let url = data["mediaUrl"] as? String, !url.isEmpty {
                mediaURLs = [url]
            } else if let url = data["videoUrl"] as? String, !url.isEmpty {
                 mediaURLs = [url]
            } else if let url = data["imageUrl"] as? String, !url.isEmpty {
                 mediaURLs = [url] // Fallback
            }
        } else {
            // Image: try 'imageUrl', 'mediaUrl'
            let imageUrl = data["imageUrl"] as? String ?? ""
            if !imageUrl.isEmpty {
                mediaURLs = [imageUrl]
            } else {
                // Try mediaURLs array if exists
                if let urls = data["mediaURLs"] as? [String] {
                    mediaURLs = urls
                }
            }
        }
        
        // Thumbnail
        let thumbnailURL = data["thumbUrl"] as? String ?? data["thumbnailURL"] as? String

        // Parse timestamp
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()

        return Post(
            id: doc.documentID,
            ownerId: userId,
            ownerUsername: username,
            ownerDisplayName: displayName,
            ownerAvatarURL: avatarURL,
            caption: data["caption"] as? String ?? "", // Fix: Read caption
            mediaURLs: mediaURLs,
            mediaType: mediaType,
            thumbnailURL: thumbnailURL,
            createdAt: timestamp,
            updatedAt: timestamp,
            likeCount: data["likes"] as? Int ?? 0,
            commentCount: data["commentsCount"] as? Int ?? 0,
            visibility: "public",
            likedBy: likedBy,
            sharesCount: data["sharesCount"] as? Int ?? 0,
            sharedBy: sharedBy
        )
    }

    private func mapDocumentToComment(_ doc: QueryDocumentSnapshot) throws -> PostComment {
        let data = doc.data()

        return PostComment(
            id: doc.documentID,
            postId: data["postId"] as? String ?? "",
            uid: data["uid"] as? String ?? "",
            username: data["username"] as? String,
            userDisplayName: data["userDisplayName"] as? String,
            userAvatarURL: data["userAvatarURL"] as? String,
            text: data["text"] as? String ?? "",
            createdAt: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    // MARK: - Like Status Check

    func isPostLiked(postId: String, uid: String) async throws -> Bool {
        // Find the post first
        let snapshot = try await db.collectionGroup("posts")
            .whereField("id", isEqualTo: postId)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            return false
        }

        // Check likedBy map
        let likedBy = doc.data()["likedBy"] as? [String: Any] ?? [:]
        return likedBy[uid] != nil
    }

    func fetchPostCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection("users").document(userId)
            .collection("posts")
            .count
            .getAggregation(source: .server)

        return Int(truncating: snapshot.count)
    }

    // MARK: - Delete Post

    func deletePost(postId: String, userId: String) async throws {
        let postRef = db.collection("users").document(userId).collection("posts").document(postId)
        let doc = try await postRef.getDocument()

        guard doc.exists else {
            throw NSError(domain: "FirestorePostRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post bulunamadı"])
        }

        guard let ownerId = doc.data()?["userId"] as? String, ownerId == userId else {
            throw NSError(domain: "FirestorePostRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Bu gönderiyi silme yetkiniz yok"])
        }

        try await postRef.delete()
        print("🗑️ FirestorePostRepository: Post deleted: \(postId)")
    }

    // MARK: - Saved Posts

    func savePost(postId: String, userId: String) async throws {
        let savedRef = db.collection("users").document(userId).collection("saved_posts").document(postId)
        try await savedRef.setData([
            "postId": postId,
            "savedAt": FieldValue.serverTimestamp()
        ])
        print("🔖 FirestorePostRepository: Post saved: \(postId)")
    }

    func unsavePost(postId: String, userId: String) async throws {
        let savedRef = db.collection("users").document(userId).collection("saved_posts").document(postId)
        try await savedRef.delete()
        print("🔖 FirestorePostRepository: Post unsaved: \(postId)")
    }

    func isPostSaved(postId: String, userId: String) async throws -> Bool {
        let savedRef = db.collection("users").document(userId).collection("saved_posts").document(postId)
        let doc = try await savedRef.getDocument()
        return doc.exists
    }

    func fetchSavedPosts(userId: String) async throws -> [Post] {
        // 1. Get saved post IDs
        let savedDocs = try await db.collection("users").document(userId)
            .collection("saved_posts")
            .order(by: "savedAt", descending: true)
            .getDocuments()

        let postIds = savedDocs.documents.compactMap { $0.data()["postId"] as? String }

        guard !postIds.isEmpty else { return [] }

        // 2. Fetch posts using collection group
        var posts: [Post] = []

        for postId in postIds {
            do {
                let post = try await fetchPost(postId: postId)
                posts.append(post)
            } catch {
                print("⚠️ FirestorePostRepo: Could not fetch saved post \(postId): \(error)")
            }
        }

        return posts
    }
}


