//
//  ActivityPostView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct ActivityPostView: View {
    let post: Post
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Button(action: {
                appState.presentUserProfile(userId: post.ownerId)
            }) {
                if let avatarURL = post.ownerAvatarURL, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            AppColor.textSecondary.opacity(0.1)
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
            
            VStack(alignment: .leading, spacing: 6) {
                // Info Text
                HStack(spacing: 4) {
                    Text(post.ownerDisplayName ?? post.ownerUsername ?? "Kullanıcı")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.semtioDarkText)
                    
                    Text(activityDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.semtioDarkText)
                }
                .multilineTextAlignment(.leading)
                
                // Event Card (Mini)
                if let eventId = post.eventId, let eventName = post.eventName {
                    Button(action: {
                        appState.handleDeepLink(URL(string: "semtio://event/\(eventId)")!)
                    }) {
                        HStack {
                            Image(systemName: "calendar")
                                .font(AppFont.headline)
                                .foregroundColor(.semtioPrimary)
                                .frame(width: 32, height: 32)
                                .background(Color.semtioPrimary.opacity(0.1))
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(eventName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.semtioDarkText)
                                Text("Etkinliği görüntüle")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }
                
                // Time
                Text(timeAgo(post.createdAt))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var activityDescription: String {
        switch post.type {
        case .userJoinedEvent:
            return "bir etkinliğe katılacak"
        case .userCreatedEvent:
            return "bir etkinlik oluşturdu"
        case .eventStarted:
            return "etkinliğini başlattı"
        case .eventEnded:
            return "etkinliğini tamamladı"
        default:
            return "bir işlem yaptı"
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
