//
//  UserRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

struct UserLite: Identifiable, Codable, Equatable {
    let id: String
    let fullName: String
    let username: String
    let avatarURL: String?
}

protocol UserRepositoryProtocol {
    func fetchUser(id: String) async throws -> AppUser?
    func fetchUser(username: String) async throws -> AppUser?
    func saveUser(_ user: AppUser) async throws
    func deleteUser(id: String) async throws
    
    // Search
    func searchUsers(query: String) async throws -> [UserLite]
    
    // Suggestions
    func fetchSuggestedUsers(limit: Int) async throws -> [AppUser]
    
    // Real-time listener
    func listenUser(id: String, onChange: @escaping (AppUser?) -> Void, onError: @escaping (Error) -> Void) -> AnyObject?
    func removeListener(_ listener: AnyObject)
    // Legacy support
    func upsertUser(id: String, email: String?, displayName: String?) async throws
    
    // ShareCode
    /// Returns existing shareCode or generates and persists a new one.
    func ensureShareCode(uid: String) async throws -> String
    /// Updates the shareCode for a user (used if explicitly resetting).
    func updateShareCode(uid: String, code: String) async throws
    
    // Privacy
    /// Updates user's profile visibility setting.
    func updateProfilePrivacy(uid: String, isPublic: Bool) async throws
    /// Fetches user's profile visibility (defaults to true if not set).
    func fetchProfilePrivacy(uid: String) async throws -> Bool
    
    // MARK: - Saved Events
    
    /// Saves an event to user's saved list
    func saveEvent(eventId: String, uid: String) async throws
    
    /// Removes an event from user's saved list
    func unsaveEvent(eventId: String, uid: String) async throws
    
    /// Fetches all saved event IDs for user
    func fetchSavedEventIds(uid: String) async throws -> Set<String>
    
    // MARK: - Blocking
    
    /// Blocks a user
    func blockUser(uid: String, blockedUid: String) async throws
    
    /// Unblocks a user
    func unblockUser(uid: String, blockedUid: String) async throws
    
    /// Fetches all blocked user IDs
    func fetchBlockedUsers(uid: String) async throws -> Set<String>
    
    // MARK: - Saved Posts
    
    /// Saves a post to user's saved list
    func savePost(postId: String, uid: String) async throws
    
    /// Removes a post to user's saved list
    func unsavePost(postId: String, uid: String) async throws
    
    /// Fetches all saved post IDs for user
    func fetchSavedPostIds(uid: String) async throws -> Set<String>
    
    // MARK: - Friends / Requests
    
    /// Sends a friend request from `fromUid` to `toUid`.
    func sendFriendRequest(fromUid: String, toUid: String) async throws
    
    /// Accepts a friend request (updates friend_requests status and adds to friends/list).
    func acceptFriendRequest(requestId: String, fromUid: String, toUid: String) async throws
    
    /// Rejects a friend request (updates friend_requests status to rejected or deletes it).
    func rejectFriendRequest(requestId: String) async throws
    
    /// Cancels a sent friend request.
    func cancelFriendRequest(requestId: String) async throws
    
    /// Removes a friend.
    func unfriend(uid: String, friendUid: String) async throws
    
    /// Listens for incoming and outgoing friend requests for the user.
    /// Returns dictionary with keys: "incoming", "outgoing" containing arrays of request objects (as Any or specific type).
    func listenFriendRequests(uid: String, onChange: @escaping ([FriendRequest]) -> Void, onError: @escaping (Error) -> Void) -> AnyObject?
    
    /// Fetches user's friend list
    func fetchFriends(uid: String) async throws -> [AppUser]
}

// Legacy alias for compatibility
typealias UserRepository = UserRepositoryProtocol
