//
//  ChatRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

protocol ChatRepository {
    // MARK: - Direct Messages (DM)
    func listenChats(for userId: String,
                     onChange: @escaping ([ChatRoom]) -> Void,
                     onError: @escaping (Error) -> Void) -> AnyObject?
                     
    func listenChatMessages(chatId: String,
                            onChange: @escaping ([ChatMessage]) -> Void,
                            onError: @escaping (Error) -> Void) -> AnyObject?
                            
    func sendChatMessage(chatId: String,
                         senderId: String,
                         senderName: String,
                         text: String) async throws
                         
    func createChat(participants: [String]) async throws -> String
    
    // MARK: - Event Chat
    func listenEventMessages(eventId: String,
                             onChange: @escaping ([ChatMessage]) -> Void,
                             onError: @escaping (Error) -> Void) -> AnyObject?
    
    func sendEventMessage(eventId: String,
                          senderId: String,
                          senderName: String,
                          text: String) async throws
                          
    // Common
    func stopListening(_ token: AnyObject?)
}
