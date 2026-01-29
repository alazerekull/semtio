//
//  EventChatScreen.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import PhotosUI

struct EventChatScreen: View {
    let event: Event
    @StateObject private var viewModel: EventChatViewModel
    @EnvironmentObject var userStore: UserStore
    
    init(event: Event, repo: ChatRepositoryProtocol) {
        self.event = event
        _viewModel = StateObject(wrappedValue: EventChatViewModel(eventId: event.id, repo: repo))
    }
    
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isSendingImage = false
    @State private var isCameraPresented = false
    @State private var cameraImage: UIImage? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message, isCurrentUser: message.senderId == userStore.currentUser.id)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChangeCompatible(of: viewModel.messages) { _ in
                    if let last = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            ChatComposerView(
                messageText: $messageText,
                isInputFocused: _isInputFocused,
                isSendingImage: isSendingImage,
                selectedItem: $selectedItem,
                isCameraPresented: $isCameraPresented
            ) {
                // On Send
                let text = messageText
                Task {
                    await viewModel.send(
                        senderId: userStore.currentUser.id,
                        senderName: userStore.currentUser.fullName.isEmpty ? "User" : userStore.currentUser.fullName,
                        text: text
                    )
                }
                messageText = ""
            }
            .disabled(viewModel.isLoading)
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraPicker(selectedImage: $cameraImage)
                .ignoresSafeArea()
        }
        // TODO: Handle Image Sending logic for Event Chat if supported by backend/repo
        // For now, these bindings allow the UI to compile, but actual image upload needs 
        // EventChatViewModel support or direct repo access similar to ChatScreen.
    }
}


