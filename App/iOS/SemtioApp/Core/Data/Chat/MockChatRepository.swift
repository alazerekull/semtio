//
//  MockChatRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

class MockChatRepository: ChatRepositoryProtocol {
    
    private var threads: [ChatThread] = []
    private var messages: [String: [ChatMessage]] = [:] // threadId -> messages
    
    init() {
        // Seed Data with unread counts
        let t1 = ChatThread(
            id: "thread1",
            type: .dm,
            participants: ["current_user", "user2"],
            lastMessage: ChatMessage(
                id: "m1",
                threadId: "thread1",
                text: "Merhaba!",
                senderId: "user2",
                createdAt: Date()
            ),
            updatedAt: Date(),
            title: nil,
            unreadCounts: ["current_user": 2, "user2": 0]
        )
        
        let t2 = ChatThread(
            id: "thread2",
            type: .event,
            participants: ["current_user", "user3", "user4"],
            lastMessage: ChatMessage(
                id: "m2",
                threadId: "thread2",
                text: "Etkinlik yarın mı?",
                senderId: "user3",
                createdAt: Date().addingTimeInterval(-3600)
            ),
            updatedAt: Date().addingTimeInterval(-3600),
            title: "Yoga Grubu",
            unreadCounts: ["current_user": 1, "user3": 0, "user4": 0]
        )
        threads = [t1, t2]
        
        messages["thread1"] = [
            ChatMessage(id: "m1", threadId: "thread1", text: "Merhaba!", senderId: "user2", createdAt: Date())
        ]
        
        messages["thread2"] = [
            ChatMessage(id: "m2", threadId: "thread2", text: "Etkinlik yarın mı?", senderId: "user3", createdAt: Date().addingTimeInterval(-3600))
        ]
    }
    
    func fetchThreads(forUserId userId: String) async throws -> [ChatThread] {
        return threads
    }
    
    func createThread(participants: [String], type: ChatType) async throws -> ChatThread {
        // Initialize unread counts to 0 for all participants
        var unreadCounts: [String: Int] = [:]
        for uid in participants {
            unreadCounts[uid] = 0
        }
        
        let newThread = ChatThread(
            id: UUID().uuidString,
            type: type,
            participants: participants,
            lastMessage: nil,
            updatedAt: Date(),
            title: type == .event ? "Yeni Grup" : nil,
            unreadCounts: unreadCounts
        )
        threads.insert(newThread, at: 0)
        return newThread
    }
    
    func createOrGetDMThread(uidA: String, uidB: String) async throws -> ChatThread {
        // Deterministic ID for DM (sorted)
        let threadId = [uidA, uidB].sorted().joined(separator: "_")
        
        // Check existing
        if let existing = threads.first(where: { $0.id == threadId }) {
            return existing
        }
        
        // Create new
        return try await createThread(participants: [uidA, uidB], type: .dm)
    }
    
    func createOrGetEventThread(eventId: String, title: String, participants: [String]) async throws -> ChatThread {
        let threadId = "event_\(eventId)"
        
        // Check existing
        if let existing = threads.first(where: { $0.id == threadId }) {
            return existing
        }
        
        // Initialize unread counts to 0 for all participants
        var unreadCounts: [String: Int] = [:]
        for uid in participants {
            unreadCounts[uid] = 0
        }
        
        let newThread = ChatThread(
            id: threadId,
            type: .event,
            participants: participants,
            lastMessage: nil,
            updatedAt: Date(),
            title: title,
            unreadCounts: unreadCounts
        )
        threads.insert(newThread, at: 0)
        return newThread
    }
    
    func createGroupThread(name: String, participantIds: [String], creatorId: String, photoURL: String?) async throws -> String {
        let threadId = UUID().uuidString
        var unreadCounts: [String: Int] = [:]
        for uid in participantIds {
            unreadCounts[uid] = 0
        }
        
        let newThread = ChatThread(
             id: threadId,
             type: .group,
             participants: participantIds,
             lastMessage: nil,
             updatedAt: Date(),
             title: name,
             unreadCounts: unreadCounts
         )
         threads.insert(newThread, at: 0)
         return threadId
    }
    
    func fetchMessages(threadId: String, limit: Int) async throws -> [ChatMessage] {
        return messages[threadId] ?? []
    }
    
    func sendMessage(_ message: ChatMessage) async throws {
        var msgs = messages[message.threadId] ?? []
        msgs.append(message)
        messages[message.threadId] = msgs
        
        // Update thread
        if let index = threads.firstIndex(where: { $0.id == message.threadId }) {
            threads[index].lastMessage = message
            threads[index].updatedAt = message.createdAt
            
            // Increment unread for all participants except sender
            for uid in threads[index].participants where uid != message.senderId {
                threads[index].unreadCounts[uid, default: 0] += 1
            }
        }
    }
    
    func markThreadRead(threadId: String, userId: String) async throws {
        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            threads[index].unreadCounts[userId] = 0
        }
    }
    
    func listenThreads(userId: String, onChange: @escaping ([ChatThread]) -> Void, onError: @escaping (Error) -> Void) -> AnyObject? {
        onChange(threads)
        return NSObject()
    }
    
    func listenMessages(threadId: String, onChange: @escaping ([ChatMessage]) -> Void) -> AnyObject? {
        onChange(messages[threadId] ?? [])
        return NSObject()
    }
    
    func stopListening(_ token: AnyObject?) {}
    
    // Mute
    func muteThread(threadId: String, userId: String) async throws {
        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            threads[index].mutedBy.append(userId)
        }
    }
    
    func unmuteThread(threadId: String, userId: String) async throws {
        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            threads[index].mutedBy.removeAll { $0 == userId }
        }
    }
    
    // Hidden
    func hideThread(threadId: String, userId: String) async throws {
        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            threads[index].hiddenBy.append(userId)
        }
    }
    
    func unhideThread(threadId: String, userId: String) async throws {
        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            threads[index].hiddenBy.removeAll { $0 == userId }
        }
    }
    
    func archiveThread(threadId: String, userId: String) async throws {
        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            threads[index].archivedBy.append(userId)
        }
    }
    
    func unarchiveThread(threadId: String, userId: String) async throws {
        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            threads[index].archivedBy.removeAll { $0 == userId }
        }
    }
    
    func deleteThread(threadId: String, userId: String) async throws {
        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            threads[index].deletedBy.append(userId)
        }
    }

    func hardDeleteThread(threadId: String, userId: String) async throws {
        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            threads.remove(at: index)
            messages.removeValue(forKey: threadId)
        }
    }
    
    func setThreadUnread(threadId: String, userId: String, count: Int) async throws {
        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            threads[index].unreadCounts[userId] = count
        }
    }
}
