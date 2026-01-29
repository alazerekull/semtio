//
//  SupportChatScreen.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct SupportChatScreen: View {
    @EnvironmentObject var chatStore: ChatStore
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    
    // Dynamic Tab Bar Height from Environment (Real measurement)
    @Environment(\.tabBarHeight) private var tabBarHeight
    
    @State private var threadId: String?
    @State private var messageText = ""
    @State private var state: ViewState = .loading
    @State private var isSending = false
    @State private var sendError: String?
    
    enum ViewState {
        case loading
        case ready(String) // threadId
        case failed(String) // errorMessage
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            switch state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            case .ready(_):
                // Messages List (ScrollView)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Empty State
                            if chatStore.currentMessages.isEmpty {
                                emptyStateView
                                    .padding(.top, 60)
                            }
                            
                            ForEach(chatStore.currentMessages) { message in
                                SupportMessageBubble(
                                    message: message,
                                    isCurrentUser: message.senderId == auth.uid
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        // Add padding for tab bar so last message isn't hidden
                        .padding(.bottom, tabBarHeight > 0 ? tabBarHeight : 88) // Fallback if 0
                    }
                    // Input Bar (Pinned via safeAreaInset)
                    .safeAreaInset(edge: .bottom) {
                        inputBar
                    }
                    // Keyboard Handling
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    
                    // Auto-scroll logic
                    .onChange(of: chatStore.currentMessages) { _, newMessages in
                        if let last = newMessages.last {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: messageText) { _, _ in
                         // Scroll to bottom when typing starts (keyboard appears)
                         if let last = chatStore.currentMessages.last {
                             withAnimation {
                                 proxy.scrollTo(last.id, anchor: .bottom)
                             }
                         }
                    }
                    .onAppear {
                        if let last = chatStore.currentMessages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                
            case .failed(let errorMessage):
                // Fallback / Error
                errorView(message: errorMessage)
            }
        }
        .background(AppColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Destek")
                        .font(AppFont.headline)
                        .foregroundColor(AppColor.textPrimary)
                    Text("Genelde birkaç saat içinde dönüş yaparız")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(AppColor.textSecondary)
                }
            }
        }
        .toolbar(.hidden, for: .tabBar) // Hides system tab bar, but handles custom via padding
        .task {
            await initializeSupportChat()
        }
        .onDisappear {
            chatStore.stopListeningMessages()
        }
    }
    
    // MARK: - Components
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.blue.opacity(0.8))
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            Text("Bize mesaj bırakın")
                .font(.headline)
                .foregroundColor(AppColor.textPrimary)
            
            Text("Sorularınızı ve geri bildirimlerinizi bekliyoruz. Ekibimiz en kısa sürede size dönüş yapacaktır.")
                .font(.subheadline)
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 12) {
                // Text Field
                TextField("Mesaj yaz...", text: $messageText, axis: .vertical)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(22)
                    .lineLimit(1...5)
                    .font(AppFont.callout)
                
                // Send Button
                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(canSend ? Color.blue : Color(.systemGray5))
                            .frame(width: 44, height: 44)
                        
                        if isSending {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(AppFont.title3)
                                .foregroundColor(canSend ? .white : .gray)
                        }
                    }
                }
                .disabled(!canSend || isSending)
                .animation(.easeInOut(duration: 0.2), value: canSend)
            }
            .padding(12)
            .background(Color(.systemBackground))
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            Text("Sohbet başlatılamadı.")
                .font(.headline)
            Text("Lütfen daha sonra tekrar deneyin.")
                .font(.subheadline)
                .foregroundColor(AppColor.textSecondary)
            
            #if DEBUG
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .padding()
            #endif
            
            Button("Tekrar Dene") {
                Task { await initializeSupportChat() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Logic
    
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func initializeSupportChat() async {
        guard let uid = auth.uid else { 
            state = .failed("Kullanıcı oturumu bulunamadı.")
            return 
        }
        
        // Use existing state if ready
        if case .ready = state { return }
        
        state = .loading
        
        do {
            print("🚀 initializeSupportChat: Starting for \(uid)")
            // 1. Get or Create
            let tId = try await chatStore.getOrCreateSupportThread(for: uid)
            print("✅ initializeSupportChat: Got threadId: \(tId)")
            
            // 2. Open Thread
            self.threadId = tId
            chatStore.openThread(tId)
            
            withAnimation {
                state = .ready(tId)
            }
        
        } catch {
            print("❌ Support chat init error: \(error)")
            withAnimation {
                state = .failed(error.localizedDescription)
            }
        }
    }
    
    private func sendMessage() {
        guard case .ready(let tId) = state, let uid = auth.uid, canSend else { return }
        
        let textToSend = messageText
        messageText = "" // Immediate clear for UX
        isSending = true
        
        Task {
            print("📤 Sending message to \(tId) for \(uid)")
            await chatStore.sendMessage(threadId: tId, text: textToSend, senderId: uid)
            
            if let error = chatStore.errorMessage {
                print("❌ Send error: \(error)")
                sendError = error
            } else {
                print("✅ Message sent successfully")
            }
            isSending = false
        }
    }
}

// MARK: - Message Bubble Component

fileprivate struct SupportMessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    
    // Colors
    private var userColor: Color { .blue }
    private var supportColor: Color { Color(.secondarySystemBackground) }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            
            // Support Icon (Left)
            if !isCurrentUser {
                Image(systemName: "headphones.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
                    .offset(y: -4) 
            } else {
                Spacer(minLength: 40) // Max width constraint
            }
            
            // Bubble content
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(AppFont.callout)
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(isCurrentUser ? userColor : supportColor)
                    .clipShape(BubbleShape(isCurrentUser: isCurrentUser))
            }
            if isCurrentUser {
                // No icon on right
            } else {
                Spacer(minLength: 40)
            }
        }
    }
}

// Custom Shape for nuanced corners
fileprivate struct BubbleShape: Shape {
    let isCurrentUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let corners: UIRectCorner = isCurrentUser
            ? [.topLeft, .topRight, .bottomLeft]
            : [.topLeft, .topRight, .bottomRight]
            
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
