//
//  PostDetailScreen.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct PostDetailScreen: View {
    let postId: String
    var ownerId: String? = nil
    var username: String? = nil
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var post: Post?
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                if let errorString = error {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(AppColor.textSecondary)
                        Text("Hata Oluştu")
                            .font(AppFont.headline)
                        Text(errorString) // Show specific error
                            .font(AppFont.body)
                            .foregroundColor(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("ID: \(postId)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .textSelection(.enabled)
                    }
                }
            } else if let post = post {
                ScrollView {
                    PostCardView(post: post)
                        .padding(.top, Spacing.md)
                }
            } else {
                Text("Gönderi bulunamadı")
                    .font(AppFont.headline)
                    .foregroundColor(AppColor.textSecondary)
            }
        }
        .navigationTitle("Gönderi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Kapat") {
                    dismiss()
                }
            }
        }
        .task {
            await loadPost()
        }
    }
    
    private func loadPost() async {
        isLoading = true
        do {
            // Sanitize ID just in case
            let cleanId = postId
                .replacingOccurrences(of: "Optional(\"", with: "")
                .replacingOccurrences(of: "\")", with: "")
                
            // Resolve Owner ID Strategy:
            // 1. Explicit Owner ID (Fastest)
            // 2. Username Lookup (Slower, but avoids Global Index)
            // 3. Fallback to Global Lookup (Requires Index)
            
            var resolvedOwnerId = ownerId
            
            if resolvedOwnerId == nil, let username = username {
                print("📥 Direct lookup missing ID, trying to resolve username: \(username)")
                if let user = await appState.userStore.resolveUserByUsername(username) {
                    resolvedOwnerId = user.id
                    print("✅ Resolved username '\(username)' to UID: \(user.id)")
                } else {
                    print("⚠️ Failed to resolve username '\(username)'")
                }
            }
            
            if let targetOwnerId = resolvedOwnerId {
                 print("📥 Loading post via Direct Lookup: \(cleanId) owner: \(targetOwnerId)")
                 post = try await appState.posts.fetchPost(postId: cleanId, userId: targetOwnerId)
            } else {
                 print("📥 Loading post via Global Lookup (Index Required): \(cleanId)")
                 post = try await appState.posts.fetchPost(postId: cleanId)
            }
        } catch {
            self.error = "Hata: \(error.localizedDescription)"
            print("❌ Failed to load post '\(postId)': \(error)")
        }
        isLoading = false
    }
}
