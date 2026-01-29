//
//  FollowRepositoryProtocol.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

protocol FollowRepositoryProtocol {
    func follow(userId: String, targetUserId: String) async throws
    func unfollow(userId: String, targetUserId: String) async throws
    func isFollowing(userId: String, targetUserId: String) async throws -> Bool
    func fetchFollowerCount(userId: String) async throws -> Int
    func fetchFollowingCount(userId: String) async throws -> Int

    /// Returns list of user IDs that this user is following
    func fetchFollowingIds(userId: String) async throws -> [String]

    /// Returns list of user IDs that follow this user
    func fetchFollowerIds(userId: String) async throws -> [String]
}
