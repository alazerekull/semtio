//
//  ProfilePostsPagerView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import AVKit

struct ProfilePostsPagerView: View {
    let posts: [Post]
    @Binding var selectedIndex: Int

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore

    @State private var showCommentsSheet = false
    @State private var activePostForComments: Post?

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                        PostDetailCard(
                            post: post,
                            onCommentsTapped: {
                                activePostForComments = post
                                showCommentsSheet = true
                            }
                        )
                        .containerRelativeFrame(.vertical)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: Binding(
                get: { selectedIndex },
                set: { if let val = $0 { selectedIndex = val } }
            ))
            .background(AppColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(AppFont.calloutBold)
                            .foregroundColor(AppColor.textPrimary)
                    }
                }

                ToolbarItem(placement: .principal) {
                   // Removed Counter
                }
            }
            .sheet(isPresented: $showCommentsSheet) {
                if let post = activePostForComments {
                    PostCommentsSheet(postId: post.id, postOwnerId: post.ownerId)
                }
            }
        }
    }
}

// MARK: - Post Detail Card (single post in pager)

private struct PostDetailCard: View {
    let post: Post
    var onCommentsTapped: (() -> Void)? = nil

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore
    @State private var isSaved = false
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: avatar + name + time
            HStack(spacing: 10) {
                Button {
                    appState.presentUserProfile(userId: post.ownerId)
                } label: {
                    if let avatarURL = post.ownerAvatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                initialsCircle
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    } else {
                        initialsCircle
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.ownerDisplayName ?? post.ownerUsername ?? "Kullanıcı")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColor.textPrimary)

