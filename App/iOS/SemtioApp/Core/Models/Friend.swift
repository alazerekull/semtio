//
//  Friend.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

struct Friend: Identifiable, Codable, Equatable {
    var id: String
    var fullName: String
    var username: String
    var avatarAssetName: String?
    var city: String?
    var isOnline: Bool
    var mutualFriendCount: Int
    
    var displayName: String { fullName }
}
