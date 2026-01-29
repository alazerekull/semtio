//
//  NotificationStore.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class NotificationStore: ObservableObject {

    @Published private(set) var notifications: [AppNotification] = []
    @Published private(set) var unreadCount: Int = 0
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: String?

    private let repo: NotificationRepositoryProtocol
    private var currentUserUid: String?
    private var listener: AnyObject?

    init(repo: NotificationRepositoryProtocol) {
        self.repo = repo
    }

    // MARK: - User Management

    func setUser(uid: String?) {
        // cleanup old listener
        if let listener = listener {
            repo.stopListening(listener)
            self.listener = nil
        }
        
        self.currentUserUid = uid
        if let uid = uid {
            setupListener(userId: uid)
        } else {
            notifications.removeAll()
            unreadCount = 0
        }
    }
    
    private func setupListener(userId: String) {
        isLoading = true
        
        // Start listening
        listener = repo.listenNotifications(userId: userId, limit: 50) { [weak self] newNotifications in
            guard let self = self else { return }
            self.notifications = newNotifications
            self.isLoading = false
            
            // Recalculate unread count locally strictly from the list or fetch fresh?
            // Usually unread count might be more than the list limit (50).
            // So we should fetch unread count separately or rely on simple count from list if appropriate.
            // For accuracy, let's fetch count.
            Task { await self.refreshUnreadCount() }
        }
    }

    // MARK: - Data Loading

    func refresh() async {
        // Manual refresh currently primarily for unread count,
        // as notifications are live. But we can ensure listener is active?
        // For now, just refresh unread count as listener handles the list.
        await refreshUnreadCount()
    }

    func refreshUnreadCount() async {
        guard let uid = currentUserUid else { return }

        do {
            unreadCount = try await repo.fetchUnreadCount(userId: uid)
        } catch {
            print("❌ NotificationStore: Failed to fetch unread count: \(error)")
        }
    }

    // MARK: - Actions

    func markAsRead(_ notification: AppNotification) async {
        guard !notification.isRead else { return }

        // Optimistic update
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
            unreadCount = max(0, unreadCount - 1)
        }

        do {
            try await repo.markAsRead(notificationId: notification.id)
        } catch {
            // Rollback on failure
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index].isRead = false
                unreadCount += 1
            }
            print("❌ NotificationStore: Failed to mark as read: \(error)")
        }
    }

    func markAllAsRead() async {
        guard let uid = currentUserUid else { return }

        // Optimistic update
        let previousNotifications = notifications
        let previousCount = unreadCount

        for i in notifications.indices {
            notifications[i].isRead = true
        }
        unreadCount = 0

        do {
            try await repo.markAllAsRead(userId: uid)
        } catch {
            // Rollback on failure
            notifications = previousNotifications
            unreadCount = previousCount
            print("❌ NotificationStore: Failed to mark all as read: \(error)")
        }
    }

    func deleteNotification(_ notification: AppNotification) async {
        // Optimistic update
        let wasUnread = !notification.isRead
        notifications.removeAll { $0.id == notification.id }
        if wasUnread {
            unreadCount = max(0, unreadCount - 1)
        }

        do {
            try await repo.deleteNotification(notificationId: notification.id)
        } catch {
            // Rollback on failure - re-fetch to get correct state
            await refresh()
            print("❌ NotificationStore: Failed to delete notification: \(error)")
        }
    }
    
    func sendNotification(_ notification: AppNotification) async {
        do {
            try await repo.createNotification(notification)
        } catch {
            print("❌ NotificationStore: Failed to send notification: \(error)")
        }
    }

    // MARK: - Helpers

    var hasUnread: Bool {
        unreadCount > 0
    }

    var unreadBadgeText: String? {
        guard unreadCount > 0 else { return nil }
        return unreadCount > 99 ? "99+" : "\(unreadCount)"
    }
}
