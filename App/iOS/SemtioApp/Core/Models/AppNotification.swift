//
//  AppNotification.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Model for in-app notifications (event invites, likes, comments, friend requests, etc.)
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct AppNotification: Identifiable, Codable, Equatable {
    let id: String
    let userId: String           // Recipient user ID
    let type: NotificationType
    let title: String
    let body: String
    let createdAt: Date
    var isRead: Bool

    // Related entity IDs
    let fromUserId: String?
    let fromUserName: String?
    let fromUserAvatar: String?
    let eventId: String?
    let eventName: String?
    let postId: String?
    let commentId: String?
    let storyId: String?
    let storyThumbURL: String?    // Story thumbnail for notification UI
    let reactionEmoji: String?    // Emoji used for reaction

    enum NotificationType: String, Codable {
        case eventInvite = "event_invite"              // Etkinlik daveti
        case eventInviteAccepted = "event_invite_accepted" // Davetim kabul edildi
        case eventInviteDeclined = "event_invite_declined" // Davetim reddedildi
        case postLike = "post_like"                    // Gönderime beğeni
        case postComment = "post_comment"              // Gönderime yorum
        case postShare = "post_share"                  // Gönderim paylaşıldı
        case commentReply = "comment_reply"            // Yorumuma yanıt
        case friendRequest = "friend_request"          // Arkadaşlık isteği
        case friendRequestAccepted = "friend_request_accepted" // İsteğim kabul edildi
        case newFollower = "new_follower"              // Yeni takipçi
        case eventReminder = "event_reminder"          // Etkinlik hatırlatma
        case eventUpdate = "event_update"              // Etkinlik güncellendi
        case eventCancelled = "event_cancelled"        // Etkinlik iptal edildi
        case system = "system"                         // Sistem bildirimi

        // Story Notifications
        case storyReply = "story_reply"                // Hikayeme yanıt
        case storyReaction = "story_reaction"          // Hikayeme tepki (emoji)
        case storyLike = "story_like"                  // Hikayemi beğendi
    }

    init(
        id: String,
        userId: String,
        type: NotificationType,
        title: String,
        body: String,
        createdAt: Date = Date(),
        isRead: Bool = false,
        fromUserId: String? = nil,
        fromUserName: String? = nil,
        fromUserAvatar: String? = nil,
        eventId: String? = nil,
        eventName: String? = nil,
        postId: String? = nil,
        commentId: String? = nil,
        storyId: String? = nil,
        storyThumbURL: String? = nil,
        reactionEmoji: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.isRead = isRead
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.fromUserAvatar = fromUserAvatar
        self.eventId = eventId
        self.eventName = eventName
        self.postId = postId
        self.commentId = commentId
        self.storyId = storyId
        self.storyThumbURL = storyThumbURL
        self.reactionEmoji = reactionEmoji
    }

    #if canImport(FirebaseFirestore)
    static func fromDoc(_ doc: DocumentSnapshot) -> AppNotification? {
        guard let data = doc.data() else { return nil }

        let id = doc.documentID
        guard
            let userId = data["userId"] as? String,
            let typeRaw = data["type"] as? String,
            let type = NotificationType(rawValue: typeRaw),
            let title = data["title"] as? String,
            let body = data["body"] as? String
        else { return nil }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let isRead = data["isRead"] as? Bool ?? false

        return AppNotification(
            id: id,
            userId: userId,
            type: type,
            title: title,
            body: body,
            createdAt: createdAt,
            isRead: isRead,
            fromUserId: data["fromUserId"] as? String,
            fromUserName: data["fromUserName"] as? String,
            fromUserAvatar: data["fromUserAvatar"] as? String,
            eventId: data["eventId"] as? String,
            eventName: data["eventName"] as? String,
            postId: data["postId"] as? String,
            commentId: data["commentId"] as? String,
            storyId: data["storyId"] as? String,
            storyThumbURL: data["storyThumbURL"] as? String,
            reactionEmoji: data["reactionEmoji"] as? String
        )
    }

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "type": type.rawValue,
            "title": title,
            "body": body,
            "createdAt": Timestamp(date: createdAt),
            "isRead": isRead
        ]

        if let fromUserId = fromUserId { data["fromUserId"] = fromUserId }
        if let fromUserName = fromUserName { data["fromUserName"] = fromUserName }
        if let fromUserAvatar = fromUserAvatar { data["fromUserAvatar"] = fromUserAvatar }
        if let eventId = eventId { data["eventId"] = eventId }
        if let eventName = eventName { data["eventName"] = eventName }
        if let postId = postId { data["postId"] = postId }
        if let commentId = commentId { data["commentId"] = commentId }
        if let storyId = storyId { data["storyId"] = storyId }
        if let storyThumbURL = storyThumbURL { data["storyThumbURL"] = storyThumbURL }
        if let reactionEmoji = reactionEmoji { data["reactionEmoji"] = reactionEmoji }

        return data
    }
    #endif

    // MARK: - Display Helpers

    var iconName: String {
        switch type {
        case .eventInvite, .eventInviteAccepted, .eventInviteDeclined:
            return "calendar.badge.plus"
        case .postLike:
            return "heart.fill"
        case .postComment, .commentReply:
            return "bubble.left.fill"
        case .postShare:
            return "paperplane.fill"
        case .friendRequest, .friendRequestAccepted:
            return "person.badge.plus"
        case .newFollower:
            return "person.fill.checkmark"
        case .eventReminder:
            return "bell.fill"
        case .eventUpdate:
            return "pencil.circle.fill"
        case .eventCancelled:
            return "calendar.badge.exclamationmark"
        case .system:
            return "info.circle.fill"
        case .storyReply:
            return "arrowshape.turn.up.left.fill"
        case .storyReaction:
            return "face.smiling.fill"
        case .storyLike:
            return "heart.fill"
        }
    }

    var iconColor: String {
        switch type {
        case .eventInvite, .eventInviteAccepted:
            return "5856D6" // Purple
        case .eventInviteDeclined, .eventCancelled:
            return "FF3B30" // Red
        case .postLike, .storyLike:
            return "FF2D55" // Pink
        case .postComment, .commentReply, .storyReply:
            return "007AFF" // Blue
        case .postShare:
            return "5856D6" // Purple
        case .friendRequest, .friendRequestAccepted, .newFollower:
            return "34C759" // Green
        case .eventReminder, .eventUpdate:
            return "FF9500" // Orange
        case .system:
            return "8E8E93" // Gray
        case .storyReaction:
            return "FFD60A" // Yellow
        }
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
