//
//  FriendRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

protocol FriendRepository {
    func fetchFriends() async throws -> [Friend]
    func searchFriends(query: String) async throws -> [Friend]
    func addFriend(friendId: String) async throws
}
