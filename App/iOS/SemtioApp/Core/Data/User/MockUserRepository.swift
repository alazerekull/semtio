//
//  MockUserRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

final class MockUserRepository: UserRepositoryProtocol {
    
    /// In-memory storage for users (persists across app session).
    private var users: [String: AppUser] = [:]
    /// Track all existing share codes to avoid collision.
    private var existingShareCodes: Set<String> = []
    
    // MARK: - Search
    func searchUsers(query: String) async throws -> [UserLite] {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return users.values.filter {
            $0.fullName.localizedCaseInsensitiveContains(query) ||
            ($0.username?.localizedCaseInsensitiveContains(query) ?? false)
        }.map {
            UserLite(id: $0.id, fullName: $0.fullName, username: $0.username ?? "", avatarURL: $0.avatarURL)
        }
    }
    
    // MARK: - Suggestions
    
    func fetchSuggestedUsers(limit: Int) async throws -> [AppUser] {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return Array(users.values.prefix(limit))
    }
    
    // MARK: - Core Methods
    
    func fetchUser(id: String) async throws -> AppUser? {
        if let user = users[id] {
            return user
        }
        // Fallback mock
        return AppUser(
            id: id,
            fullName: "Mock User",
            avatarAssetName: "avatar_placeholder",
            headline: nil,
            username: "mockuser",
            city: "İstanbul",
            bio: "Mock Bio",
            interests: [],
            shareCode11: nil,
            district: nil,
            isPremium: nil,
            isDeleted: nil
        )
    }
    
    func fetchUser(username: String) async throws -> AppUser? {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return users.values.first { $0.username == username }
    }
    
    func saveUser(_ user: AppUser) async throws {
        users[user.id] = user
        // Track share code
        if let code = user.shareCode11 {
            existingShareCodes.insert(code)
        }
    }
    
    func deleteUser(id: String) async throws {
        if let code = users[id]?.shareCode11 {
            existingShareCodes.remove(code)
        }
        users.removeValue(forKey: id)
    }
    
    func listenUser(id: String, onChange: @escaping (AppUser?) -> Void, onError: @escaping (Error) -> Void) -> AnyObject? {
        // Send current value immediately
        if let user = users[id] {
            onChange(user)
        } else {
            // Send default mock if not found
            let mock = AppUser(
                id: id,
                fullName: "Mock User",
                avatarAssetName: "avatar_placeholder",
                headline: nil,
                username: "mockuser",
                city: "İstanbul",
                bio: "Mock Bio",
                interests: [],
                shareCode11: nil,
                district: nil,
                isPremium: nil,
                isDeleted: nil
            )
            onChange(mock)
        }
        return NSObject() // Mock listener
    }
    
    func removeListener(_ listener: AnyObject) {
        // No-op
    }
    
    func upsertUser(id: String, email: String?, displayName: String?) async throws {
        if users[id] == nil {
            users[id] = AppUser(
                id: id,
                fullName: displayName ?? "Mock User",
                avatarAssetName: nil,
                headline: nil,
                username: nil,
                city: nil,
                bio: nil,
                interests: [],
                profileCompleted: false,
                shareCode11: nil,
                district: nil,
                isPremium: nil,
                isDeleted: nil
            )
        }
    }
    
    // MARK: - ShareCode
    
    func ensureShareCode(uid: String) async throws -> String {
        // Check if user already has a code
        if let existingCode = users[uid]?.shareCode11, !existingCode.isEmpty {
            return existingCode
        }
        
        // Generate new unique code
        let newCode = ShareCodeGenerator.generateUnique(existingCodes: existingShareCodes)
        
        // Persist
        if var user = users[uid] {
            user.shareCode11 = newCode
            users[uid] = user
        } else {
            // Create minimal user if not exists
            var newUser = AppUser(id: uid, fullName: "User", avatarAssetName: nil, headline: nil, username: nil, city: nil, bio: nil, interests: [], shareCode11: nil, district: nil, isPremium: nil, isDeleted: nil)
            newUser.shareCode11 = newCode
            users[uid] = newUser
        }
        existingShareCodes.insert(newCode)
        
        return newCode
    }
    
    func updateShareCode(uid: String, code: String) async throws {
        if var user = users[uid] {
            // Remove old code from tracking
            if let oldCode = user.shareCode11 {
                existingShareCodes.remove(oldCode)
            }
            user.shareCode11 = code
            users[uid] = user
            existingShareCodes.insert(code)
        }
    }
    
