//
//  NotificationRepositoryProtocol.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

protocol NotificationRepositoryProtocol {
    /// Fetches notifications for a user
    func fetchNotifications(userId: String, limit: Int) async throws -> [AppNotification]
    
    /// Listens for real-time notification updates
    func listenNotifications(userId: String, limit: Int, onChange: @escaping ([AppNotification]) -> Void) -> AnyObject?
    
    /// Stops the real-time listener
    func stopListening(_ token: AnyObject?)

    /// Fetches unread notification count
    func fetchUnreadCount(userId: String) async throws -> Int

    /// Marks a notification as read
    func markAsRead(notificationId: String) async throws

    /// Marks all notifications as read for a user
    func markAllAsRead(userId: String) async throws

    /// Deletes a notification
    func deleteNotification(notificationId: String) async throws

    /// Creates a new notification (used by server-side triggers or for testing)
    func createNotification(_ notification: AppNotification) async throws
}
