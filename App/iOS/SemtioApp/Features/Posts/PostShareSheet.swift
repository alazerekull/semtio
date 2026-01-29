//
//  PostShareSheet.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct PostShareSheet: View {
    let post: Post
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedUserIds: Set<String> = []
    
    var filteredFriends: [AppUser] {
        let friends = appState.friends.friends
        if searchText.isEmpty {
            return friends
        } else {
            return friends.filter { user in
                (user.username?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                user.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Indicator
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)
            
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Ara...", text: $searchText)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom, 16)
            
            // Friends Grid
            if appState.friends.isLoading && appState.friends.friends.isEmpty {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if filteredFriends.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text(searchText.isEmpty ? "Henüz arkadaşın yok" : "Kullanıcı bulunamadı")
                        .foregroundColor(.gray)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        ForEach(filteredFriends) { user in
                            FriendShareItem(user: user, isSelected: selectedUserIds.contains(user.id))
                                .onTapGesture {
                                    toggleSelection(user.id)
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Send Button (if selected)
            if !selectedUserIds.isEmpty {
                Button(action: sendToSelected) {
                    Text("Gönder (\(selectedUserIds.count))")
                        .font(AppFont.calloutBold)
                        .foregroundColor(AppColor.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.semtioPrimary)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            
            Divider()
            
            // Bottom Actions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    // Story
                    ShareActionItem(icon: "plus.circle", title: "Hikayeye ekle", color: .gray) {
                        // TODO: Add to story
                    }
                    
                    // WhatsApp
                    ShareActionItem(icon: "phone.circle.fill", title: "WhatsApp", color: .green) {
                        shareToWhatsApp()
                    }
                    
                    // Copy Link
                    ShareActionItem(icon: "link.circle.fill", title: "Bağlantıyı\nkopyala", color: .gray) {
                        copyLink()
                    }
                    
                    // System Share
                    ShareActionItem(icon: "square.and.arrow.up.circle.fill", title: "Paylaş...", color: .gray) {
                        openSystemShare()
                    }
                    
                    // Snapchat (Mock)
                    ShareActionItem(icon: "camera.circle.fill", title: "Snapchat", color: .yellow) {
                        // Mock
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            if appState.friends.friends.isEmpty {
                Task {
                    if let uid = appState.auth.uid {
                        await appState.friends.loadFriends(userId: uid)
                    }
                }
            }
        }
    }
    
    private func toggleSelection(_ id: String) {
        if selectedUserIds.contains(id) {
            selectedUserIds.remove(id)
        } else {
            selectedUserIds.insert(id)
        }
    }
    
    private func sendToSelected() {
        guard let currentUid = appState.auth.uid else { return }
        let selectedIds = Array(selectedUserIds)
        let postToSend = self.post
        let senderDisplayName = appState.userStore.currentUser.displayName
        let senderAvatarURL = appState.userStore.currentUser.avatarURL

        Task {
            // UI Feedback immediately
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Post Preview Data
            let preview = PostSharePreview(
                id: postToSend.id,
                authorId: postToSend.ownerId,
                authorName: postToSend.ownerDisplayName ?? postToSend.ownerUsername ?? "User",
                authorUsername: postToSend.ownerUsername,
                authorAvatarURL: postToSend.ownerAvatarURL,
                caption: postToSend.caption,
                mediaURL: (postToSend.mediaType == .video ? postToSend.thumbnailURL : nil) ?? postToSend.mediaURLs.first,
                mediaType: postToSend.mediaType == .video ? 1 : 0,
                aspectRatio: 1.0 // Assuming square or calculate if available
            )

            // Perform sending in background
            await withTaskGroup(of: Void.self) { group in
                for userId in selectedIds {
                    group.addTask {
                        // 1. Get/Create Thread
                        // Note: createDM is on MainActor, so we await it
                        if let threadId = await appState.chat.createDM(with: userId, currentUserId: currentUid) {

                            // 2. Prepare Message
                            var msg = ChatMessage(
                                id: UUID().uuidString,
                                threadId: threadId,
                                text: "Bir gönderi paylaştı", // Fallback text
                                senderId: currentUid,
                                createdAt: Date(),
                                type: .post,
                                sharedPostId: postToSend.id,
                                postPreview: preview
                            )
                            msg.senderName = senderDisplayName

                            // 3. Send
                            do {
                                try await appState.chat.repo.sendMessage(msg)
                            } catch {
                                print("❌ Failed to share post to \(userId): \(error)")
                            }
                        }
                    }
                }
            }

            // Send notification to post owner (only once, not per recipient)
            if postToSend.ownerId != currentUid {
                let notification = AppNotification(
                    id: UUID().uuidString,
                    userId: postToSend.ownerId,
                    type: .postShare,
                    title: "Paylaşım",
                    body: "\(senderDisplayName) gönderini paylaştı.",
                    createdAt: Date(),
                    isRead: false,
                    fromUserId: currentUid,
                    fromUserName: senderDisplayName,
                    fromUserAvatar: senderAvatarURL,
                    postId: postToSend.id
                )
                await appState.notifications.sendNotification(notification)
            }

            // Dismiss after initiating
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func copyLink() {
        let url = "semtio://post/\(post.id)"
        UIPasteboard.general.string = url
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        dismiss()
    }
    
    private func shareToWhatsApp() {
        let text = "Bu paylaşıma göz at: \(post.caption) semtio://post/\(post.id)"
        let urlString = "whatsapp://send?text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openSystemShare() {
        // Wait for dismiss to avoid stacked sheets issues or present on top
        // Best approach: dismiss custom sheet, then tell parent to show system sheet?
        // Or present from here.
        
        let text = "Bu paylaşıma göz at: \(post.caption)"
        let url = URL(string: "semtio://post/\(post.id)")!
        
        let activityVC = UIActivityViewController(
            activityItems: [text, url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            // Find top controller
            var topController = rootVC
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(activityVC, animated: true)
        }
    }
}

struct FriendShareItem: View {
    let user: AppUser
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                if let avatarURL = user.avatarURL, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        AppColor.textSecondary.opacity(0.2)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppColor.textSecondary.opacity(0.2))
                        .frame(width: 60, height: 60)
                    Text(String((user.username ?? "").prefix(1)).uppercased())
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .blue)
                        .font(AppFont.title3)
                        .offset(x: 2, y: 2)
                }
            }
            
            Text(user.displayName)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(AppColor.textPrimary)
        }
        .frame(width: 70)
        .opacity(isSelected ? 1.0 : 0.6)
    }
}

struct ShareActionItem: View {
    let icon: String // System name or Asset name?
    let title: String
    let color: Color
    let action: () -> Void
    
    // Custom style for specific apps
    var isSystemIcon: Bool = true
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(width: 60, height: 60)
                    
                    if isSystemIcon {
                        Image(systemName: icon)
                            .font(.system(size: 28))
                            .foregroundColor(color)
                    } else {
                        // Asset image here if we had logos
                        Image(systemName: icon) // Fallback
                    }
                }
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                    
                Text(title)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(2)
                    .frame(width: 70) // Ensure consistent width for text wrapping
            }
        }
    }
}
