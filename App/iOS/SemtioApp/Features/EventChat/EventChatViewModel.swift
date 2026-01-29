//
//  EventChatViewModel.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import Combine

@MainActor
final class EventChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let repo: ChatRepositoryProtocol
    private let eventId: String
    private var listener: AnyObject?
    
    init(eventId: String, repo: ChatRepositoryProtocol) {
        self.eventId = eventId
        self.repo = repo
    }
    

    
    func startListening() {
        isLoading = true
        listener = repo.listenMessages(threadId: eventId) { [weak self] msgs in
            Task { @MainActor in
                self?.messages = msgs
                self?.isLoading = false
            }
        }
    }
    
    func stopListening() {
        repo.stopListening(listener)
        listener = nil
    }
    
    func send(senderId: String, senderName: String, text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = ChatMessage(
            id: UUID().uuidString,
            threadId: eventId,
            text: text,
            senderId: senderId,
            createdAt: Date(),
            senderName: senderName
        )
        
        do {
            try await repo.sendMessage(message)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
