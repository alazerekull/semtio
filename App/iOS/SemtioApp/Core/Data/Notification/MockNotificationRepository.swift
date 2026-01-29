//
//  MockNotificationRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

final class MockNotificationRepository: NotificationRepositoryProtocol {
    private var notifications: [AppNotification] = MockNotificationRepository.generateMockData()

    func fetchNotifications(userId: String, limit: Int = 50) async throws -> [AppNotification] {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3s delay
        return Array(notifications.prefix(limit))
    }
    
    func listenNotifications(userId: String, limit: Int, onChange: @escaping ([AppNotification]) -> Void) -> AnyObject? {
        // Mock immediate return
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onChange(Array(self.notifications.prefix(limit)))
        }
        return "mock_listener" as AnyObject
    }
    
    func stopListening(_ token: AnyObject?) {
        // no-op for mock
    }

    func fetchUnreadCount(userId: String) async throws -> Int {
        return notifications.filter { !$0.isRead }.count
    }

    func markAsRead(notificationId: String) async throws {
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            notifications[index].isRead = true
        }
    }

    func markAllAsRead(userId: String) async throws {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
    }

    func deleteNotification(notificationId: String) async throws {
        notifications.removeAll { $0.id == notificationId }
    }

    func createNotification(_ notification: AppNotification) async throws {
        notifications.insert(notification, at: 0)
    }

    // MARK: - Mock Data Generator

    private static func generateMockData() -> [AppNotification] {
        let now = Date()
        return [
            AppNotification(
                id: "notif_1",
                userId: "current_user",
                type: .eventInvite,
                title: "Etkinlik Daveti",
                body: "Ahmet seni 'Kadıköy Kahve Buluşması' etkinliğine davet etti.",
                createdAt: now.addingTimeInterval(-300), // 5 dk önce
                isRead: false,
                fromUserId: "user_ahmet",
                fromUserName: "Ahmet Yılmaz",
                fromUserAvatar: nil,
                eventId: "event_123",
                eventName: "Kadıköy Kahve Buluşması"
            ),
            AppNotification(
                id: "notif_2",
                userId: "current_user",
                type: .postLike,
                title: "Beğeni",
                body: "Elif gönderini beğendi.",
                createdAt: now.addingTimeInterval(-1800), // 30 dk önce
                isRead: false,
                fromUserId: "user_elif",
                fromUserName: "Elif Kaya",
                fromUserAvatar: nil,
                postId: "post_456"
            ),
            AppNotification(
                id: "notif_3",
                userId: "current_user",
                type: .postComment,
                title: "Yorum",
                body: "Mehmet gönderine yorum yaptı: \"Harika görünüyor!\"",
                createdAt: now.addingTimeInterval(-3600), // 1 saat önce
                isRead: false,
                fromUserId: "user_mehmet",
                fromUserName: "Mehmet Demir",
                fromUserAvatar: nil,
                postId: "post_456",
                commentId: "comment_789"
            ),
            AppNotification(
                id: "notif_4",
                userId: "current_user",
                type: .friendRequest,
                title: "Arkadaşlık İsteği",
                body: "Zeynep sana arkadaşlık isteği gönderdi.",
                createdAt: now.addingTimeInterval(-7200), // 2 saat önce
                isRead: true,
                fromUserId: "user_zeynep",
                fromUserName: "Zeynep Öztürk",
                fromUserAvatar: nil
            ),
            AppNotification(
                id: "notif_5",
                userId: "current_user",
                type: .eventReminder,
                title: "Etkinlik Hatırlatma",
                body: "'Beşiktaş Sahil Koşusu' yarın saat 09:00'da başlıyor.",
                createdAt: now.addingTimeInterval(-10800), // 3 saat önce
                isRead: true,
                eventId: "event_789",
                eventName: "Beşiktaş Sahil Koşusu"
            ),
            AppNotification(
                id: "notif_6",
                userId: "current_user",
                type: .newFollower,
                title: "Yeni Takipçi",
                body: "Can seni takip etmeye başladı.",
                createdAt: now.addingTimeInterval(-86400), // 1 gün önce
                isRead: true,
                fromUserId: "user_can",
                fromUserName: "Can Arslan",
                fromUserAvatar: nil
            ),
            AppNotification(
                id: "notif_7",
                userId: "current_user",
                type: .eventInviteAccepted,
                title: "Davet Kabul Edildi",
                body: "Selin 'Park Pikniği' davetini kabul etti.",
                createdAt: now.addingTimeInterval(-172800), // 2 gün önce
                isRead: true,
                fromUserId: "user_selin",
                fromUserName: "Selin Ak",
                fromUserAvatar: nil,
                eventId: "event_321",
                eventName: "Park Pikniği"
            )
        ]
    }
}
