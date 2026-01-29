//
//  UserRow.swift
//  SemtioApp
//
//  Created by Design System Refactor.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct UserRow: View {
    let user: AppUser
    var subtitle: String? = nil
    var action: RowAction? = nil
    
    enum RowAction {
        case button(title: String, style: ActionStyle, handler: () -> Void)
        case icon(name: String, handler: () -> Void)
        case text(String)
    }
    
    enum ActionStyle {
        case primary
        case secondary
        case outlined
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            if let avatarURL = user.avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(AppColor.surfaceSecondary)
                }
                .frame(width: ComponentSize.avatarMedium, height: ComponentSize.avatarMedium)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(AppColor.secondary.opacity(0.1))
                    .frame(width: ComponentSize.avatarMedium, height: ComponentSize.avatarMedium)
                    .overlay(
                        Text(String(user.fullName.prefix(1)).uppercased())
                            .font(AppFont.headline)
                            .foregroundColor(AppColor.secondary)
                    )
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName)
                    .font(AppFont.bodyBold)
                    .foregroundColor(AppColor.textPrimary)
                
                if let sub = subtitle ?? user.username {
                    Text(sub.hasPrefix("@") ? sub : "@\(sub)")
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            
            Spacer()
            
            // Action
            if let action = action {
                switch action {
                case .button(let title, let style, let handler):
                    Button(action: handler) {
                        Text(title)
                            .font(AppFont.captionBold)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 6)
                            .background(bgForStyle(style))
                            .foregroundColor(fgForStyle(style))
                            .cornerRadius(Radius.pill)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.pill)
                                    .stroke(borderForStyle(style), lineWidth: 1)
                            )
                    }
                    
                case .icon(let name, let handler):
                    Button(action: handler) {
                        Image(systemName: name)
                            .foregroundColor(AppColor.textSecondary)
                            .padding(8)
                            .background(AppColor.surface)
                            .clipShape(Circle())
                    }
                    
                case .text(let str):
                    Text(str)
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(AppColor.surface) // Optional: remove if used in plain list
        .cornerRadius(Radius.md) // Optional
    }
    
    private func bgForStyle(_ style: ActionStyle) -> Color {
        switch style {
        case .primary: return AppColor.primary
        case .secondary: return AppColor.surface2
        case .outlined: return .clear
        }
    }
    
    private func fgForStyle(_ style: ActionStyle) -> Color {
        switch style {
        case .primary: return AppColor.onPrimary
        case .secondary: return AppColor.textPrimary
        case .outlined: return AppColor.primary
        }
    }
    
    private func borderForStyle(_ style: ActionStyle) -> Color {
        switch style {
        case .outlined: return AppColor.primary
        default: return .clear
        }
    }
}

#Preview {
    VStack {
        // Mock User
        let user = AppUser(
            id: "1",
            fullName: "Ali Yılmaz",
            avatarAssetName: nil,
            avatarURL: nil,
            headline: nil,
            username: "ali_yilmaz",
            city: nil,
            bio: nil,
            interests: nil,
            profileCompleted: true,
            profileImageData: nil,
            shareCode11: nil,
            district: "Kadiköy",
            isPremium: false
        )
        
        UserRow(user: user, action: .button(title: "Follow", style: .primary, handler: {}))
        UserRow(user: user, subtitle: "İstanbul", action: .icon(name: "ellipsis", handler: {}))
    }
    .padding()
}