                    if let username = post.ownerUsername {
                        Text("@\(username)")
                            .font(AppFont.caption)
                            .foregroundColor(AppColor.textSecondary)
                    }
                }

                Spacer()

                Text(timeAgo(post.createdAt))
                    .font(AppFont.caption)
                    .foregroundColor(AppColor.textMuted)
                
                if let uid = appState.auth.uid, uid == post.ownerId {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14)) // Match caption size roughly
                            .foregroundColor(AppColor.textSecondary)
                            .padding(.leading, 8)
                            .frame(width: 30, height: 30) // Tappable area
                            .contentShape(Rectangle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Media
            if let firstURL = post.mediaURLs.first, let url = URL(string: firstURL) {
                if post.mediaType == .video {
                    // Smart Video Player
                    SmartVideoPlayer(url: url)
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                } else {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                        } else if phase.error != nil {
                            mediaErrorView
                        } else {
                            ShimmerView()
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }

            // Action Bar
            HStack(spacing: 20) {
                // Like
                Button {
                    Task {
                        if let uid = appState.auth.uid {
                            await appState.postFeed.toggleLike(post: post, uid: uid)
                        }
                    }
                } label: {
                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                        .font(AppFont.title2)
                        .foregroundColor(post.isLiked ? .red : AppColor.textPrimary)
                }

                // Comments
                Button {
                    onCommentsTapped?()
                } label: {
                    Image(systemName: "bubble.right")
                        .font(AppFont.title3)
                        .foregroundColor(AppColor.textPrimary)
                }

                // Share
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "paperplane")
                        .font(AppFont.title3)
                        .foregroundColor(AppColor.textPrimary)
                }

                Spacer()

                // Save
                Button {
                    toggleSave()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(AppFont.title3)
                        .foregroundColor(AppColor.textPrimary)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)

            // Likes count
            if post.likeCount > 0 {
                Text("\(post.likeCount) beğenme")
                    .font(AppFont.footnoteBold)
                    .foregroundColor(AppColor.textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, 4)
            }

            // Caption
            if !post.caption.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Text(post.ownerUsername ?? "")
                        .font(AppFont.footnoteBold)
                    + Text(" \(post.caption)")
                        .font(AppFont.footnote)
                }
                .foregroundColor(AppColor.textPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, 6)
            }

            // Comments count
            if post.commentCount > 0 {
                Button {
                    onCommentsTapped?()
                } label: {
                    Text("\(post.commentCount) yorumun tümünü gör")
                        .font(AppFont.footnote)
                        .foregroundColor(AppColor.textMuted)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, 8)
            }

            Spacer().frame(height: 20)
        }
        .sheet(isPresented: $showShareSheet) {
            PostShareSheet(post: post)
        }
        .task {
            await checkSavedState()
        }
        .alert("Gönderiyi Sil", isPresented: $showDeleteAlert) {
            Button("İptal", role: .cancel) { }
            Button("Sil", role: .destructive) {
                deletePost()
            }
        } message: {
            Text("Bu gönderiyi silmek istediğinden emin misin? Bu işlem geri alınamaz.")
        }
    }
    
    private func deletePost() {
        guard let uid = appState.auth.uid else { return }
        Task {
            do {
                try await appState.postFeed.deletePost(post: post, uid: uid)
                appState.lastDeletedPostId = post.id
                // Post will be removed from list by parent view updating or simple state update
            } catch {
                print("Failed to delete post: \(error)")
            }
        }
    }

    private var initialsCircle: some View {
        Circle()
            .fill(AppColor.primary.opacity(0.2))
            .frame(width: 36, height: 36)
            .overlay(
                Text(String((post.ownerDisplayName ?? "U").prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColor.primary)
            )
    }

    private var videoPlaceholder: some View {
        // Use VideoPlayer for actual playback
        // In a real app, we might want to manage AVPlayer lifecycle more carefully for a pager (play/pause on appear/disappear)
        // But for now, basic VideoPlayer integration.
        // Note: The URL is available in the body where this is called. 
        // We will modify the caller to pass the URL or modify this to accept it.
        // However, to keep it simple with existing structure, I'll return a view that assumes the URL is valid or handle it inline.
        // Actually, looking at the call site: `if let firstURL = post.mediaURLs.first... { videoPlaceholder }`
        // So I can't easily access `url` here without changing signature.
        
        // Better approach: Change the call site to use VideoPlayer directly.
        EmptyView() 
    }

    private var mediaErrorView: some View {
        ZStack {
            AppColor.textSecondary.opacity(0.1)
                .aspectRatio(1, contentMode: .fit)
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundColor(AppColor.textMuted)
                Text("Medya yüklenemedi")
                    .font(AppFont.caption)
                    .foregroundColor(AppColor.textMuted)
            }
        }
    }

    private func toggleSave() {
        guard let uid = appState.auth.uid else { return }
        isSaved.toggle()
        Task {
            do {
                if isSaved {
                    try await appState.posts.savePost(postId: post.id, userId: uid)
                } else {
                    try await appState.posts.unsavePost(postId: post.id, userId: uid)
                }
            } catch {
                isSaved.toggle()
                print("❌ PostDetailCard: Save toggle failed: \(error)")
            }
        }
    }

    private func checkSavedState() async {
        guard let uid = appState.auth.uid else { return }
        do {
            isSaved = try await appState.posts.isPostSaved(postId: post.id, userId: uid)
        } catch {
            print("⚠️ PostDetailCard: Check saved state failed: \(error)")
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let now = Date()
        let diff = now.timeIntervalSince(date)
        if diff < 60 { return "Az önce" }
        if diff < 3600 { return "\(Int(diff / 60))dk" }
        if diff < 86400 { return "\(Int(diff / 3600))sa" }
        if diff < 604800 { return "\(Int(diff / 86400))g" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
}

// MARK: - Smart Video Player

private struct SmartVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    
    var body: some View {
        ZStack {
            Color.black // Background for video
            
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                        isPlaying = true
                    }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            if player == nil {
                let p = AVPlayer(url: url)
                p.preventsDisplaySleepDuringVideoPlayback = false
                p.isMuted = false // Or default to muted?
                player = p
            }
        }
        .onDisappear {
            player?.pause()
            player = nil // Destroy player to free PLAVPlayerView resources
            isPlaying = false
        }
    }
}
