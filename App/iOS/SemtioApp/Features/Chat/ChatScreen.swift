//
//  ChatScreen.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import PhotosUI

struct ChatScreen: View {
    let threadId: String
    @State private var thread: ChatThread?
    @State private var isLoading = true
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var chatStore: ChatStore
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var friendStore: FriendStore
    
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isSendingImage = false
    @State private var isCameraPresented = false
    @State private var cameraImage: UIImage? = nil
    
    var resolvedTitle: String {
        guard let thread = thread else { return "Sohbet" }
        
        // 1. Group/Event Title
        if thread.type == .event, let title = thread.title {
            return title
        }
        
        // 2. DM: Resolve Friend Name
        if thread.type == .dm {
            let currentUid = userStore.currentUser.id
            if let otherId = thread.participants.first(where: { $0 != currentUid }) {
                // Try FriendStore first
                if let friend = friendStore.friends.first(where: { $0.id == otherId }) {
                    return friend.displayName
                }
                return "Kullanıcı"
            }
        }
        
        return thread.title ?? "Sohbet"
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let thread = thread {
                VStack(spacing: 0) {
                    MessageListView(
                        messages: chatStore.currentMessages,
                        currentUserId: userStore.currentUser.id
                    )
                    
                    ChatComposerView(
                        messageText: $messageText,
                        isInputFocused: _isInputFocused,
                        isSendingImage: isSendingImage,
                        selectedItem: $selectedItem,
                        isCameraPresented: $isCameraPresented,
                        onSend: { sendMessage(threadId: thread.id) }
                    )
                }
                .background(Color.semtioBackground)
                .navigationTitle(resolvedTitle)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Text("Sohbet bulunamadı")
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.semtioPrimary)
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            appState.isTabBarHidden = true
            loadThread()
        }
        .onDisappear {
            appState.isTabBarHidden = false
            chatStore.stopListeningMessages()
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem = newItem else { return }
            
            Task {
                isSendingImage = true
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await chatStore.sendImage(
                        threadId: threadId,
                        imageData: data,
                        senderId: userStore.currentUser.id
                    )
                }
                selectedItem = nil
                isSendingImage = false
            }
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraPicker(selectedImage: $cameraImage)
                .ignoresSafeArea()
        }
        .onChange(of: cameraImage) { _, newImage in
            guard let image = newImage else { return }
            
            Task {
                isSendingImage = true
                if let data = StorageService.shared.compressImage(image) {
                   await chatStore.sendImage(
                        threadId: threadId,
                        imageData: data,
                        senderId: userStore.currentUser.id
                    )
                }
                cameraImage = nil
                isSendingImage = false
            }
        }
    }
    
    private func loadThread() {
        if let existing = chatStore.threads.first(where: { $0.id == threadId }) {
            self.thread = existing
            self.isLoading = false
            chatStore.openThread(threadId)
        } else {
            self.isLoading = false
            chatStore.openThread(threadId)
        }
    }
    
    private func sendMessage(threadId: String) {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        
        Task {
            await chatStore.sendMessage(
                threadId: threadId,
                text: text,
                senderId: userStore.currentUser.id
            )
        }
        
        messageText = ""
    }
}

// MARK: - Subviews

struct MessageListView: View {
    let messages: [ChatMessage]
    let currentUserId: String
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        MessageBubble(
                            message: message,
                            isCurrentUser: message.senderId == currentUserId
                        )
                        .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                if let lastId = messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastId = messages.last?.id {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }
}


