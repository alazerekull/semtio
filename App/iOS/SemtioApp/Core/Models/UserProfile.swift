//
//  UserProfile.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import FirebaseFirestore

struct UserProfile: Identifiable, Codable, Equatable {
    let id: String // uid
    var displayName: String?
    var bio: String?
    var avatarURL: String?
    var isProfilePublic: Bool
    var readReceiptsEnabled: Bool // Görüldü bilgisi (WhatsApp style)
    
    // Stats
    var postCount: Int
    var followersCount: Int
    var followingCount: Int
    var eventCount: Int
    var joinCount: Int
    var friendCount: Int
    
    // Additional Profile Info
    var username: String?
    var city: String?
    var interests: [String]
    var shareCode11: String? 
    
    init(
        id: String,
        displayName: String? = nil,
        bio: String? = nil,
        avatarURL: String? = nil,
        isProfilePublic: Bool = true,
        readReceiptsEnabled: Bool = true,
        postCount: Int = 0,
        followersCount: Int = 0,
        followingCount: Int = 0,
        eventCount: Int = 0,
        joinCount: Int = 0,
        friendCount: Int = 0,
        username: String? = nil,
        city: String? = nil,
        interests: [String] = [],
        shareCode11: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.bio = bio
        self.avatarURL = avatarURL
        self.isProfilePublic = isProfilePublic
        self.readReceiptsEnabled = readReceiptsEnabled
        self.postCount = postCount
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.eventCount = eventCount
        self.joinCount = joinCount
        self.friendCount = friendCount
        self.username = username
        self.city = city
        self.interests = interests
        self.shareCode11 = shareCode11
    }
}
