//
//  StoryHeaderView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct StoryHeaderView: View {
    let user: AppUser
    let date: Date
    let onClose: () -> Void
    let onMore: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Avatar
            ProfileAvatarSmall(user: user, size: 36)
            
            // Name & Time
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username ?? user.fullName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Text(date.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            Spacer()
            
            // More Options (Three dots)
            Button(action: onMore) {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(8)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            
            // Close Button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(8)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// Helper Extension for Time Ago if not already present
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
