//
//  ChatMessage.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

struct ChatMessage: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var threadId: String
    var text: String
    var senderId: String
    var createdAt: Date
    var clientTimestamp: Date? // Robust sort key (set at local creation time)
    var attachmentURL: String?
    var type: ChatMessageType = .text
    
    // Read Receipt Status (WhatsApp style)
    var isRead: Bool = false
    var readAt: Date? = nil
    
    // Shared Post Data
    var sharedPostId: String? = nil
    var postPreview: PostSharePreview? = nil
    
    // Shared Event Data
    var sharedEventId: String? = nil
    var eventPreview: EventSharePreview? = nil

    // Story Reply Data
    var replyToStoryId: String? = nil
    var storyPreview: StorySharePreview? = nil

    // Optional sender name for group chats
    var senderName: String = ""
    
    // Computed property to robustly resolve the post ID
    var normalizedPostId: String? {
        if let id = sharedPostId, !id.isEmpty { return id }
        if let previewId = postPreview?.id, !previewId.isEmpty { return previewId }
        return nil
    }

    // Computed property for time label
    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

enum ChatMessageType: String, Codable, Equatable, Hashable {
    case text
    case post
    case image
    case event
    case storyReply     // Reply to a story
    case storyReaction  // Emoji reaction to a story
}

struct PostSharePreview: Codable, Equatable, Hashable {
    var id: String? 
    var authorId: String?
    var authorName: String?
    var authorUsername: String?
    var authorAvatarURL: String?
    var caption: String?
    var mediaURL: String?
    var mediaType: Int? // 0 = Image, 1 = Video
    var aspectRatio: Double?
}

struct EventSharePreview: Codable, Equatable, Hashable {
    var id: String
    var title: String
    var dateLabel: String
    var locationName: String?
    var coverImageURL: String?
    var categoryIcon: String?
    var category: String? // Raw value of EventCategory for default image lookup
    var lat: Double?
    var lon: Double?
}

struct StorySharePreview: Codable, Equatable, Hashable {
    var storyId: String
    var ownerId: String
    var ownerName: String?
    var ownerAvatarURL: String?
    var thumbnailURL: String?
    var mediaType: String?    // "image" or "video"
    var createdAt: Date?
}