    // MARK: - Privacy
    
    private var privacySettings: [String: Bool] = [:]
    
    func updateProfilePrivacy(uid: String, isPublic: Bool) async throws {
        privacySettings[uid] = isPublic
    }
    
    func fetchProfilePrivacy(uid: String) async throws -> Bool {
        return privacySettings[uid] ?? true // Default public
    }
    
    // MARK: - Saved Events
    
    private var savedEvents: [String: Set<String>] = [:]  // [uid: Set<eventId>]
    
    func saveEvent(eventId: String, uid: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        if savedEvents[uid] == nil {
            savedEvents[uid] = []
        }
        savedEvents[uid]?.insert(eventId)
    }
    
    func unsaveEvent(eventId: String, uid: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        savedEvents[uid]?.remove(eventId)
    }
    
    func fetchSavedEventIds(uid: String) async throws -> Set<String> {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return savedEvents[uid] ?? []
    }
    
    // MARK: - Saved Posts
    
    private var savedPosts: [String: Set<String>] = [:] // [uid: Set<postId>]
    
    func savePost(postId: String, uid: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        if savedPosts[uid] == nil {
            savedPosts[uid] = []
        }
        savedPosts[uid]?.insert(postId)
    }
    
    func unsavePost(postId: String, uid: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        savedPosts[uid]?.remove(postId)
    }
    
    func fetchSavedPostIds(uid: String) async throws -> Set<String> {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return savedPosts[uid] ?? []
    }
    
    // MARK: - Blocking
    
    private var blockedUsers: [String: Set<String>] = [:] // uid -> Blocked UIDs
    
    func blockUser(uid: String, blockedUid: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        if blockedUsers[uid] == nil {
            blockedUsers[uid] = []
        }
        blockedUsers[uid]?.insert(blockedUid)
    }
    
    func unblockUser(uid: String, blockedUid: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        blockedUsers[uid]?.remove(blockedUid)
    }
    
    func fetchBlockedUsers(uid: String) async throws -> Set<String> {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return blockedUsers[uid] ?? []
    }
    
    // MARK: - Friends / Requests (Mock)
    
    // Simulating simplified friends storage: uid -> Set<friendUid>
    private var friends: [String: Set<String>] = [:]
    // Simulating requests: [requestId: Request]
    private var requests: [String: FriendRequest] = [:]
    
    func sendFriendRequest(fromUid: String, toUid: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        let id = UUID().uuidString
        let req = FriendRequest(
            id: id,
            fromUid: fromUid,
            toUid: toUid,
            status: "pending",
            createdAt: Date()
        )
        requests[id] = req
    }
    
    func acceptFriendRequest(requestId: String, fromUid: String, toUid: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        guard let req = requests[requestId] else { return }
        let updatedReq = FriendRequest(
            id: req.id,
            fromUid: req.fromUid,
            toUid: req.toUid,
            status: "accepted",
            createdAt: req.createdAt,
            updatedAt: Date(), // Update timestamp
            fromName: req.fromName,
            fromAvatar: req.fromAvatar,
            toName: req.toName,
            toAvatar: req.toAvatar
        )
        requests[requestId] = updatedReq
        
        // Add to friends
        if friends[fromUid] == nil { friends[fromUid] = [] }
        if friends[toUid] == nil { friends[toUid] = [] }
        friends[fromUid]?.insert(toUid)
        friends[toUid]?.insert(fromUid)
    }
    
    func rejectFriendRequest(requestId: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        requests.removeValue(forKey: requestId)
    }
    
    func cancelFriendRequest(requestId: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        requests.removeValue(forKey: requestId)
    }
    
    func unfriend(uid: String, friendUid: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        friends[uid]?.remove(friendUid)
        friends[friendUid]?.remove(uid)
    }
    
    func listenFriendRequests(uid: String, onChange: @escaping ([FriendRequest]) -> Void, onError: @escaping (Error) -> Void) -> AnyObject? {
        let relevant = requests.values.filter { $0.fromUid == uid || $0.toUid == uid }
        onChange(Array(relevant))
        return NSObject()
    }
    
    func fetchFriends(uid: String) async throws -> [AppUser] {
        try? await Task.sleep(nanoseconds: 200_000_000)
        let friendIds = friends[uid] ?? []
        return friendIds.compactMap { self.users[$0] }
    }
}
