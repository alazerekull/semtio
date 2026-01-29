//
//  ChatRowView.swift
//  SemtioApp
//
//  Created by Antigravity on 2026-01-20.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct ChatRowView: View {
    let summary: ChatSummary
    let currentUserId: String?
    
    @EnvironmentObject var friendStore: FriendStore
    
    var otherUserId: String? {
        // Find the ID that is not the current user
        summary.memberIds.first(where: { $0 != currentUserId })
    }
    
    var displayTitle: String {
        if summary.type == .event || summary.title != "Sohbet" {
            return summary.title
        }
        // Try to resolve DM name from friends list
        if let otherId = otherUserId, let friend = friendStore.friends.first(where: { $0.id == otherId }) {
            return friend.displayName
        }
        return "Kullanıcı"
    }
    
    var displayAvatarURL: String? {
        if summary.type == .event { return summary.avatarURL }
        if let otherId = otherUserId, let friend = friendStore.friends.first(where: { $0.id == otherId }) {
            return friend.avatarURL
        }
        return summary.avatarURL
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Group {
                if let url = displayAvatarURL, let validURL = URL(string: url) {
                    AsyncImage(url: validURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        AppColor.textSecondary.opacity(0.3)
                    }
                } else {
                    // Placeholder based on type
                    ZStack {
                        Circle()
                            .fill(summary.type == .event ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                        
                        Image(systemName: summary.type == .event ? "calendar" : "person.fill")
                            .foregroundColor(summary.type == .event ? .orange : .blue)
                            .font(AppFont.title3)
                    }
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayTitle)
                        .font(AppFont.calloutBold)
                        .foregroundColor(AppColor.textPrimary)
                    
                    Spacer()
                    
                    if summary.unreadCount > 0 {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                
                HStack {
                    Text(summary.lastMessage ?? "Mesaj yok")
                        .font(summary.unreadCount > 0 ? .system(size: 14, weight: .medium) : .system(size: 14))
                        .foregroundColor(summary.unreadCount > 0 ? .primary : .gray)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(summary.timeAgo)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // Tappable area
    }
}
