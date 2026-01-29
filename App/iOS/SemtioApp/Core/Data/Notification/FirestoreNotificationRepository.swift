//
//  FirestoreNotificationRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import FirebaseFirestore

final class FirestoreNotificationRepository: NotificationRepositoryProtocol {
    private let db = Firestore.firestore()
    private let collection = "notifications"

    func fetchNotifications(userId: String, limit: Int = 50) async throws -> [AppNotification] {
        let snapshot = try await db.collection(collection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { AppNotification.fromDoc($0) }
    }
    
    func listenNotifications(userId: String, limit: Int, onChange: @escaping ([AppNotification]) -> Void) -> AnyObject? {
        // Real-time listener
        let listener = db.collection(collection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else {
                    print("❌ Notification Listener Error: \(error?.localizedDescription ?? "unknown")")
                    return
                }
                
                let notifications = docs.compactMap { AppNotification.fromDoc($0) }
                onChange(notifications)
            }
        
        return listener
    }
    
    func stopListening(_ token: AnyObject?) {
        (token as? ListenerRegistration)?.remove()
    }

    func fetchUnreadCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection(collection)
            .whereField("userId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .count
            .getAggregation(source: .server)

        return Int(truncating: snapshot.count)
    }

    func markAsRead(notificationId: String) async throws {
        try await db.collection(collection)
            .document(notificationId)
            .updateData(["isRead": true])
    }

    func markAllAsRead(userId: String) async throws {
        let snapshot = try await db.collection(collection)
            .whereField("userId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        let batch = db.batch()
        for doc in snapshot.documents {
            batch.updateData(["isRead": true], forDocument: doc.reference)
        }
        try await batch.commit()
    }

    func deleteNotification(notificationId: String) async throws {
        try await db.collection(collection)
            .document(notificationId)
            .delete()
    }

    func createNotification(_ notification: AppNotification) async throws {
        try await db.collection(collection)
            .document(notification.id)
            .setData(notification.toFirestoreData())
    }
}
