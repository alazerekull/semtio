//
//  FriendStore.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import Combine
import UIKit

import FirebaseFirestore

@MainActor
final class FriendStore: ObservableObject {
    // MARK: - Friends State
    @Published private(set) var friends: [AppUser] = []
    @Published private(set) var searchResults: [AppUser] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String? = nil
    @Published var lastSearchError: Error? = nil
    
    // Pagination State
    private var lastFriendSnapshot: DocumentSnapshot?
    @Published var hasMoreFriends: Bool = false
    private let pageSize = 15
    
    // ... (rest of props)
    
    // MARK: - Incoming Requests UI State (Phase 1)
    @Published var incomingRequests: [FriendRequest] = []
    @Published var isLoadingIncomingRequests: Bool = false
    @Published var incomingRequestsErrorMessage: String? = nil
    @Published var isIndexBuildingIncomingRequests: Bool = false
    
    /// Button-level loading state for accept/reject
    @Published var processingRequestIds: Set<String> = []
    
    var incomingCount: Int { incomingRequests.count }
    
    // Legacy aliases for compatibility
    var incoming: [FriendRequest] { incomingRequests }
    var isLoadingIncoming: Bool { isLoadingIncomingRequests }
    var incomingError: String? { incomingRequestsErrorMessage }
    
    let repo: FriendRepositoryProtocol
    private let notificationRepo: NotificationRepositoryProtocol
    private let userStore: UserStore

    private var hasLoaded: Bool = false
    private var incomingTask: Task<Void, Never>?

    // Realtime listener for incoming requests
    private var incomingRequestsListener: AnyObject?
    private let db = Firestore.firestore()

    init(repo: FriendRepositoryProtocol, notificationRepo: NotificationRepositoryProtocol, userStore: UserStore) {
        self.repo = repo
        self.notificationRepo = notificationRepo
        self.userStore = userStore
    }

    deinit {
        // Remove listener directly without calling MainActor method
        // (deinit runs in non-isolated context)
        (incomingRequestsListener as? ListenerRegistration)?.remove()
    }

    // MARK: - Realtime Listener for Incoming Requests

    /// Starts a realtime listener for incoming friend requests
    func startListeningForIncomingRequests() {
        let userId = userStore.currentUser.id
        guard !userId.isEmpty else { return }

        // Remove existing listener if any
        stopListeningForIncomingRequests()

        // Delegate to repository
        let listener = repo.listenIncomingRequests(userId: userId) { [weak self] requests in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.incomingRequests = requests
                self.isIndexBuildingIncomingRequests = false
                self.incomingRequestsErrorMessage = nil
            }
        }
        
        // Store as ListenerRegistration if possible for explicit removal, or just keep reference
        self.incomingRequestsListener = listener

