//
//  PostCommentsSheet.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct PostCommentsSheet: View {
    let postId: String
    let postOwnerId: String? // Optional because sometimes we might not have it loaded yet, but usually we do
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var comments: [PostComment] = []
    @State private var isLoading = true
    @State private var newCommentText = ""
    @State private var isSending = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Comments List
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if comments.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.4))
                        Text("Henüz yorum yok")
                            .foregroundColor(.gray)
                        Text("İlk yorumu sen yap!")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(comments) { comment in
                                CommentRow(comment: comment)
                            }
                        }
                        .padding()
                    }
                }
                
                Divider()
                
                // Input Area
                HStack(spacing: 12) {
                    TextField("Yorum ekle...", text: $newCommentText)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(20)
                    
                    Button(action: {
                        Task {
                            await sendComment()
                        }
                    }) {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Paylaş")
                                .fontWeight(.semibold)
                                .foregroundColor(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .semtioPrimary)
                        }
                    }
                    .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
                .padding()
                .padding(.bottom, 10) // Extra padding for safe area
            }
            .navigationTitle("Yorumlar")
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
            await loadComments()
        }
    }
    
    private func loadComments() async {
        isLoading = true
        do {
            comments = try await appState.posts.fetchComments(postId: postId, limit: 50)
        } catch {
            print("❌ PostCommentsSheet: Failed to load comments: \(error)")
        }
        isLoading = false
    }
    
    private func sendComment() async {
        guard let uid = appState.auth.uid else { return }
        
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isSending = true
        
        // Optimistic UI
        let tempId = UUID().uuidString
        let tempComment = PostComment(
            id: tempId,
            postId: postId,
            uid: uid,
            username: userStore.currentUser.username,
            userDisplayName: userStore.currentUser.displayName,
            userAvatarURL: userStore.currentUser.avatarURL,
            text: text,
            createdAt: Date()
        )
        comments.append(tempComment)
        newCommentText = ""
        
        do {
            let actualComment = try await appState.posts.addComment(
                postId: postId,
                uid: uid,
                text: text,
                username: userStore.currentUser.username,
                userDisplayName: userStore.currentUser.displayName,
                userAvatarURL: userStore.currentUser.avatarURL
            )
            
            // Replace mock with actual
            if let index = comments.firstIndex(where: { $0.id == tempId }) {
                comments[index] = actualComment
            }
            
            // Notify feed to update count
            appState.postFeed.incrementCommentCount(postId: postId)
            
            // Trigger Notification
            if let ownerId = postOwnerId, ownerId != uid {
                let notification = AppNotification(
                    id: UUID().uuidString,
                    userId: ownerId,
                    type: .postComment,
                    title: "Yeni Yorum",
                    body: text,
                    createdAt: Date(),
                    isRead: false,
                    fromUserId: uid,
                    fromUserName: userStore.currentUser.displayName,
                    fromUserAvatar: userStore.currentUser.avatarURL,
                    postId: postId,
                    commentId: actualComment.id
                )
                await appState.notifications.sendNotification(notification)
            }
            
        } catch {
            print("❌ PostCommentsSheet: Failed to add comment: \(error)")
            // Rollback
            comments.removeAll(where: { $0.id == tempId })
            newCommentText = text // Restore text
        }
        
        isSending = false
    }
}

struct CommentRow: View {
    let comment: PostComment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            if let avatarURL = comment.userAvatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        AppColor.textSecondary.opacity(0.2)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(comment.username ?? comment.userDisplayName ?? "Kullanıcı")
                        .font(.system(size: 14, weight: .semibold))
                    Text(timeAgo(comment.createdAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(.semtioDarkText)
            }
            
            Spacer()
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
