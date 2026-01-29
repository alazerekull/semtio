//
//  PostInteractionStore.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class PostInteractionStore: ObservableObject {
    
    @Published private(set) var likedPostIds: Set<String> = []
    @Published private(set) var loadingPostIds: Set<String> = []
    
    private let repo: PostRepositoryProtocol
    private let notificationRepo: NotificationRepositoryProtocol
    private let userStore: UserStore
    private var currentUserUid: String?
    
    init(repo: PostRepositoryProtocol, notificationRepo: NotificationRepositoryProtocol, userStore: UserStore) {
        self.repo = repo
        self.notificationRepo = notificationRepo
        self.userStore = userStore
    }
    
    func setUser(uid: String?) {
        self.currentUserUid = uid
        if uid == nil {
            likedPostIds.removeAll()
            loadingPostIds.removeAll()
        }
    }
    
    func isLiked(_ postId: String) -> Bool {
        return likedPostIds.contains(postId)
    }
    
    func isLoading(_ postId: String) -> Bool {
        return loadingPostIds.contains(postId)
    }
    
    func toggleLike(post: Post) {
        guard let uid = currentUserUid else { return }
        
        // Optimistic update
        let isCurrentlyLiked = likedPostIds.contains(post.id)
        
        if isCurrentlyLiked {
            likedPostIds.remove(post.id)
        } else {
            likedPostIds.insert(post.id)
        }
        
        // Prevent double tapping while loading
        if loadingPostIds.contains(post.id) { return }
        loadingPostIds.insert(post.id)
        
        Task {
            do {
                if isCurrentlyLiked {
                    try await repo.unlikePost(postId: post.id, ownerId: post.ownerId, uid: uid)
                } else {
                    try await repo.likePost(postId: post.id, ownerId: post.ownerId, uid: uid)
                    // Trigger Notification
                    if post.ownerId != uid { // Don't notify self
                        await createLikeNotification(for: post)
                    }
                }
                loadingPostIds.remove(post.id)
            } catch {
                print("❌ PostInteractionStore: Toggle like failed: \(error)")
                // Rollback
                if isCurrentlyLiked {
                    likedPostIds.insert(post.id)
                } else {
                    likedPostIds.remove(post.id)
                }
                loadingPostIds.remove(post.id)
            }
        }
    }
    
    private func createLikeNotification(for post: Post) async {
        guard let currentUid = currentUserUid else { return }
        let currentUser = userStore.currentUser
        
        let notification = AppNotification(
            id: UUID().uuidString,
            userId: post.ownerId,
            type: .postLike,
            title: "Yeni Beğeni",
            body: "\(currentUser.displayName) gönderini beğendi.",
            createdAt: Date(),
            isRead: false,
            fromUserId: currentUid,
            fromUserName: currentUser.displayName,
            fromUserAvatar: currentUser.avatarURL,
            postId: post.id
        )
        
        do {
            try await notificationRepo.createNotification(notification)
        } catch {
            print("❌ PostInteractionStore: Failed to create notification: \(error)")
        }
    }
    
    /// Called when loading feed to sync local state with what comes from server
    /// If server says "isLiked=true", we ensure it's in our set
    func syncLikeState(for post: Post) {
        if post.isLiked {
            likedPostIds.insert(post.id)
        }
    }
}
