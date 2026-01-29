//
//  PostHeaderView.swift
//  SemtioApp
//
//  Created for Performance Optimization on 2026-01-27.
//

import SwiftUI

struct PostHeaderView: View, Equatable {
    let ownerId: String
    let displayName: String
    let username: String?
    let avatarURL: URL?
    let timeAgo: String
    let isOwner: Bool
    
    // Actions
    let onDelete: () -> Void
    let onBlock: () -> Void
    let onReport: () -> Void
    
    static func == (lhs: PostHeaderView, rhs: PostHeaderView) -> Bool {
        return lhs.ownerId == rhs.ownerId &&
               lhs.displayName == rhs.displayName &&
               lhs.avatarURL == rhs.avatarURL &&
               lhs.timeAgo == rhs.timeAgo
    }
    
    var body: some View {
        HStack {
            // Avatar
            NavigationLink(destination: PublicProfileView(userId: ownerId)) {
                if let url = avatarURL {
                    CachedRemoteImage(url: url, targetSize: CGSize(width: 64, height: 64))
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                }
            }
            
            // Name
            NavigationLink(destination: PublicProfileView(userId: ownerId)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.semtioDarkText)
                    
                    if let username = username {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            // Time
            Text(timeAgo)
                .font(.caption)
                .foregroundColor(.gray)
            
            // Menu
            Menu {
                Button(role: .destructive, action: onReport) {
                    Label("Şikayet Et", systemImage: "exclamationmark.bubble")
                }
                
                Button(action: onDelete) { // Actually Hide
                    Label("Gizle", systemImage: "eye.slash")
                }
                
                if !isOwner {
                    Button(role: .destructive, action: onBlock) {
                        Label("Kullanıcıyı Engelle", systemImage: "person.slash.fill")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color.clear)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
