//
//  MockFriendRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

import FirebaseFirestore

final class MockFriendRepository: FriendRepositoryProtocol {
    
    /// All searchable users in the system (mock).
    private var allUsers: [AppUser] = []
    
    /// Current user's friends (mock).
    private var friends: [AppUser] = []
    
    /// Pending outgoing friend requests (sender → receiver).
    private var pendingOutgoing: [String: Set<String>] = [:]  // [senderUid: Set<receiverUid>]
    
    init() {
        // Expanded mock user pool for search
        allUsers = [
            AppUser(id: "user2", fullName: "Ahmet Yılmaz", avatarAssetName: "avatar1", headline: "Mobil Geliştirici", username: "ahmet", city: "İstanbul", bio: "Kod yazmayı severim", interests: ["Yazılım"], shareCode11: "AHM12345678", district: "Kadıköy"),
            AppUser(id: "user3", fullName: "Ayşe Demir", avatarAssetName: "avatar2", headline: "Tasarımcı", username: "ayse", city: "İzmir", bio: "UX Design", interests: ["Tasarım"], shareCode11: "AYS98765432", district: "Alsancak"),
            AppUser(id: "user4", fullName: "Mehmet Kaya", avatarAssetName: nil, headline: "Girişimci", username: "mehmet_k", city: "Ankara", bio: "Startup founder", interests: ["İş"], shareCode11: "MEH11223344", district: "Çankaya"),
            AppUser(id: "user5", fullName: "Elif Özkan", avatarAssetName: nil, headline: "Fotoğrafçı", username: "elif_oz", city: "İstanbul", bio: "Nature lover", interests: ["Fotoğraf"], shareCode11: "ELF55667788", district: "Beşiktaş"),
            AppUser(id: "user6", fullName: "Can Yıldırım", avatarAssetName: nil, headline: "Müzisyen", username: "can_music", city: "İstanbul", bio: "Guitar player", interests: ["Müzik"], shareCode11: "CAN99887766", district: "Beyoğlu"),
            AppUser(id: "user7", fullName: "Zeynep Arslan", avatarAssetName: nil, headline: "Öğretmen", username: "zeynep_a", city: "Bursa", bio: "Education is key", interests: ["Eğitim"], shareCode11: "ZEY44556677", district: "Nilüfer"),
            AppUser(id: "user8", fullName: "Ali Çelik", avatarAssetName: nil, headline: "Software Engineer", username: "ali_dev", city: "İstanbul", bio: "Swift & Kotlin", interests: ["Yazılım"], shareCode11: "ALI33221100", district: "Şişli")
        ]
        
        // Current user's existing friends
        friends = [allUsers[0], allUsers[1]]  // Ahmet and Ayşe
    }
    
    func fetchFriends(userId: String, limit: Int, startAfter: DocumentSnapshot?) async throws -> FriendPage {
        try? await Task.sleep(nanoseconds: 200_000_000)
        // Mock pagination: just return all for now or empty if startAfter is set (simple 1 page mock)
        if startAfter != nil {
            return FriendPage(users: [], lastSnapshot: nil, hasMore: false)
        }
        return FriendPage(users: friends, lastSnapshot: nil, hasMore: false)
    }
    
    func searchUsers(query: String) async throws -> [AppUser] {
        try? await Task.sleep(nanoseconds: 300_000_000)  // Simulate network
        
        guard !query.isEmpty else { return [] }
        
        let lowercasedQuery = query.lowercased()
        return allUsers.filter { user in
            user.fullName.lowercased().contains(lowercasedQuery) ||
            (user.username?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    func sendFriendRequest(from: String, to: String, senderName: String? = nil, senderAvatar: String? = nil) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Track pending request
        var pending = pendingOutgoing[from] ?? Set()
        pending.insert(to)
        pendingOutgoing[from] = pending

        print("Mock: Friend request sent from \(from) to \(to) (name: \(senderName ?? "nil"))")
    }
    
    func acceptFriendRequest(requestId: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        print("Mock: Friend request accepted: \(requestId)")
    }
    
    func pendingRequests(for uid: String) async throws -> Set<String> {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return pendingOutgoing[uid] ?? Set()
    }
    
    func fetchOutgoingPendingRequests(for uid: String) async throws -> Set<String> {
        return try await pendingRequests(for: uid)
    }
    
    // MARK: - New Protocol Methods
    
    func rejectFriendRequest(requestId: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        print("Mock: Friend request rejected: \(requestId)")
    }
    
    func cancelFriendRequest(requestId: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        print("Mock: Friend request cancelled: \(requestId)")
    }
    
    func removeFriend(friendUid: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
        friends.removeAll { $0.id == friendUid }
        print("Mock: Friend removed: \(friendUid)")
    }
    
    func listenIncomingRequests(userId: String, onChange: @escaping ([FriendRequest]) -> Void) -> AnyObject? {
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            let mocks = try? await fetchIncomingRequests()
            onChange(mocks ?? [])
        }
        return NSObject()
    }
    
    func fetchIncomingRequests() async throws -> [FriendRequest] {
        try? await Task.sleep(nanoseconds: 200_000_000)
        // Return mock incoming requests
        return [
            FriendRequest(id: "req1", fromUid: "user5", toUid: "me", status: "pending", createdAt: Date(), fromName: "Elif Özkan"),
            FriendRequest(id: "req2", fromUid: "user6", toUid: "me", status: "pending", createdAt: Date(), fromName: "Can Yıldırım")
        ]
    }
    
    func fetchOutgoingRequests() async throws -> [FriendRequest] {
        try? await Task.sleep(nanoseconds: 200_000_000)
        // Return mock outgoing requests based on pendingOutgoing
        return [
            FriendRequest(id: "req3", fromUid: "me", toUid: "user7", status: "pending", createdAt: Date(), toName: "Zeynep Arslan")
        ]
    }
}