        print("FriendStore: Started listening for incoming requests for user \(userId)")
    }

    /// Stops the realtime listener
    func stopListeningForIncomingRequests() {
        (incomingRequestsListener as? ListenerRegistration)?.remove()
        incomingRequestsListener = nil
    }
    
    // MARK: - Friends Loading
    
    func loadIfNeeded(userId: String) async {
        guard !hasLoaded else { return }
        await loadFriends(userId: userId)
        hasLoaded = true
    }
    
    func loadFriends(userId: String) async {
        isLoading = true
        errorMessage = nil
        lastFriendSnapshot = nil
        hasMoreFriends = false
        
        do {
            let page = try await repo.fetchFriends(userId: userId, limit: pageSize, startAfter: nil)
            friends = page.users
            lastFriendSnapshot = page.lastSnapshot
            hasMoreFriends = page.hasMore
        } catch {
            errorMessage = error.localizedDescription
            friends = []
        }
        isLoading = false
    }
    
    func loadMoreFriends(userId: String) async {
        guard !isLoadingMore, hasMoreFriends, let lastSnap = lastFriendSnapshot else { return }
        
        isLoadingMore = true
        do {
           let page = try await repo.fetchFriends(userId: userId, limit: pageSize, startAfter: lastSnap)
           // Append unique friends just in case
           let newFriends = page.users.filter { newUser in
               !friends.contains(where: { $0.id == newUser.id })
           }
           friends.append(contentsOf: newFriends)
           
           lastFriendSnapshot = page.lastSnapshot
           hasMoreFriends = page.hasMore
        } catch {
            print("Failed to load more friends: \(error.localizedDescription)")
        }
        isLoadingMore = false
    }
    
    // MARK: - Incoming Requests (Phase 1 Enhanced)
    
    /// Classifies Firestore errors to detect index building state
    private func classifyFirestoreError(_ error: Error) -> (isIndexBuilding: Bool, message: String) {
        let msg = (error as NSError).localizedDescription.lowercased()
        let isBuilding = msg.contains("currently building") || msg.contains("cannot be used yet") || msg.contains("index")
        return (isBuilding, (error as NSError).localizedDescription)
    }
    
    /// Load incoming requests with force refresh option
    func loadIncomingRequests(force: Bool = false) async {
        if isLoadingIncomingRequests { return }
        if !force, !incomingRequests.isEmpty { return }
        
        incomingTask?.cancel()
        incomingTask = Task { [weak self] in
            guard let self else { return }
            
            self.isLoadingIncomingRequests = true
            self.incomingRequestsErrorMessage = nil
            self.isIndexBuildingIncomingRequests = false
            
            do {
                let reqs = try await repo.fetchIncomingRequests()
                // Sort by createdAt descending (newest first)
                self.incomingRequests = reqs.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            } catch {
                let c = self.classifyFirestoreError(error)
                self.isIndexBuildingIncomingRequests = c.isIndexBuilding
                self.incomingRequestsErrorMessage = c.isIndexBuilding ? nil : c.message
            }
            
            self.isLoadingIncomingRequests = false
        }
        
        await incomingTask?.value
    }
    
    // MARK: - Accept / Reject (with animations + haptics)
    
    func accept(request: FriendRequest) async {
        processingRequestIds.insert(request.id)
        defer { processingRequestIds.remove(request.id) }
        
        do {
            try await repo.acceptFriendRequest(requestId: request.id)
            // Optimistic UI: remove from list
            incomingRequests.removeAll { $0.id == request.id }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            // Notify the requester
            await createAcceptNotification(to: request.fromUid)
        } catch {
            incomingRequestsErrorMessage = (error as NSError).localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    func reject(request: FriendRequest) async {
        processingRequestIds.insert(request.id)
        defer { processingRequestIds.remove(request.id) }
        
        do {
            try await repo.rejectFriendRequest(requestId: request.id)
            incomingRequests.removeAll { $0.id == request.id }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } catch {
            incomingRequestsErrorMessage = (error as NSError).localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    func cancelRequest(requestId: String) async {
        processingRequestIds.insert(requestId)
        defer { processingRequestIds.remove(requestId) }
        
        do {
            try await repo.cancelFriendRequest(requestId: requestId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("❌ Failed to cancel request: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    // MARK: - Notification Helpers
    
    func acceptRequest(fromUserId: String) async {
        // Ensure requests are loaded
        await loadIncomingRequests()
        
        if let request = incomingRequests.first(where: { $0.fromUid == fromUserId }) {
            await accept(request: request)
        } else {
             print("❌ FriendStore: Could not find request from \(fromUserId)")
        }
    }

    func rejectRequest(fromUserId: String) async {
        await loadIncomingRequests()
        if let request = incomingRequests.first(where: { $0.fromUid == fromUserId }) {
            await reject(request: request)
        }
    }
    
    // MARK: - Search
    
    /// Searches users with proper error handling.
    func search(query: String) async {
        lastSearchError = nil
        
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            searchResults = []
            return
        }
        
        isLoading = true
        
        do {
            print("🔍 FriendStore.search calling repo.searchUsers with: '\(query)'")
            searchResults = try await repo.searchUsers(query: query)
            print("✅ FriendStore.search received \(searchResults.count) results")
        } catch {
            print("❌ FriendStore.search FAILED: \(error.localizedDescription)")
            searchResults = []
            lastSearchError = error
            errorMessage = "Arama başarısız: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func sendRequest(from: String, to: String) async {
        do {
            let currentUser = userStore.currentUser
            try await repo.sendFriendRequest(
                from: from,
                to: to,
                senderName: currentUser.displayName,
                senderAvatar: currentUser.avatarURL
            )
            // Notify target
            await createRequestNotification(to: to, from: from)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Clears search state
    func clearSearch() {
        searchResults = []
        lastSearchError = nil
    }
    
    // MARK: - Private Notification Helpers
    
    private func createRequestNotification(to targetUid: String, from currentUid: String) async {
        let currentUser = userStore.currentUser
        let notification = AppNotification(
            id: UUID().uuidString,
            userId: targetUid,
            type: .friendRequest,
            title: "Arkadaşlık İsteği",
            body: "\(currentUser.displayName) sana arkadaşlık isteği gönderdi.",
            createdAt: Date(),
            isRead: false,
            fromUserId: currentUid,
            fromUserName: currentUser.displayName,
            fromUserAvatar: currentUser.avatarURL
        )
        try? await notificationRepo.createNotification(notification)
    }
    
    private func createAcceptNotification(to targetUid: String) async {
        let currentUser = userStore.currentUser
        
        let notification = AppNotification(
            id: UUID().uuidString,
            userId: targetUid,
            type: .friendRequestAccepted,
            title: "Arkadaş Oldunuz",
            body: "\(currentUser.displayName) arkadaşlık isteğini kabul etti.",
            createdAt: Date(),
            isRead: false,
            fromUserId: currentUser.id,
            fromUserName: currentUser.displayName,
            fromUserAvatar: currentUser.avatarURL
        )
        try? await notificationRepo.createNotification(notification)
    }
}
