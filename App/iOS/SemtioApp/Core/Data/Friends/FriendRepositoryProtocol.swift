//
//  FriendRepositoryProtocol.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

import FirebaseFirestore

struct FriendPage {
    let users: [AppUser]
    let lastSnapshot: DocumentSnapshot?
    let hasMore: Bool
}

protocol FriendRepositoryProtocol {
    // MARK: - Friends
    func fetchFriends(userId: String, limit: Int, startAfter: DocumentSnapshot?) async throws -> FriendPage
    func removeFriend(friendUid: String) async throws
    
    // MARK: - User Search
    func searchUsers(query: String) async throws -> [AppUser]
    
    // MARK: - Friend Requests
    func sendFriendRequest(from fromUid: String, to toUid: String, senderName: String?, senderAvatar: String?) async throws
    func acceptFriendRequest(requestId: String) async throws
    func rejectFriendRequest(requestId: String) async throws
    func cancelFriendRequest(requestId: String) async throws
    
    // MARK: - Fetch Requests
    func fetchIncomingRequests() async throws -> [FriendRequest]
    func listenIncomingRequests(userId: String, onChange: @escaping ([FriendRequest]) -> Void) -> AnyObject?
    func fetchOutgoingRequests() async throws -> [FriendRequest]
    
    /// Returns UIDs of users to whom we have already sent a pending request.
    func pendingRequests(for uid: String) async throws -> Set<String>
    func fetchOutgoingPendingRequests(for uid: String) async throws -> Set<String>
}

