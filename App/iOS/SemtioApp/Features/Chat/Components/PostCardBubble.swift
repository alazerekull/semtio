//
//  PostCardBubble.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import FirebaseFirestore

struct PostCardBubble: View {
    let postId: String?
    let message: ChatMessage
    let isCurrentUser: Bool
    
    @EnvironmentObject var appState: AppState
    
    // Pure Render Props from Embedded Data (Anti-Gravity)
    private var preview: PostSharePreview? { message.postPreview }
    
    private var isVideo: Bool { preview?.mediaType == 1 }
    
    var body: some View {
        if let preview = preview {
            // RENDER CARD (No Fetch)
            VStack(alignment: .leading, spacing: 0) {
                // 1. Header
                HStack(spacing: 8) {
                    if let avatar = preview.authorAvatarURL, let url = URL(string: avatar) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(AppColor.textSecondary.opacity(0.1))
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                    
                    Text(preview.authorUsername ?? preview.authorName ?? "Kullanıcı")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let authorId = preview.authorId {
                         appState.handleDeepLink(URL(string: "semtio://profile/\(authorId)")!)
                    }
                }
                
                // 2. Media
                if let mediaStr = preview.mediaURL, let url = URL(string: mediaStr) {
                    ZStack {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ZStack {
                                    Color.gray.opacity(0.1)
                                    ProgressView()
                                }
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            case .failure:
                                Color.gray.opacity(0.2)
                            @unknown default:
                                Color.gray.opacity(0.2)
                            }
                        }
                        
                        if isVideo {
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(radius: 4)
                        }
                    }
                    .frame(width: 240, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .clipped()
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                    .onTapGesture { openPost() }
                }
                
                // 3. Caption
                if let caption = preview.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.primary.opacity(0.9))
                        .padding(10)
                        .frame(width: 252, alignment: .leading)
                        .onTapGesture { openPost() }
                } else {
                    Spacer().frame(height: 6)
                }
            }
            .frame(width: 252)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .clipShape(RoundedCornersShape(corners: [
                .topLeft, .topRight,
                isCurrentUser ? .bottomLeft : .bottomRight
            ], radius: 16))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedCornersShape(corners: [
                    .topLeft, .topRight,
                    isCurrentUser ? .bottomLeft : .bottomRight
                ], radius: 16)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            
        } else {
            // OLD FORMAT / RETRY CARD
            VStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundColor(.gray)
                Text("İçerik eski format")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if postId != nil {
                     Button("Görüntüle") {
                         openPost()
                     }
                     .font(.caption.bold())
                     .padding(.horizontal, 12)
                     .padding(.vertical, 6)
                     .background(Color.semtioPrimary.opacity(0.1))
                     .cornerRadius(8)
                }
            }
            .frame(width: 140, height: 100)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func openPost() {
        if let id = postId {
            var urlString = "semtio://post/\(id)"
            if let authorId = preview?.authorId {
                 urlString += "?ownerId=\(authorId)"
            }
            if let url = URL(string: urlString) {
                appState.handleDeepLink(url)
            }
        }
    }
}
