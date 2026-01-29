//
//  ChatStore.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var threads: [ChatThread] = []
    
    // UI Helpers (Computed from threads)
    @Published var dmChats: [ChatSummary] = []
    @Published var groupChats: [ChatSummary] = []
    
    @Published private(set) var currentMessages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    @Published var threadsIndexStatus: String = "Unknown"
    
    let repo: ChatRepositoryProtocol
    private var threadListener: AnyObject?
    private var messageListener: AnyObject?
    private var currentUserId: String?
    
    init(repo: ChatRepositoryProtocol) {
        self.repo = repo
    }
    
    // MARK: - Unread Count
    
    /// Total unread messages across all threads for current user
    var totalUnread: Int {
        guard let uid = currentUserId else { return 0 }
        return threads.reduce(0) { $0 + $1.unreadCount(for: uid) }
    }
    
    // MARK: - Threads
    
    func startListeningThreads(userId: String) {
        currentUserId = userId
        
        // Cleanup previous
        if let token = threadListener {
            repo.stopListening(token)
        }
        
        isLoading = true
        threadsIndexStatus = "Connecting..."
        
        threadListener = repo.listenThreads(userId: userId, onChange: { [weak self] allThreads in
            Task { @MainActor in
                self?.threads = allThreads.sorted { $0.updatedAt > $1.updatedAt }
                self?.processThreads(allThreads, userId: userId)
                self?.isLoading = false
                self?.threadsIndexStatus = "OK (\(allThreads.count) threads)"
            }
        }, onError: { [weak self] error in
            Task { @MainActor in
                self?.isLoading = false
                self?.threadsIndexStatus = "ERROR: \(error.localizedDescription)"
                
                let nsError = error as NSError
                if nsError.domain == FirestoreErrorDomain && nsError.code == FirestoreErrorCode.failedPrecondition.rawValue {
                     self?.threadsIndexStatus = "INDEX REQUIRED"
                }
            }
        })
    }
    
    private func processThreads(_ threads: [ChatThread], userId: String) {
        // Map to ChatSummary
        let summaries: [ChatSummary] = threads.map { thread in
            // Title and Avatar logic
            // For Groups: title is explicit
            // For DMs: title is "Other User" (handled by UI via memberIds usually, or here if we fetched users)
            // Ideally ChatSummary just stores the basic info and UI resolves names asynchronously or via UserStore
            
            return ChatSummary(
                id: thread.id,
                type: thread.type,
                title: thread.title ?? "Sohbet",
                avatarURL: nil, // UI resolves this
                lastMessage: thread.lastMessage?.text,
                lastMessageAt: thread.lastMessage?.createdAt ?? thread.updatedAt,
                unreadCount: thread.unreadCount(for: userId),
                eventId: nil, // Extracted if we add eventId to ChatThread or parse from ID
                memberIds: thread.participants
            )
        }
        
        self.dmChats = summaries.filter { $0.type == .dm }
        self.groupChats = summaries.filter { $0.type == .group || $0.type == .event }
    }
    
    func createDM(with userId: String, currentUserId: String) async -> String? {
        do {
            let thread = try await repo.createOrGetDMThread(uidA: currentUserId, uidB: userId)
            return thread.id
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    /// Gets or creates a DM thread with another user (deterministic, no duplicates)
    func getOrCreateDMThread(currentUserId: String, otherUserId: String) async throws -> ChatThread {
        // Use repository's race-safe implementation
        return try await repo.createOrGetDMThread(uidA: currentUserId, uidB: otherUserId)
    }
    

    /// Gets or creates a Support thread for the user
    /// Gets or creates a Support thread for the user
    func getOrCreateSupportThread(for userId: String) async throws -> String {
        print("🔵 ChatStore: getOrCreateSupportThread for \(userId)")
        
        let supportId = "support_\(userId)"
        
        if let existing = threads.first(where: { $0.id == supportId }) {
            return existing.id
        }
        
        // We use createThread for support as before (repo logic handles idempotency partially or we rely on ID)
        // If repo implementation for support is robust:
        let thread = try await repo.createThread(participants: [userId, "support"], type: .support)
        return thread.id
    }
    
    /// Joins or opens an event group chat
    func openGroupChat(for eventId: String, title: String, currentUserId: String) async -> String? {
        do {
            // Participants: Initially just the joiner. The Repo handles arrayUnion.
            // In a real app, you might sync all participants, but for "Join Chat" button logic:
            let thread = try await repo.createOrGetEventThread(eventId: eventId, title: title, participants: [currentUserId])
            return thread.id
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Messages
    
    func openThread(_ threadId: String) {
        stopListeningMessages()
        
        // Mark as read
        if let uid = currentUserId {
            Task {
                await markThreadRead(threadId: threadId, userId: uid)
            }
        }
        
        // Listen
        messageListener = repo.listenMessages(threadId: threadId) { [weak self] msgs in
            Task { @MainActor in
                self?.currentMessages = msgs.sorted {
                    if let t1 = $0.clientTimestamp, let t2 = $1.clientTimestamp {
                        return t1 < t2
                    }
                    return $0.createdAt < $1.createdAt
                }
            }
        }
    }
    
    func sendMessage(threadId: String, text: String, senderId: String) async {
        let msg = ChatMessage(
            id: UUID().uuidString,
            threadId: threadId,
            text: text,
            senderId: senderId,
            createdAt: Date()
        )
        do {
            try await repo.sendMessage(msg)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Sends a story reply message with story preview
    func sendStoryReply(threadId: String, text: String, senderId: String, story: Story, storyOwner: AppUser) async {
        let storyPreview = StorySharePreview(
            storyId: story.id,
            ownerId: story.ownerId,
            ownerName: storyOwner.fullName,
            ownerAvatarURL: storyOwner.avatarURL,
            thumbnailURL: story.thumbURL ?? story.mediaURL,
            mediaType: story.mediaType.rawValue,
            createdAt: story.createdAt
        )

        var msg = ChatMessage(
            id: UUID().uuidString,
            threadId: threadId,
            text: text,
            senderId: senderId,
            createdAt: Date(),
            type: .storyReply
        )
        msg.replyToStoryId = story.id
        msg.storyPreview = storyPreview

        do {
            try await repo.sendMessage(msg)
        } catch {
            errorMessage = "Hikaye yanıtı gönderilemedi: \(error.localizedDescription)"
        }
    }

    /// Sends a story reaction (emoji) message with story preview
    func sendStoryReaction(threadId: String, emoji: String, senderId: String, story: Story, storyOwner: AppUser) async {
        let storyPreview = StorySharePreview(
            storyId: story.id,
            ownerId: story.ownerId,
            ownerName: storyOwner.fullName,
            ownerAvatarURL: storyOwner.avatarURL,
            thumbnailURL: story.thumbURL ?? story.mediaURL,
            mediaType: story.mediaType.rawValue,
            createdAt: story.createdAt
        )

        var msg = ChatMessage(
            id: UUID().uuidString,
            threadId: threadId,
            text: emoji,
            senderId: senderId,
            createdAt: Date(),
            type: .storyReaction
        )
        msg.replyToStoryId = story.id
        msg.storyPreview = storyPreview

        do {
            try await repo.sendMessage(msg)
        } catch {
            errorMessage = "Hikaye tepkisi gönderilemedi: \(error.localizedDescription)"
        }
    }

    func sendImage(threadId: String, imageData: Data, senderId: String) async {
        do {
            // 1. Upload
            let path = "chats/\(threadId)/\(UUID().uuidString).jpg"
            let url = try await StorageService.shared.uploadImage(data: imageData, path: path)
            
            // 2. Create Message
            let msg = ChatMessage(
                id: UUID().uuidString,
                threadId: threadId,
                text: "📷 Fotoğraf", // Snippet text
                senderId: senderId,
                createdAt: Date(),
                attachmentURL: url,
                type: .image
            )
            
            // 3. Send
            try await repo.sendMessage(msg)
        } catch {
            errorMessage = "Görsel gönderilemedi: \(error.localizedDescription)"
        }
    }
    
    /// Sends a rich Event Card message
    func sendEvent(threadId: String, event: Event, senderId: String) async {
        let msg = ChatMessage(
            id: UUID().uuidString,
            threadId: threadId,
            text: "🎫 Etkinlik: \(event.title)", // Snippet
            senderId: senderId,
            createdAt: Date(),
            type: .event,
            sharedEventId: event.id,
            eventPreview: EventSharePreview(
                id: event.id,
                title: event.title,
                dateLabel: event.dayLabel,
                locationName: event.locationName,
                coverImageURL: event.coverImageURL,
                categoryIcon: event.category.icon,
                category: event.category.rawValue,
                lat: event.lat,
                lon: event.lon
            )
        )
        do {
            try await repo.sendMessage(msg)
        } catch {
            errorMessage = "Etkinlik gönderilemedi: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Mark Read
    
    func markThreadRead(threadId: String, userId: String) async {
        do {
            try await repo.markThreadRead(threadId: threadId, userId: userId)

            // Update local state immediately and rebuild summaries
            // so unread badges disappear without waiting for Firestore listener
            if let index = threads.firstIndex(where: { $0.id == threadId }) {
                threads[index].unreadCounts[userId] = 0
                rebuildSummaries()
            }
        } catch {
            print("⚠️ ChatStore: Failed to mark thread read: \(error)")
        }
    }
    
    // MARK: - Group Chat Operations

    func createGroupChat(
        name: String,
        description: String?,
        participantIds: [String],
        creatorId: String,
        photoData: Data? = nil
    ) async throws -> String {
        #if canImport(FirebaseFirestore)
        guard let firestoreRepo = repo as? FirestoreChatRepository else {
            throw NSError(domain: "ChatStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Repository not available"])
        }

        // 1. Upload group photo if provided
        var photoURL: String? = nil
        if let photoData = photoData {
            let path = "groups/\(UUID().uuidString).jpg"
            photoURL = try await StorageService.shared.uploadImage(data: photoData, path: path)
        }

        // 2. Create thread
        let threadId = try await firestoreRepo.createGroupThread(
            name: name,
            participantIds: participantIds,
            creatorId: creatorId,
            photoURL: photoURL
        )

        // 3. Add system message
        let systemMessage = ChatMessage(
            id: UUID().uuidString,
            threadId: threadId,
            text: "Grup oluşturuldu",
            senderId: "system",
            createdAt: Date(),
            type: .text
        )
        try await repo.sendMessage(systemMessage)

        return threadId
        #else
        throw NSError(domain: "ChatStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not available"])
        #endif
    }

    // MARK: - Archive/Delete/Mute Operations

    func archiveThread(threadId: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        guard let firestoreRepo = repo as? FirestoreChatRepository else { return }
        do {
            try await firestoreRepo.archiveThread(threadId: threadId, userId: userId)
            // Update local state
            if let index = threads.firstIndex(where: { $0.id == threadId }) {
                threads[index].archivedBy.append(userId)
                rebuildSummaries()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }

    func unarchiveThread(threadId: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        guard let firestoreRepo = repo as? FirestoreChatRepository else { return }
        do {
            try await firestoreRepo.unarchiveThread(threadId: threadId, userId: userId)
            // Update local state
            if let index = threads.firstIndex(where: { $0.id == threadId }) {
                threads[index].archivedBy.removeAll { $0 == userId }
                rebuildSummaries()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }

    func deleteThread(threadId: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        guard let firestoreRepo = repo as? FirestoreChatRepository else { return }
        do {
            try await firestoreRepo.deleteThread(threadId: threadId, userId: userId)
            // Update local state
            if let index = threads.firstIndex(where: { $0.id == threadId }) {
                threads[index].deletedBy.append(userId)
                rebuildSummaries()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }

    func markThreadUnread(threadId: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        guard let firestoreRepo = repo as? FirestoreChatRepository else { return }
        do {
            try await firestoreRepo.setThreadUnread(threadId: threadId, userId: userId, count: 1)
            // Update local state
            if let index = threads.firstIndex(where: { $0.id == threadId }) {
                threads[index].unreadCounts[userId] = 1
                rebuildSummaries()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }

    func muteThread(threadId: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        guard let firestoreRepo = repo as? FirestoreChatRepository else { return }
        do {
            try await firestoreRepo.muteThread(threadId: threadId, userId: userId)
            // Update local state
            if let index = threads.firstIndex(where: { $0.id == threadId }) {
                threads[index].mutedBy.append(userId)
                rebuildSummaries()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }

    func unmuteThread(threadId: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        guard let firestoreRepo = repo as? FirestoreChatRepository else { return }
        do {
            try await firestoreRepo.unmuteThread(threadId: threadId, userId: userId)
            // Update local state
            if let index = threads.firstIndex(where: { $0.id == threadId }) {
                threads[index].mutedBy.removeAll { $0 == userId }
                rebuildSummaries()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }
    
    func hideThread(threadId: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        guard let firestoreRepo = repo as? FirestoreChatRepository else { return }
        do {
            try await firestoreRepo.hideThread(threadId: threadId, userId: userId)
            // Update local state
            if let index = threads.firstIndex(where: { $0.id == threadId }) {
                threads[index].hiddenBy.append(userId)
                rebuildSummaries()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }
    
    func unhideThread(threadId: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        guard let firestoreRepo = repo as? FirestoreChatRepository else { return }
        do {
            try await firestoreRepo.unhideThread(threadId: threadId, userId: userId)
            // Update local state
            if let index = threads.firstIndex(where: { $0.id == threadId }) {
                threads[index].hiddenBy.removeAll { $0 == userId }
                rebuildSummaries()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }
    
    // MARK: - Batch Operations (Selection Mode)
    
    func hideThreads(threadIds: [String], userId: String) async {
        for id in threadIds {
            await hideThread(threadId: id, userId: userId)
        }
    }
    
    func unhideThreads(threadIds: [String], userId: String) async {
        for id in threadIds {
            await unhideThread(threadId: id, userId: userId)
        }
    }
    
    func archiveThreads(threadIds: [String], userId: String) async {
        for id in threadIds {
            await archiveThread(threadId: id, userId: userId)
        }
    }
    
    func unarchiveThreads(threadIds: [String], userId: String) async {
        for id in threadIds {
            await unarchiveThread(threadId: id, userId: userId)
        }
    }
    
    func deleteThreads(threadIds: [String], userId: String) async {
        for id in threadIds {
            await deleteThread(threadId: id, userId: userId)
        }
    }

    // MARK: - Helper Methods

    private func rebuildSummaries() {
        guard let userId = currentUserId else { return }
        processThreads(threads, userId: userId)
    }

    func stopListeningMessages() {
        if let token = messageListener {
            repo.stopListening(token)
            messageListener = nil
        }
        currentMessages = []
    }

    func stopListening() {
        if let tToken = threadListener { repo.stopListening(tToken) }
        if let mToken = messageListener { repo.stopListening(mToken) }
        threadListener = nil
        messageListener = nil
        currentUserId = nil
    }
}
