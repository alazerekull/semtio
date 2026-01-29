//
//  StoryViewerScreen.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import AVKit

struct StoryViewerScreen: View {
    let bundle: StoryStore.UserStoryBundle
    @EnvironmentObject var appState: AppState // To mark as viewed
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var chatStore: ChatStore
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var storyStore: StoryStore
    
    @State private var currentIndex = 0
    @State private var progress: CGFloat = 0.0
    @State private var timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    // Gestures & Focus
    @State private var isPaused = false
    @State private var replyText = ""
    @FocusState private var isInputFocused: Bool
    
    // Sheets & Dialogs
    @State private var showViewersSheet = false
    @State private var showMoreActionSheet = false
    @State private var showDeleteConfirmation = false
    
    var currentStory: Story {
        if currentIndex < bundle.stories.count {
            return bundle.stories[currentIndex]
        }
        return bundle.stories.last! // Fallback
    }
    
    var isOwner: Bool {
        return bundle.user.id == userStore.currentUser.id
    }
    
    let storyDuration: Double = 5.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 1. Story Content
            StoryContent(story: currentStory, isPaused: isPaused)
                .onTapGesture { locations in
                    guard !isInputFocused else {
                        isInputFocused = false
                        return
                    }
                    
                    let screenWidth = UIScreen.main.bounds.width
                    if locations.x < screenWidth * 0.3 {
                        prev()
                    } else {
                        next()
                    }
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.2)
                        .onEnded { _ in isPaused = false }
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { _ in isPaused = true }
                        .onEnded { _ in isPaused = false }
                )
                // Swipe Gestures
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height > 100 {
                                // Swipe Down -> Close
                                dismiss()
                            } else if value.translation.height < -100 {
                                // Swipe Up
                                if isOwner {
                                    showViewersSheet = true
                                    isPaused = true
                                } else {
                                    // Viewer Swipe Up logic (e.g., link)
                                    // For now, maybe focus input?
                                    // isInputFocused = true
                                }
                            }
                        }
                )
            
            // 2. Event Sticker Overlay (If context exists)
            if case .event(let id, let name, let date, _) = currentStory.context {
                VStack {
                    Spacer()
                    EventContextCard(
                         eventId: id,
                         name: name,
                         date: date
                    )
                    .onTapGesture {
                        isPaused = true
                        appState.handleDeepLink(URL(string: "semtio://event/\(id)")!)
                        dismiss()
                    }
                    .padding(.bottom, 150) // Adjust for bottom bar
                }
            }
            
            // 3. UI Overlays
            VStack(spacing: 0) {
                // Top Progress & Header
                ZStack(alignment: .top) {
                    LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 100)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        StoryProgressView(
                            storiesCount: bundle.stories.count,
                            currentIndex: currentIndex,
                            currentProgress: progress
                        )
                        
                        StoryHeaderView(
                            user: bundle.user,
                            date: currentStory.createdAt,
                            onClose: { dismiss() },
                            onMore: {
                                isPaused = true
                                showMoreActionSheet = true
                            }
                        )
                    }
                    .padding(.top, 40) // Safe Area approximation or use Geometry
                }
                
                Spacer()
                
                // Caption
                 if !currentStory.caption.isEmpty {
                     Text(currentStory.caption)
                         .font(.body)
                         .foregroundColor(.white)
                         .multilineTextAlignment(.center)
                         .padding(10)
                         .background(Color.black.opacity(0.4))
                         .cornerRadius(8)
                         .padding(.bottom, 20)
                 }
                
                // Bottom Bar
                if isOwner {
                    StoryOwnerBottomBar(
                        viewCount: currentStory.viewCount,
                        onSwipeUp: {
                            isPaused = true
                            showViewersSheet = true
                        },
                        onDelete: {
                            isPaused = true
                            showDeleteConfirmation = true
                        },
                        onHighlight: {
                            // TODO: Add to Highlights
                        },
                        onMore: {
                            isPaused = true
                            showMoreActionSheet = true
                        }
                    )
                } else {
                    StoryViewerBottomBar(
                        text: $replyText,
                        isFocused: $isInputFocused,
                        onSend: sendMessage,
                        onLike: {
                            // TODO: Like Interaction
                            sendReaction("❤️")
                        },
                        onShare: {
                            // TODO: Share Sheet
                        },
                        onReaction: { emoji in
                            sendReaction(emoji)
                        }
                    )
                }
            }
        }
        .onReceive(timer) { _ in
            guard !isPaused && !isInputFocused && !showViewersSheet else { return }
            
            let step = 0.05 / storyDuration
            if progress < 1.0 {
                progress += step
            } else {
                next()
            }
        }
        .onAppear {
             markAsViewed()
        }
        .onChange(of: currentIndex) { _, _ in
            progress = 0
            markAsViewed()
        }
        .onChange(of: isInputFocused) { focused, _ in
            isPaused = focused
        }
        .sheet(isPresented: $showViewersSheet, onDismiss: { isPaused = false }) {
            StoryViewersSheet(story: currentStory)
        }
        .confirmationDialog("Seçenekler", isPresented: $showMoreActionSheet) {
            if isOwner {
                Button("Hikayeyi Sil", role: .destructive) {
                    showDeleteConfirmation = true
                }
                Button("Kaydet") {
                    // Save logic
                }
            } else {
                Button("Bu hikayeyi şikayet et", role: .destructive) { }
                Button("Sessize Al") { }
            }
            Button("Vazgeç", role: .cancel) { isPaused = false }
        }
        .alert("Hikayeyi Sil", isPresented: $showDeleteConfirmation) {
            Button("Sil", role: .destructive) {
                deleteStory()
            }
            Button("Vazgeç", role: .cancel) { isPaused = false }
        } message: {
            Text("Bu hikayeyi kalıcı olarak silmek istediğinizden emin misiniz?")
        }
    }
    
    // MARK: - Actions
    
    func next() {
        if currentIndex < bundle.stories.count - 1 {
            currentIndex += 1
            progress = 0
        } else {
            dismiss()
        }
    }
    
    func prev() {
        if currentIndex > 0 {
            currentIndex -= 1
            progress = 0 
        } else {
            progress = 0
        }
    }
    
    func markAsViewed() {
        appState.stories.markAsViewed(storyId: currentStory.id)
    }
    
    func sendMessage() {
        guard !replyText.isEmpty else { return }
        let text = replyText // Capture
        let story = currentStory
        let storyOwner = bundle.user

        Task {
            do {
                let thread = try await chatStore.getOrCreateDMThread(
                    currentUserId: userStore.currentUser.id,
                    otherUserId: storyOwner.id
                )

                // Send story reply message with metadata
                await chatStore.sendStoryReply(
                    threadId: thread.id,
                    text: text,
                    senderId: userStore.currentUser.id,
                    story: story,
                    storyOwner: storyOwner
                )

                // Send notification to story owner
                await sendStoryNotification(
                    type: .storyReply,
                    toUserId: storyOwner.id,
                    storyId: story.id,
                    messageText: text
                )

                await MainActor.run {
                    replyText = ""
                    isInputFocused = false
                    isPaused = false
                }
            } catch {
                print("Failed to send reply: \(error)")
            }
        }
    }

    func sendReaction(_ emoji: String) {
        let story = currentStory
        let storyOwner = bundle.user

        Task {
            do {
                let thread = try await chatStore.getOrCreateDMThread(
                    currentUserId: userStore.currentUser.id,
                    otherUserId: storyOwner.id
                )

                // Send story reaction message with metadata
                await chatStore.sendStoryReaction(
                    threadId: thread.id,
                    emoji: emoji,
                    senderId: userStore.currentUser.id,
                    story: story,
                    storyOwner: storyOwner
                )

                // Send notification to story owner
                await sendStoryNotification(
                    type: emoji == "❤️" ? .storyLike : .storyReaction,
                    toUserId: storyOwner.id,
                    storyId: story.id,
                    reactionEmoji: emoji
                )
            } catch {
                print("Failed to send reaction: \(error)")
            }
        }
    }

    private func sendStoryNotification(
        type: AppNotification.NotificationType,
        toUserId: String,
        storyId: String,
        messageText: String? = nil,
        reactionEmoji: String? = nil
    ) async {
        // Don't send notification to yourself
        guard toUserId != userStore.currentUser.id else { return }

        let currentUser = userStore.currentUser
        let title: String
        let body: String

        switch type {
        case .storyReply:
            title = "\(currentUser.fullName) hikayene yanıt verdi"
            body = messageText ?? ""
        case .storyReaction:
            title = "\(currentUser.fullName) hikayene tepki verdi"
            body = reactionEmoji ?? "😊"
        case .storyLike:
            title = "\(currentUser.fullName) hikayeni beğendi"
            body = "❤️"
        default:
            return
        }

        let notification = AppNotification(
            id: UUID().uuidString,
            userId: toUserId,
            type: type,
            title: title,
            body: body,
            fromUserId: currentUser.id,
            fromUserName: currentUser.fullName,
            fromUserAvatar: currentUser.avatarURL,
            storyId: storyId,
            storyThumbURL: currentStory.thumbURL,
            reactionEmoji: reactionEmoji
        )

        await appState.notifications.sendNotification(notification)
    }
    
    func deleteStory() {
        let id = currentStory.id
        Task {
            // Optimistically dismiss or wait?
            // User expects "Immediate" deletion feel.
            await storyStore.deleteStory(storyId: id)
            await MainActor.run {
                dismiss()
            }
        }
    }
}

