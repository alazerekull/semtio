//
//  Post.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import FirebaseFirestore

struct Post: Identifiable, Codable, Equatable {
    let id: String
    let ownerId: String
    let ownerUsername: String?
    let ownerDisplayName: String?
    let ownerAvatarURL: String?
    let caption: String
    let mediaURLs: [String]
    let mediaType: MediaType
    let thumbnailURL: String?
    let createdAt: Date
    let updatedAt: Date
    var likeCount: Int
    var commentCount: Int
    let visibility: String // "public", "followers", "private"

    // New fields for Activity/Event linking
    let type: PostType
    let eventId: String?
    let eventName: String?

    // Local state for UI
    var isLiked: Bool = false
    
    // SCHEMA ADDITIONS
    var likedBy: [String: Bool] = [:] // Map of user IDs who liked
    var sharesCount: Int = 0
    var sharedBy: [String: Bool] = [:] // Map of user IDs who shared

    enum MediaType: String, Codable {
        case image = "image"
        case video = "video"
    }

    enum PostType: String, Codable {
        case standard = "standard"
        case userJoinedEvent = "user_joined_event"
        case userCreatedEvent = "user_created_event"
        case eventStarted = "event_started"
        case eventEnded = "event_ended"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerId
        case ownerUsername
        case ownerDisplayName
        case ownerAvatarURL
        case caption
        case mediaURLs
        case mediaType
        case thumbnailURL
        case createdAt
        case updatedAt
        case likeCount
        case commentCount
        case visibility
        case type
        case eventId
        case eventName
        case likedBy
        case sharesCount
        case sharedBy
    }
    
    init(
        id: String,
        ownerId: String,
        ownerUsername: String?,
        ownerDisplayName: String?,
        ownerAvatarURL: String?,
        caption: String,
        mediaURLs: [String],
        mediaType: MediaType = .image,
        thumbnailURL: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        likeCount: Int,
        commentCount: Int,
        visibility: String,
        type: PostType = .standard,
        eventId: String? = nil,
        eventName: String? = nil,
        isLiked: Bool = false,
        likedBy: [String: Bool] = [:],
        sharesCount: Int = 0,
        sharedBy: [String: Bool] = [:]
    ) {
        self.id = id
        self.ownerId = ownerId
        self.ownerUsername = ownerUsername
        self.ownerDisplayName = ownerDisplayName
        self.ownerAvatarURL = ownerAvatarURL
        self.caption = caption
        self.mediaURLs = mediaURLs
        self.mediaType = mediaType
        self.thumbnailURL = thumbnailURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.visibility = visibility
        self.type = type
        self.eventId = eventId
        self.eventName = eventName
        self.isLiked = isLiked
        self.likedBy = likedBy
        self.sharesCount = sharesCount
        self.sharedBy = sharedBy
    }
}


