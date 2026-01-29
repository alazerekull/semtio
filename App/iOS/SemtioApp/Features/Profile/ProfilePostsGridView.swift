//
//  ProfilePostsGridView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Modern posts grid with shimmer loading, staggered appearance animations, and refined thumbnails

import SwiftUI

struct ProfilePostsGridView: View {
    let userId: String

    @StateObject private var store: ProfilePostStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore
    @State private var showCreatePost = false
    @State private var showPostPager = false
    @State private var selectedPostIndex = 0

    init(userId: String, repo: PostRepositoryProtocol) {
        self.userId = userId
        _store = StateObject(wrappedValue: ProfilePostStore(repo: repo))
    }

    var isOwnProfile: Bool {
        userId == userStore.currentUser.id
    }

    private let columns = [
        GridItem(.flexible(), spacing: 1.5),
        GridItem(.flexible(), spacing: 1.5),
        GridItem(.flexible(), spacing: 1.5)
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if store.isLoading && store.posts.isEmpty {
                    shimmerGrid
                } else if store.posts.isEmpty {
                    emptyState
                } else {
                    postsGrid
                }
            }
            
            // Floating Action Button removed as per request
        }
        .task {
            await store.loadInitial(userId: userId)
        }
        .onChange(of: appState.lastDeletedPostId) { _, postId in
            if let postId = postId {
                store.removePost(id: postId)
            }
        }
        .onChange(of: appState.postsChanged) { _, changed in
            if changed {
                Task {
                    await store.loadInitial(userId: userId)
                    appState.postsChanged = false
                }
            }
        }
        .sheet(isPresented: $showCreatePost, onDismiss: {
            Task { await store.loadInitial(userId: userId) }
        }) {
            CreatePostScreen()
        }
    }

    // MARK: - Shimmer Loading Grid

    private var shimmerGrid: some View {
        LazyVGrid(columns: columns, spacing: 1.5) {
            ForEach(0..<9, id: \.self) { index in
                ShimmerView()
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(.horizontal, 1.5)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        if isOwnProfile {
            VStack(spacing: Spacing.md) {
                EmptyStateView(
                     iconName: "plus.app", // More generic creation icon
                     title: "İlk gönderini oluştur",
                     subtitle: "Bu alanı kendine özel hale getir.",
                     actionTitle: "Oluştur",
                     action: {
                         showCreatePost = true
                     }
                 )
            }
            .padding(.top, Spacing.xl)
        } else {
            VStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(AppColor.primary.opacity(0.08))
                        .frame(width: 80, height: 80)
                    Image(systemName: "camera")
                        .font(AppFont.largeTitle)
                        .foregroundColor(AppColor.textMuted)
                }
                Text("Henüz paylaşım yok")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(AppColor.textMuted)
            }
            .padding(.top, 50)
        }
    }

    // MARK: - Posts Grid

    private var postsGrid: some View {
        LazyVGrid(columns: columns, spacing: 1.5) {
            ForEach(Array(store.posts.enumerated()), id: \.element.id) { index, post in
                Button(action: {
                    selectedPostIndex = index
                    showPostPager = true
                }) {
                    PostThumbnailView(post: post, index: index)
                }
                .buttonStyle(ScaleButtonStyle())
                .onAppear {
                    if post == store.posts.last {
                        Task { await store.loadMore() }
                    }
                }
            }
        }
        .padding(.horizontal, 1.5)
        .fullScreenCover(isPresented: $showPostPager) {
            ProfilePostsPagerView(
                posts: store.posts,
                selectedIndex: $selectedPostIndex
            )
        }
    }
}

// MARK: - Post Thumbnail View

struct PostThumbnailView: View {
    let post: Post
    var index: Int = 0

    @State private var isAppeared = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let thumbnailURL = post.thumbnailURL, !thumbnailURL.isEmpty, let url = URL(string: thumbnailURL) {
                    // Always prefer thumbnail if available (works for video & image)
                    if url.scheme == "mock" {
                        ZStack {
                            AppColor.textSecondary.opacity(0.2)
                            Image(systemName: "photo")
                                .font(AppFont.title3)
                                .foregroundColor(AppColor.textMuted)
                        }
                    } else {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                ZStack {
                                    AppColor.textSecondary.opacity(0.15)
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(AppColor.textMuted)
                                }
                            } else {
                                ShimmerView()
                            }
                        }
                    }
                } else if let firstMedia = post.mediaURLs.first, let url = URL(string: firstMedia), post.mediaType == .image {
                    // Fallback to first media only if it is an image
                    if url.scheme == "mock" {
                        ZStack {
                            AppColor.textSecondary.opacity(0.2)
                            Image(systemName: "photo")
                                .font(AppFont.title3)
                                .foregroundColor(AppColor.textMuted)
                        }
                    } else {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                ZStack {
                                    AppColor.textSecondary.opacity(0.15)
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(AppColor.textMuted)
                                }
                            } else {
                                ShimmerView()
                            }
                        }
                    }
                } else {
                    // No valid image/thumbnail to show
                    ZStack {
                        AppColor.textSecondary.opacity(0.15)
                        Image(systemName: post.mediaType == .video ? "video.fill" : "photo")
                            .font(AppFont.title3)
                            .foregroundColor(AppColor.textMuted)
                    }
                }

                // Multi-image indicator
                if post.mediaURLs.count > 1 {
                    indicatorOverlay(icon: "square.fill.on.square.fill")
                }
                
                // Video indicator
                if post.mediaType == .video {
                    indicatorOverlay(icon: "play.fill", alignment: .bottomLeading)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .opacity(isAppeared ? 1.0 : 0)
        .scaleEffect(isAppeared ? 1.0 : 0.92)
        .onAppear {
            let delay = Double(index % 9) * 0.04
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay)) {
                isAppeared = true
            }
        }
    }

    private func indicatorOverlay(icon: String, alignment: Alignment = .topTrailing) -> some View {
        VStack {
            if alignment == .bottomTrailing || alignment == .bottomLeading { Spacer() }
            HStack {
                if alignment == .topTrailing || alignment == .bottomTrailing { Spacer() }
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColor.onPrimary)
                    .padding(5)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
                    .padding(6)
                if alignment == .topLeading || alignment == .bottomLeading { Spacer() }
            }
            if alignment == .topTrailing || alignment == .topLeading { Spacer() }
        }
    }
}

// MARK: - Shimmer View

struct ShimmerView: View {
    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColor.textSecondary.opacity(0.12)

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 0.6)
                .offset(x: shimmerOffset * geometry.size.width)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.5
            }
        }
    }
}
