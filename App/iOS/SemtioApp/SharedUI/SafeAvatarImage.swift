//
//  SafeAvatarImage.swift
//  SemtioApp
//
//  Safe avatar image component with fallback to SF Symbol.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

/// A safe avatar image view that handles:
/// - Remote URL (avatarURL) with AsyncImage
/// - Local asset (avatarAssetName) with fallback
/// - Initials-based placeholder
/// - SF Symbol fallback if all else fails
struct SafeAvatarImage: View {
    let avatarURL: String?
    let avatarAssetName: String?
    let profileImageData: Data?
    let fullName: String
    let size: CGFloat
    
    init(
        avatarURL: String? = nil,
        avatarAssetName: String? = nil,
        profileImageData: Data? = nil,
        fullName: String = "",
        size: CGFloat = 48
    ) {
        self.avatarURL = avatarURL
        self.avatarAssetName = avatarAssetName
        self.profileImageData = profileImageData
        self.fullName = fullName
        self.size = size
    }
    
    /// Convenience init from User model
    init(user: User, size: CGFloat = 48) {
        self.avatarURL = user.avatarURL
        self.avatarAssetName = user.avatarAssetName
        self.profileImageData = user.profileImageData
        self.fullName = user.fullName
        self.size = size
    }
    
    var body: some View {
        Group {
            if let data = profileImageData, let uiImage = UIImage(data: data) {
                // Local data blob
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let avatarURL = avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                // Remote URL (safe, http/https only)
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
            } else if let assetName = avatarAssetName, !assetName.isEmpty, UIImage(named: assetName) != nil {
                // Local asset (only if it exists)
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                // Fallback placeholder
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        if !fullName.isEmpty {
            // Initials-based placeholder
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColor.primaryFallback.opacity(0.3), Color.purple.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Text(String(fullName.prefix(1)).uppercased())
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundColor(AppColor.primaryFallback)
                )
        } else {
            // SF Symbol fallback
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(AppColor.border)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SafeAvatarImage(fullName: "John Doe", size: 80)
        SafeAvatarImage(avatarAssetName: "nonexistent", fullName: "Jane", size: 60)
        SafeAvatarImage(size: 40)
    }
}
