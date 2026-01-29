//
//  PostCardView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import AVKit

struct PostCardView: View {
    let post: Post
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore
    
    @State private var showComments = false
    @State private var showShareSheet = false
    @State private var showReportSheet = false
    
    // Performance: Computed props for subviews
    private var isLiked: Bool { appState.postInteractions.isLiked(post.id) }
    private var isSaved: Bool { userStore.isPostSaved(post.id) }
    
    // Like count logic
    private var likeCount: Int {
        let isLocallyLiked = isLiked
        if isLocallyLiked == post.isLiked {
            return post.likeCount
        } else if isLocallyLiked {
            return post.likeCount + 1
        } else {
            return max(0, post.likeCount - 1)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // 1. Stable Header
            PostHeaderView(
                ownerId: post.ownerId,
                displayName: post.ownerDisplayName ?? post.ownerUsername ?? "Kullanıcı",
                username: post.ownerUsername,
                avatarURL: URL(string: post.ownerAvatarURL ?? ""),
                timeAgo: timeAgo(post.createdAt),
                isOwner: post.ownerId == userStore.currentUser.id,
                onDelete: { appState.postFeed.hidePost(post.id) },
                onBlock: {
                    Task {
                        await userStore.blockUser(post.ownerId)
                        await appState.postFeed.refresh(blockedUserIds: userStore.blockedUserIds)
                    }
                },
                onReport: { showReportSheet = true }
            )
            
            // 2. Stable Media
            // Note: We don't pass 'isLiked' here to avoid re-rendering video when heart is toggled in footer
            if let mediaStr = post.mediaURLs.first, let url = URL(string: mediaStr) {
                PostMediaView(
                    postId: post.id,
                    mediaType: post.mediaType,
                    mediaURL: url,
                    isLiked: false, // Not used for display in media view (only for heart burst logic which is local or callback)
                    onDoubleTap: {
                        if !isLiked { appState.postInteractions.toggleLike(post: post) }
                    },
                    onSingleTap: {
                        if post.mediaType == .video {
                            let coordinator = VideoPlaybackCoordinator.shared
                            if coordinator.currentPlayingURL == url {
                                coordinator.pause(url: url)
                            } else {
                                coordinator.play(url: url)
                            }
                        }
                    }
                )
            }
            
            // 3. Actions & Footer (Dynamic)
            VStack(alignment: .leading, spacing: 10) {
                // Action Bar
                HStack(spacing: 16) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            appState.postInteractions.toggleLike(post: post)
                        }
                    }) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 24))
                            .foregroundColor(isLiked ? .red : .semtioDarkText)
                            .scaleEffect(isLiked ? 1.1 : 1.0)
                    }
                    
                    Button(action: { showComments = true }) {
                        Image(systemName: "message")
                            .font(AppFont.title2)
                            .foregroundColor(.semtioDarkText)
                    }
                    
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "paperplane")
                            .font(AppFont.title2)
                            .foregroundColor(.semtioDarkText)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        Task {
                            await userStore.toggleSave(postId: post.id, authorId: post.ownerId, caption: post.caption, mediaURL: post.mediaURLs.first)
                        }
                    }) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(AppFont.title2)
                            .foregroundColor(isSaved ? .semtioPrimary : .semtioDarkText)
                    }
                }
                
                // Likes & Caption
                if likeCount > 0 {
                    Text("\(likeCount) beğeni")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.semtioDarkText)
                }
                
                if !post.caption.isEmpty {
                    Text("\(Text(post.ownerUsername ?? "user").font(.system(size: 14, weight: .semibold))) \(Text(post.caption).font(.system(size: 14)))")
                        .foregroundColor(.semtioDarkText)
                        .lineLimit(3)
                }
                
                // Comments Link
                if post.commentCount > 0 {
                    Button(action: { showComments = true }) {
                        Text("\(post.commentCount) yorumun tümünü gör")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color.white)
        .confirmationDialog("Şikayet Nedeni", isPresented: $showReportSheet, titleVisibility: .visible) {
            ForEach(ReportReason.allCases) { reason in
                Button(reason.rawValue) {
                    Task { await appState.postFeed.reportPost(post, reason: reason.rawValue) }
                }
            }
            Button("İptal", role: .cancel) { }
        }
        .sheet(isPresented: $showComments) {
            PostCommentsSheet(postId: post.id, postOwnerId: post.ownerId)
                .environmentObject(appState)
                .environmentObject(userStore)
        }
        .sheet(isPresented: $showShareSheet) {
            PostShareSheet(post: post)
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}



