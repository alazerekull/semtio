//
//  FollowInteractionStore.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import Combine

@MainActor
class FollowInteractionStore: ObservableObject {
    
    // Set of UserIDs that the current user is following
    @Published var followingIds: Set<String> = []
    
    // Set of UserIDs currently loading (follow/unfollow in progress)
    @Published var loadingIds: Set<String> = []
    
    private let repo: FollowRepositoryProtocol
    private var currentUserId: String?
    
    init(repo: FollowRepositoryProtocol) {
        self.repo = repo
    }
    
    func setUser(uid: String?) async {
        self.currentUserId = uid
        if uid == nil {
            self.followingIds.removeAll()
            self.loadingIds.removeAll()
        }
        // In a real app we might fetch the full following list here
        // For now, we rely on individual checks or lazy loading
    }
    
    func isFollowing(_ userId: String) -> Bool {
        followingIds.contains(userId)
    }
    
    func isLoading(_ userId: String) -> Bool {
        loadingIds.contains(userId)
    }
    
    func checkFollowStatus(userId: String) async {
        guard let currentUid = currentUserId, currentUid != userId else { return }
        
        do {
            let isFollowing = try await repo.isFollowing(userId: currentUid, targetUserId: userId)
            if isFollowing {
                followingIds.insert(userId)
            } else {
                followingIds.remove(userId)
            }
        } catch {
            print("FollowStore: Check status failed: \(error)")
        }
    }
    
    func toggleFollow(targetUserId: String) {
        guard let currentUid = currentUserId else { return }
        guard !isLoading(targetUserId) else { return }
        
        let isCurrentlyFollowing = followingIds.contains(targetUserId)
        
        // Optimistic Update
        loadingIds.insert(targetUserId)
        if isCurrentlyFollowing {
            followingIds.remove(targetUserId)
        } else {
            followingIds.insert(targetUserId)
        }
        
        Task {
            do {
                if isCurrentlyFollowing {
                    try await repo.unfollow(userId: currentUid, targetUserId: targetUserId)
                } else {
                    try await repo.follow(userId: currentUid, targetUserId: targetUserId)
                }
                loadingIds.remove(targetUserId)
            } catch {
                // Rollback
                if isCurrentlyFollowing {
                    followingIds.insert(targetUserId)
                } else {
                    followingIds.remove(targetUserId)
                }
                loadingIds.remove(targetUserId)
                print("FollowStore: Toggle failed: \(error)")
            }
        }
    }
    
    // Fetch counts wrapper
    func fetchCounts(userId: String) async throws -> (followers: Int, following: Int) {
        async let followers = repo.fetchFollowerCount(userId: userId)
        async let following = repo.fetchFollowingCount(userId: userId)
        return try await (followers, following)
    }
}
