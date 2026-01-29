//
//  ChatViewModel.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let repo: ChatRepository
    private let chatId: String
    private var listener: AnyObject?
    
    init(chatId: String, repo: ChatRepository) {
        self.chatId = chatId
        self.repo = repo
    }
    

    
    func start() {
        isLoading = true
        listener = repo.listenChatMessages(chatId: chatId) { [weak self] msgs in
            Task { @MainActor in
                self?.messages = msgs
                self?.isLoading = false
            }
        } onError: { [weak self] err in
            Task { @MainActor in
                self?.errorMessage = err.localizedDescription
                self?.isLoading = false
            }
        }
    }
    
    func stop() {
        repo.stopListening(listener)
        listener = nil
    }
    
    func send(senderId: String, senderName: String, text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try await repo.sendChatMessage(chatId: chatId, senderId: senderId, senderName: senderName, text: text)
        } catch {
            let nsError = error as NSError
            // Check for Firestore permission denied (Code 7)
            if nsError.domain == FirestoreErrorDomain && nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
                errorMessage = "Bu kullanıcıyla mesajlaşamazsın."
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}
