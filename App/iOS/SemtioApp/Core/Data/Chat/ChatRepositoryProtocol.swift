//
//  ChatRepositoryProtocol.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

protocol ChatRepositoryProtocol {
    // Threads
    func fetchThreads(forUserId userId: String) async throws -> [ChatThread]
    func createOrGetDMThread(uidA: String, uidB: String) async throws -> ChatThread
    func createOrGetEventThread(eventId: String, title: String, participants: [String]) async throws -> ChatThread
    func createGroupThread(name: String, participantIds: [String], creatorId: String, photoURL: String?) async throws -> String
    
    // Messages
    func fetchMessages(threadId: String, limit: Int) async throws -> [ChatMessage]
    func sendMessage(_ message: ChatMessage) async throws
    
    // Unread counts
    func markThreadRead(threadId: String, userId: String) async throws
    
    // Mutable thread actions
    func muteThread(threadId: String, userId: String) async throws
    func unmuteThread(threadId: String, userId: String) async throws
    func hideThread(threadId: String, userId: String) async throws
    func unhideThread(threadId: String, userId: String) async throws
    
    func archiveThread(threadId: String, userId: String) async throws
    func unarchiveThread(threadId: String, userId: String) async throws
    func deleteThread(threadId: String, userId: String) async throws
    func hardDeleteThread(threadId: String, userId: String) async throws

    func setThreadUnread(threadId: String, userId: String, count: Int) async throws
    
    // Real-time
    func listenThreads(userId: String, onChange: @escaping ([ChatThread]) -> Void, onError: @escaping (Error) -> Void) -> AnyObject?
    func listenMessages(threadId: String, onChange: @escaping ([ChatMessage]) -> Void) -> AnyObject?
    func stopListening(_ token: AnyObject?)
    
    // Legacy support (optional, can stub)
    func createThread(participants: [String], type: ChatType) async throws -> ChatThread
}
