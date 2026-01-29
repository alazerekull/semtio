//
//  DeepLinkPostSheet.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

/// Sheet view that loads and displays a post from a deep link
struct DeepLinkPostSheet: View {
    let postId: String
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var post: Post?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCommentsSheet = false
    @State private var isSaved = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isSaving = false
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Paylaşım yükleniyor...")
                            .foregroundColor(.gray)
                    }
                } else if let post = post {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            postHeader(post: post)
                            
                            // Media
                            postMedia(post: post)
                            
                            // Action Bar
                            actionBar(post: post)
                            
                            // Footer Info
                            postFooter(post: post)
                            
                            Divider()
                                .padding(.vertical, 12)
                            
                            // Comments Section Header
                            commentsHeader(post: post)
                            
                            // Comments Preview
                            commentsPreview(post: post)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Paylaşım bulunamadı")
                            .font(.headline)
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Button("Kapat") {
                            dismiss()
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("Paylaşım")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadPost()
        }
        .sheet(isPresented: $showCommentsSheet) {
            if let post = post {
                PostCommentsSheet(postId: post.id, postOwnerId: post.ownerId)
            }
        }
        .confirmationDialog(
            "Bu gönderiyi silmek istediğinize emin misiniz?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Gönderiyi Sil", role: .destructive) {
                Task {
                    await deletePost()
                }
            }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("Bu işlem geri alınamaz.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let post = post {
                PostShareSheet(post: post)
                    .presentationDetents([.fraction(0.6), .large])
                    .presentationDragIndicator(.hidden)
            }
        }
    }
    
    // MARK: - Header
    
    @ViewBuilder
    private func postHeader(post: Post) -> some View {
        HStack {
            // Avatar
            Button(action: {
                appState.presentUserProfile(userId: post.ownerId)
            }) {
                if let avatarURL = post.ownerAvatarURL, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Circle().fill(AppColor.textSecondary.opacity(0.2))
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
            }
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(post.ownerDisplayName ?? post.ownerUsername ?? "Kullanıcı")
                    .font(AppFont.subheadline)
                    .foregroundColor(AppColor.textPrimary)
                
                if let username = post.ownerUsername {
                    Text("@\(username)")
                        .font(AppFont.footnote)
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            
            Spacer()
            
            // Time
            Text(timeAgo(post.createdAt))
                .font(AppFont.footnote)
                .foregroundColor(AppColor.textSecondary)
            
            // Menu (Delete, Report, etc.)
            Menu {
                if post.ownerId == appState.auth.uid {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Gönderiyi Sil", systemImage: "trash")
                    }
                } else {
                    Button {
                        // Report functionality
                    } label: {
                        Label("Şikayet Et", systemImage: "exclamationmark.bubble")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(AppFont.callout)
                    .foregroundColor(AppColor.textSecondary)
                    .padding(8)
                    .background(AppColor.textSecondary.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Media
    
    @ViewBuilder
    private func postMedia(post: Post) -> some View {
        if let firstMedia = post.mediaURLs.first, let url = URL(string: firstMedia) {
            if url.scheme == "mock" {
                ZStack {
                    AppColor.textSecondary.opacity(0.2)
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
            } else {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            AppColor.textSecondary.opacity(0.1)
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        ZStack {
                            AppColor.textSecondary.opacity(0.1)
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Action Bar
    
    @ViewBuilder
    private func actionBar(post: Post) -> some View {
        HStack(spacing: 20) {
            // Like Button
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    appState.postInteractions.toggleLike(post: post)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isLiked(post) ? "heart.fill" : "heart")
                        .font(.system(size: 24))
                        .foregroundColor(isLiked(post) ? .red : AppColor.textPrimary)
                        .scaleEffect(isLiked(post) ? 1.1 : 1.0)
                    
                    if likeCount(post) > 0 {
                        Text("\(likeCount(post))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColor.textPrimary)
                    }
                }
            }
            .disabled(appState.postInteractions.isLoading(post.id))
            
            // Comment Button
            Button(action: {
                showCommentsSheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "message")
                        .font(AppFont.title2)
                        .foregroundColor(AppColor.textPrimary)
                    
                    if post.commentCount > 0 {
                        Text("\(post.commentCount)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColor.textPrimary)
                    }
                }
            }
            
            // Share Button
            // Share Button
            Button(action: {
                showShareSheet = true
            }) {
                Image(systemName: "paperplane")
                    .font(AppFont.title2)
                    .foregroundColor(AppColor.textPrimary)
            }
            
            Spacer()
            
            // Save Button
            Button(action: {
                Task {
                    await toggleSave()
                }
            }) {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(AppFont.title2)
                        .foregroundColor(isSaved ? .orange : AppColor.textPrimary)
                }
            }
            .disabled(isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Footer
    
    @ViewBuilder
    private func postFooter(post: Post) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Likes count
            if likeCount(post) > 0 {
                Text("\(likeCount(post)) beğeni")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColor.textPrimary)
            }
            
            // Caption
            if !post.caption.isEmpty {
                // Use AttributedString to avoid deprecated Text + Text
                let captionText: Text = {
                    var userStr = AttributedString(post.ownerUsername ?? "user")
                    userStr.font = .systemFont(ofSize: 14, weight: .semibold)
                    
                    var capStr = AttributedString(" " + post.caption)
                    capStr.font = .systemFont(ofSize: 14)
                    
                    return Text(userStr + capStr)
                }()
                
                captionText.foregroundColor(AppColor.textPrimary)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Comments Section
    
    @ViewBuilder
    private func commentsHeader(post: Post) -> some View {
        HStack {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 14))
                .foregroundColor(AppColor.accent)
            Text("Yorumlar")
                .font(AppFont.calloutBold)
                .foregroundColor(AppColor.textPrimary)
            
            if post.commentCount > 0 {
                Text("(\(post.commentCount))")
                    .font(.system(size: 14))
                    .foregroundColor(AppColor.textSecondary)
            }
            
            Spacer()
            
            Button(action: {
                showCommentsSheet = true
            }) {
                Text("Tümünü Gör")
                    .font(AppFont.footnote)
                    .foregroundColor(.semtioPrimary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private func commentsPreview(post: Post) -> some View {
        if post.commentCount == 0 {
            VStack(spacing: 12) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.4))
                Text("Henüz yorum yok")
                    .font(.system(size: 14))
                    .foregroundColor(AppColor.textSecondary)
                Button(action: {
                    showCommentsSheet = true
                }) {
                    Text("İlk yorumu yap")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColor.onPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.semtioPrimary)
                        .cornerRadius(20)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            Button(action: {
                showCommentsSheet = true
            }) {
                HStack {
                    Text("\(post.commentCount) yorumun tümünü gör")
                        .font(.system(size: 14))
                        .foregroundColor(AppColor.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColor.textSecondary.opacity(0.05))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Helpers
    
    private func isLiked(_ post: Post) -> Bool {
        appState.postInteractions.isLiked(post.id)
    }
    
    private func likeCount(_ post: Post) -> Int {
        let isLocallyLiked = isLiked(post)
        if isLocallyLiked == post.isLiked {
            return post.likeCount
        } else if isLocallyLiked {
            return post.likeCount + 1
        } else {
            return max(0, post.likeCount - 1)
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func sharePost(_ post: Post) {
        let text = "Bu paylaşıma göz at: \(post.caption)"
        let url = URL(string: "semtio://post/\(post.id)")!
        
        let activityVC = UIActivityViewController(
            activityItems: [text, url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func toggleSave() async {
        guard let uid = appState.auth.uid else { return }
        
        isSaving = true
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        do {
            if isSaved {
                try await appState.posts.unsavePost(postId: postId, userId: uid)
                withAnimation { isSaved = false }
            } else {
                try await appState.posts.savePost(postId: postId, userId: uid)
                withAnimation { isSaved = true }
            }
            // Trigger refresh in profile
            appState.savedPostsChanged.toggle()
        } catch {
            print("❌ DeepLinkPostSheet: Failed to toggle save: \(error)")
        }
        
        isSaving = false
    }
    
    private func deletePost() async {
        guard let uid = appState.auth.uid else { return }
        
        isDeleting = true
        
        do {
            try await appState.posts.deletePost(postId: postId, userId: uid)
            
            // Remove from feed if present
            appState.postFeed.removePost(postId: postId)
            
            // Signal deletion to other screens (e.g. Profile)
            appState.lastDeletedPostId = postId
            
            dismiss()
        } catch {
            print("❌ DeepLinkPostSheet: Failed to delete post: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isDeleting = false
    }
    
    private func loadPost() async {
        isLoading = true
        do {
            // Try to find in feed first
            if let existing = appState.postFeed.posts.first(where: { $0.id == postId }) {
                self.post = existing
                appState.postInteractions.syncLikeState(for: existing)
                
                // Check if saved
                if let uid = appState.auth.uid {
                    isSaved = try await appState.posts.isPostSaved(postId: postId, userId: uid)
                }
                
                isLoading = false
                return
            }
            
            // Fetch from Firebase
            let fetchedPost = try await appState.posts.fetchPost(postId: postId)
            post = fetchedPost
            appState.postInteractions.syncLikeState(for: fetchedPost)
            
            // Check if saved
            if let uid = appState.auth.uid {
                isSaved = try await appState.posts.isPostSaved(postId: postId, userId: uid)
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
