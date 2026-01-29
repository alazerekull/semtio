//
//  PostFeedStore.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class PostFeedStore: ObservableObject {
    
    enum FeedFilter {
        case following
        case recent
    }
    
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var hasMore = true
    @Published var currentFilter: FeedFilter = .following
    
    private var followingIds: [String] = []
    
    func updateFollowingIds(_ ids: [String]) {
        self.followingIds = ids
    }
    
    func setFilter(_ filter: FeedFilter) async {
        guard currentFilter != filter else { return }
        currentFilter = filter
        await refresh()
    }
    
    private let repo: PostRepositoryProtocol
    private var lastCursor: Any?
    private let pageSize = 10
    
    // MARK: - Settings & Density
    
    @Published var showActivityPosts: Bool {
        didSet {
            UserDefaults.standard.set(showActivityPosts, forKey: "feed_show_activity_posts")
            // Re-apply filter locally if possible, or refresh
            Task { await refresh() }
        }
    }
    
    // MARK: - Moderation State
    
    @Published var hiddenPostIds: Set<String> = []
    private let moderationRepo: ModerationRepositoryProtocol
    
    // Raw posts before density filtering
    // ...
    
    init(repo: PostRepositoryProtocol, moderationRepo: ModerationRepositoryProtocol) {
        self.repo = repo
        self.moderationRepo = moderationRepo
        self.showActivityPosts = UserDefaults.standard.object(forKey: "feed_show_activity_posts") as? Bool ?? true
        
        // Load hidden posts
        if let saved = UserDefaults.standard.stringArray(forKey: "hidden_post_ids") {
            self.hiddenPostIds = Set(saved)
        }
    }
    
    func hidePost(_ postId: String) {
        hiddenPostIds.insert(postId)
        UserDefaults.standard.set(Array(hiddenPostIds), forKey: "hidden_post_ids")
        // Remove locally
        posts.removeAll { $0.id == postId }
    }
    
    func removePost(postId: String) {
        posts.removeAll { $0.id == postId }
    }
    
    func reportPost(_ post: Post, reason: String) async {
        do {
            try await moderationRepo.report(type: .post, targetId: post.id, reason: reason)
            // Auto-hide on report? Ideally yes.
            hidePost(post.id)
            print("PostFeedStore: Reported post \(post.id)")
        } catch {
            print("PostFeedStore: Failed to report post: \(error)")
        }
    }
    
    func deletePost(post: Post, uid: String) async throws {
        // Optimistic update
        removePost(postId: post.id)
        
        do {
            try await repo.deletePost(postId: post.id, userId: uid)
        } catch {
            // Re-fetch or handle error if needed
            print("❌ PostFeedStore: Failed to delete post: \(error)")
            throw error
        }
    }
    
    func refresh(blockedUserIds: Set<String> = []) async {
        isLoading = true
        posts = []
        lastCursor = nil
        hasMore = true
        await fetchPosts(isLoadMore: false, blockedUserIds: blockedUserIds)
    }
    
    // Updated signature to accept blockedUserIds if needed for dynamic filtering
    // In a real app, `blockedUserIds` might better be injected or accessed via UserStore singleton if available,
    // or passed in. Since `PostFeedStore` is in `AppState`, it can access `UserStore`.
    // However, to keep it decoupled, passing it in `refresh` or relying on a property is fine.
    // Let's assume the caller (HomeView) passes it or we filter after fetch.
    
    private func fetchPosts(isLoadMore: Bool, blockedUserIds: Set<String> = []) async {
        if isLoadMore {
            guard !isLoading, hasMore else { return }
            isLoading = true
        } else {
            isLoading = true
            error = nil
            lastCursor = nil
            hasMore = true
            if posts.isEmpty { isLoading = true }
        }
        
        do {
            let result: (posts: [Post], cursor: Any?, hasMore: Bool)
            
            switch currentFilter {
            case .recent:
                result = try await repo.fetchFeedPosts(limit: pageSize, cursor: lastCursor)
                
            case .following:
                if followingIds.isEmpty {
                     result = ([], nil, false)
                } else {
                     result = try await repo.fetchPostsByAuthors(authorIds: followingIds, limit: pageSize, cursor: lastCursor)
                }
            }
            
            // 1. Filter Blocked Users & Hidden Posts
            var fetchedPosts = result.posts.filter { post in
                !blockedUserIds.contains(post.ownerId) && !hiddenPostIds.contains(post.id)
            }
            
            // 2. Apply Density Rules & Settings
            if !showActivityPosts {
                fetchedPosts = fetchedPosts.filter { $0.type == .standard }
            } else {
                fetchedPosts = applyDensityRules(to: fetchedPosts, appendingTo: isLoadMore ? posts : [])
            }
            
            if isLoadMore {
                 let newPosts = fetchedPosts.filter { newPost in
                    !self.posts.contains(where: { $0.id == newPost.id })
                }
                self.posts.append(contentsOf: newPosts)
            } else {
                self.posts = fetchedPosts
            }
            
            self.lastCursor = result.cursor
            self.hasMore = result.hasMore
            
        } catch {
            self.error = error
            print("❌ PostFeedStore: Fetch failed: \(error)")
        }
        
        isLoading = false
    }
    
    private func applyDensityRules(to newPosts: [Post], appendingTo existing: [Post]) -> [Post] {
        // Simple density check:
        // We want to avoid 3 consecutive activity posts.
        // We look at the tail of 'existing' + 'newPosts'.
        
        var activityCount = 0
        
        // We only need to process the 'newPosts' part strictly, but context matters.
        // Let's iterate through standard + new but only keep the new ones that pass.
        // Actually, easier to return just the filtered 'newPosts' but based on 'existing' context.
        
        // Optimization: Just check `newPosts` against density, assuming `existing` allows appending.
        // But if `existing` ended with 2 activities, we shouldn't start with another activity.
        
        // Let's check the last few items of existing
        let suffix = existing.suffix(2)
        for post in suffix {
            if post.type != .standard {
                activityCount += 1
            } else {
                activityCount = 0
            }
        }
        
        var safeNewPosts: [Post] = []
        for post in newPosts {
            if post.type == .standard {
                activityCount = 0
                safeNewPosts.append(post)
            } else {
                if activityCount < 2 {
                    activityCount += 1
                    safeNewPosts.append(post)
                } else {
                    // Skip this activity post to maintain density
                    print("Density: Skipping activity post \(post.id)")
                }
            }
        }
        
        return safeNewPosts
    }
    
    func loadMore(blockedUserIds: Set<String> = []) async {
        guard !isLoading, hasMore else { return }
        
        await fetchPosts(isLoadMore: true, blockedUserIds: blockedUserIds)
    }
    
    // MARK: - Interactions
    
    func toggleLike(post: Post, uid: String) async {
        // Optimistic UI update
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        var updatedPost = post
        
        if post.isLiked {
            updatedPost.isLiked = false
            updatedPost.likeCount = max(0, post.likeCount - 1)
        } else {
            updatedPost.isLiked = true
            updatedPost.likeCount += 1
        }
        
        posts[index] = updatedPost
        
        // API Call
        do {
            if post.isLiked {
                try await repo.unlikePost(postId: post.id, ownerId: post.ownerId, uid: uid)
            } else {
                try await repo.likePost(postId: post.id, ownerId: post.ownerId, uid: uid)
            }
        } catch {
            // Revert on failure
            print("❌ PostFeedStore: Toggle like failed: \(error)")
            if let revertIndex = posts.firstIndex(where: { $0.id == post.id }) {
                posts[revertIndex] = post
            }
        }
    }
    func incrementCommentCount(postId: String) {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var updatedPost = posts[index]
            updatedPost = Post(
                id: updatedPost.id,
                ownerId: updatedPost.ownerId,
                ownerUsername: updatedPost.ownerUsername,
                ownerDisplayName: updatedPost.ownerDisplayName,
                ownerAvatarURL: updatedPost.ownerAvatarURL,
                caption: updatedPost.caption,
                mediaURLs: updatedPost.mediaURLs,
                createdAt: updatedPost.createdAt,
                updatedAt: updatedPost.updatedAt,
                likeCount: updatedPost.likeCount,
                commentCount: updatedPost.commentCount + 1,
                visibility: updatedPost.visibility,
                isLiked: updatedPost.isLiked
            )
            posts[index] = updatedPost
        }
    }
}
