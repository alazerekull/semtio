//
//  MockFollowRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

class MockFollowRepository: FollowRepositoryProtocol {
    
    // followingState: [userId: Set<FollowingUserId>]
    private var followingState: [String: Set<String>] = [:]
    
    func follow(userId: String, targetUserId: String) async throws {
        try? await Task.sleep(nanoseconds: 300_000_000)
        var following = followingState[userId] ?? []
        following.insert(targetUserId)
        followingState[userId] = following
        print("Mock: \(userId) followed \(targetUserId)")
    }
    
    func unfollow(userId: String, targetUserId: String) async throws {
        try? await Task.sleep(nanoseconds: 300_000_000)
        var following = followingState[userId] ?? []
        following.remove(targetUserId)
        followingState[userId] = following
        print("Mock: \(userId) unfollowed \(targetUserId)")
    }
    
    func isFollowing(userId: String, targetUserId: String) async throws -> Bool {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return followingState[userId]?.contains(targetUserId) ?? false
    }
    
    func fetchFollowerCount(userId: String) async throws -> Int {
        try? await Task.sleep(nanoseconds: 200_000_000)
        // Calculating followers by iterating all followings (inefficient but fine for mock)
        var count = 0
        for (_, following) in followingState {
            if following.contains(userId) {
                count += 1
            }
        }
        return count
    }
    
    func fetchFollowingCount(userId: String) async throws -> Int {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return followingState[userId]?.count ?? 0
    }

    func fetchFollowingIds(userId: String) async throws -> [String] {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return Array(followingState[userId] ?? [])
    }

    func fetchFollowerIds(userId: String) async throws -> [String] {
        try? await Task.sleep(nanoseconds: 200_000_000)
        var followerIds: [String] = []
        for (uid, following) in followingState {
            if following.contains(userId) {
                followerIds.append(uid)
            }
        }
        return followerIds
    }
}
