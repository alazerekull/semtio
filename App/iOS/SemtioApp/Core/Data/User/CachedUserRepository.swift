//
//  CachedUserRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

/// A wrapper around UserRepositoryProtocol that adds in-memory caching with TTL and request coalescing.
class CachedUserRepository: UserRepositoryProtocol {
    
    private let upstream: UserRepositoryProtocol
    private let cache = MemoryCache.shared
    private let coalescer = InflightTaskCoalescer()
    
    /// Default TTL: 5 minutes for profiles
    private let defaultTTL: TimeInterval = 300
    
    init(upstream: UserRepositoryProtocol) {
        self.upstream = upstream
    }
    
    // MARK: - Core
    
    func fetchUser(id: String) async throws -> AppUser? {
        let cacheKey = "user_\(id)"
        
        // 1. Check cache
        if let cached = cache.get(forKey: cacheKey) as? AppUser {
            return cached
        }
        
        // 2. Fetch from upstream (coalesced)
        return try await coalescer.perform(key: cacheKey) {
            let user = try await self.upstream.fetchUser(id: id)
            
            // 3. Cache result
            if let user = user {
                self.cache.insert(user, forKey: cacheKey, ttl: self.defaultTTL)
            }
            return user
        }
    }
    
    func fetchUser(username: String) async throws -> AppUser? {
        // Forward to upstream (no caching for username lookup yet)
        return try await upstream.fetchUser(username: username)
    }
    
    func saveUser(_ user: AppUser) async throws {
        try await upstream.saveUser(user)
        let cacheKey = "user_\(user.id)"
        cache.insert(user, forKey: cacheKey, ttl: defaultTTL)
    }
    
    func deleteUser(id: String) async throws {
        try await upstream.deleteUser(id: id)
        cache.remove(forKey: "user_\(id)")
    }
    
    // MARK: - Start/Stop Listening
    
    func listenUser(id: String, onChange: @escaping (AppUser?) -> Void, onError: @escaping (Error) -> Void) -> AnyObject? {
        // Listeners bypass data cache to get real-time updates, but we update cache on incoming changes
        return upstream.listenUser(id: id, onChange: { [weak self] user in
            if let user = user {
                self?.cache.insert(user, forKey: "user_\(id)", ttl: self?.defaultTTL ?? 300)
            } else {
                self?.cache.remove(forKey: "user_\(id)")
            }
            onChange(user)
        }, onError: onError)
    }
    
    func removeListener(_ listener: AnyObject) {
        upstream.removeListener(listener)
    }
    
    // MARK: - Other Passthrough Methods
    
    func searchUsers(query: String) async throws -> [UserLite] {
        // Should we cache searches? Maybe not.
        return try await upstream.searchUsers(query: query)
    }
    
    func fetchSuggestedUsers(limit: Int) async throws -> [AppUser] {
        let users = try await upstream.fetchSuggestedUsers(limit: limit)
        // Opportunistically cache users fetched
        users.forEach { cache.insert($0, forKey: "user_\($0.id)", ttl: defaultTTL) }
        return users
    }
    
    func upsertUser(id: String, email: String?, displayName: String?) async throws {
        try await upstream.upsertUser(id: id, email: email, displayName: displayName)
        cache.remove(forKey: "user_\(id)") // Invalidate
    }
    
    // MARK: - Share Code
    
    func ensureShareCode(uid: String) async throws -> String {
        return try await upstream.ensureShareCode(uid: uid)
    }
    
    func updateShareCode(uid: String, code: String) async throws {
        try await upstream.updateShareCode(uid: uid, code: code)
        // User object changed (shareCode property)
        cache.remove(forKey: "user_\(uid)")
    }
    
    // MARK: - Privacy
    
    func updateProfilePrivacy(uid: String, isPublic: Bool) async throws {
        try await upstream.updateProfilePrivacy(uid: uid, isPublic: isPublic)
        cache.remove(forKey: "user_\(uid)")
    }
    
    func fetchProfilePrivacy(uid: String) async throws -> Bool {
        return try await upstream.fetchProfilePrivacy(uid: uid)
    }
    
    // MARK: - Saved Events
    
    func saveEvent(eventId: String, uid: String) async throws {
        try await upstream.saveEvent(eventId: eventId, uid: uid)
        cache.remove(forKey: "user_\(uid)") // Invalidate if user stores this list
    }
    
    func unsaveEvent(eventId: String, uid: String) async throws {
        try await upstream.unsaveEvent(eventId: eventId, uid: uid)
        cache.remove(forKey: "user_\(uid)")
    }
    
    func fetchSavedEventIds(uid: String) async throws -> Set<String> {
        return try await upstream.fetchSavedEventIds(uid: uid)
    }
    
    // MARK: - Blocking
    
    func blockUser(uid: String, blockedUid: String) async throws {
        try await upstream.blockUser(uid: uid, blockedUid: blockedUid)
        cache.remove(forKey: "user_\(uid)")
    }
    
    func unblockUser(uid: String, blockedUid: String) async throws {
        try await upstream.unblockUser(uid: uid, blockedUid: blockedUid)
        cache.remove(forKey: "user_\(uid)")
    }
    
    func fetchBlockedUsers(uid: String) async throws -> Set<String> {
        return try await upstream.fetchBlockedUsers(uid: uid)
    }
    
    // MARK: - Saved Posts
    
    func savePost(postId: String, uid: String) async throws {
        try await upstream.savePost(postId: postId, uid: uid)
        cache.remove(forKey: "user_\(uid)")
    }
    
    func unsavePost(postId: String, uid: String) async throws {
        try await upstream.unsavePost(postId: postId, uid: uid)
        cache.remove(forKey: "user_\(uid)")
    }
    
    func fetchSavedPostIds(uid: String) async throws -> Set<String> {
        return try await upstream.fetchSavedPostIds(uid: uid)
    }
    
    // MARK: - Friends / Requests
    
    func sendFriendRequest(fromUid: String, toUid: String) async throws {
        try await upstream.sendFriendRequest(fromUid: fromUid, toUid: toUid)
        // Friend graph changed for both users; invalidate caches opportunistically
        cache.remove(forKey: "user_\(fromUid)")
        cache.remove(forKey: "user_\(toUid)")
    }
    
    func acceptFriendRequest(requestId: String, fromUid: String, toUid: String) async throws {
        try await upstream.acceptFriendRequest(requestId: requestId, fromUid: fromUid, toUid: toUid)
        cache.remove(forKey: "user_\(fromUid)")
        cache.remove(forKey: "user_\(toUid)")
    }
    
    func rejectFriendRequest(requestId: String) async throws {
        try await upstream.rejectFriendRequest(requestId: requestId)
        // No-op cache; user objects may not change.
    }
    
    func cancelFriendRequest(requestId: String) async throws {
        try await upstream.cancelFriendRequest(requestId: requestId)
        // No-op cache; user objects may not change.
    }
    
    func unfriend(uid: String, friendUid: String) async throws {
        try await upstream.unfriend(uid: uid, friendUid: friendUid)
        cache.remove(forKey: "user_\(uid)")
        cache.remove(forKey: "user_\(friendUid)")
    }
    
    func listenFriendRequests(uid: String, onChange: @escaping ([FriendRequest]) -> Void, onError: @escaping (Error) -> Void) -> AnyObject? {
        return upstream.listenFriendRequests(uid: uid, onChange: onChange, onError: onError)
    }
    
    func fetchFriends(uid: String) async throws -> [AppUser] {
        return try await upstream.fetchFriends(uid: uid)
    }
}
