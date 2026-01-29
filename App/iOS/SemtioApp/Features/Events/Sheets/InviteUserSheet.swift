//
//  InviteUserSheet.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct InviteUserSheet: View {
    let event: Event
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var chatStore: ChatStore
    
    @State private var searchText = ""
    @State private var sentInvites: Set<String> = []
    @State private var isProcessing = false
    @State private var showStoryCreation = false
    
    var filteredFriends: [AppUser] {
        // ... (existing filter logic)
        if searchText.isEmpty {
            return friendStore.friends
        } else {
            return friendStore.friends.filter {
                $0.fullName.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationStack {
             VStack(spacing: 0) {
                 // ... (existing search and list code)
                 // Search Bar
                 HStack {
                     Image(systemName: "magnifyingglass")
                         .foregroundColor(.gray)
                     TextField("Arkadaş ara...", text: $searchText)
                 }
                 .padding(10)
                 .background(Color(.systemGray6))
                 .cornerRadius(10)
                 .padding()
                 
                 // Friends List
                 if friendStore.isLoading {
                     ProgressView()
                         .frame(maxHeight: .infinity)
                 } else if filteredFriends.isEmpty {
                     VStack(spacing: 12) {
                         Image(systemName: "person.2.slash")
                             .font(.system(size: 40))
                             .foregroundColor(.gray)
                         Text(searchText.isEmpty ? "Arkadaşın yok" : "Sonuç bulunamadı")
                             .foregroundColor(.secondary)
                     }
                     .frame(maxHeight: .infinity)
                 } else {
                     List {
                         ForEach(filteredFriends) { friend in
                             FriendInviteRow(
                                 friend: friend,
                                 isSent: sentInvites.contains(friend.id),
                                 onInvite: {
                                     sendInvite(to: friend)
                                 }
                             )
                         }
                     }
                     .listStyle(.plain)
                 }
                 
                // External Share Link (Footer)
                VStack(spacing: 12) {
                    Divider()
                    
                    // Share to Story
                    Button {
                        shareToStory()
                    } label: {
                        Label("Hikayende Paylaş", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Share Link
                    Button {
                        shareLink()
                    } label: {
                        Label("Bağlantıyı Paylaş (WhatsApp, vb.)", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.semtioPrimary.opacity(0.1))
                            .foregroundColor(.semtioPrimary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Arkadaşlarını Davet Et")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .task {
                await friendStore.loadIfNeeded(userId: userStore.currentUser.id)
            }
            .fullScreenCover(isPresented: $showStoryCreation) {
                // Direct Share Mode: Skip media selection, use Event Background
                StoryEditorView(image: nil, videoURL: nil, contextEvent: event)
            }
        }
    }

    // MARK: - Actions
    
    private func sendInvite(to friend: AppUser) {
        guard !sentInvites.contains(friend.id) else { return }
        
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        
        // Optimistic UI Update
        sentInvites.insert(friend.id)
        
        Task {
            // Send as a Rich Event Card
            do {
                let thread = try await chatStore.getOrCreateDMThread(
                    currentUserId: userStore.currentUser.id,
                    otherUserId: friend.id
                )
                
                await chatStore.sendEvent(
                    threadId: thread.id,
                    event: event,
                    senderId: userStore.currentUser.id
                )
                
                // Optional: Also send the friendly text message as followup? 
                // Or let the card speak for itself.
                // Converting original text logic to just card for cleaner UI as requested.
                
                print("✅ Invite sent to \(friend.fullName)")
            } catch {
                print("❌ Failed to send invite: \(error)")
                // Revert optimistic update on failure
                await MainActor.run { _ = sentInvites.remove(friend.id) }
            }
        }
    }
    
    private func shareLink() {
        let text = "Semtio'da \"\(event.title)\" etkinliğine sen de gel! https://semtio.app/event/\(event.id)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func shareToStory() {
        showStoryCreation = true
    }
}

struct FriendInviteRow: View {
    let friend: AppUser
    let isSent: Bool
    let onInvite: () -> Void
    
    var body: some View {
        HStack {
            // Avatar
            if let urlString = friend.avatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(Text(String(friend.fullName.prefix(1))).foregroundColor(.white))
            }
            
            Text(friend.fullName)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onInvite) {
                Text(isSent ? "Davet Edildi" : "Davet Et")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSent ? Color.gray.opacity(0.2) : Color.semtioPrimary)
                    .foregroundColor(isSent ? .gray : .white)
                    .cornerRadius(20)
            }
            .disabled(isSent)
        }
        .padding(.vertical, 4)
    }
}
