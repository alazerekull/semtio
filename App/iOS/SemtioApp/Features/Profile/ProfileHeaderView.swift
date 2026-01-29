//
//  ProfileHeaderView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Premium profile header with glassmorphism stats, animated avatar ring, and modern layout

import SwiftUI

struct ProfileHeaderView: View {
    let user: AppUser
    let eventCount: Int
    let friendCount: Int
    let postCount: Int
    
    // Legacy follow is replaced by friendStatus
    let friendStatus: UserStore.FriendStatus
    let isFollowLoading: Bool
    let isPremium: Bool
    let isBlocked: Bool
    
    let onEditTapped: (() -> Void)?
    let onSettingsTapped: (() -> Void)?
    
    // Friend Actions
    let onAddFriend: (() -> Void)?
    let onCancelRequest: (() -> Void)?
    let onAcceptRequest: (() -> Void)?
    let onRejectRequest: (() -> Void)?
    let onUnfriend: (() -> Void)?
    let onMessage: (() -> Void)?
    
    // Legacy support (optional, can be passed as nil if using friendStatus)
    let onFollowTapped: (() -> Void)?

    @State private var avatarScale: CGFloat = 0.8
    @State private var statsOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 20
    @State private var ringRotation: Double = 0
    @State private var showUnfriendAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Row 1: Avatar + Stats
            HStack(spacing: 24) {
                // Avatar
                ModernProfileAvatar(user: user, isPremium: isPremium, size: 88)

                // Stats Row
                HStack(spacing: 0) {
                    SocialStatItem(value: postCount, label: "Gönderi")
                        .frame(maxWidth: .infinity)
                    
                    // Divider
                    Rectangle()
                        .fill(AppColor.border.opacity(0.3))
                        .frame(width: 1, height: 24)
                    
                    SocialStatItem(value: friendCount, label: "Arkadaş")
                        .frame(maxWidth: .infinity)
                    
                    // Divider
                    Rectangle()
                        .fill(AppColor.border.opacity(0.3))
                        .frame(width: 1, height: 24)
                    
                    SocialStatItem(value: eventCount, label: "Etkinlik")
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)

            // Row 2: Name & Bio
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(user.fullName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)

                    if isPremium {
                        Image(systemName: "checkmark.seal.fill")
                             .font(AppFont.footnote)
                             .foregroundColor(AppColor.accent)
                    }
                }

                if let username = user.username, !username.isEmpty {
                     Text(username)
                         .font(AppFont.footnote)
                         .foregroundColor(AppColor.textSecondary)
                }

                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppColor.textPrimary)
                        .padding(.top, 3)
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, Spacing.md)

            // Row 3: Action Buttons
            actionButtons
                .padding(.horizontal, Spacing.md)
                .padding(.top, 2)
        }
        .padding(.bottom, Spacing.md)
        .background(AppColor.background)
        .alert("Arkadaşlıktan Çıkar", isPresented: $showUnfriendAlert) {
            Button("Evet, Çıkar", role: .destructive) {
                onUnfriend?()
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("\(user.fullName) adlı kişiyi arkadaş listenizden çıkarmak istediğinize emin misiniz?")
        }
    }

    // MARK: - Vertical Divider
    private var verticalDivider: some View {
        Rectangle()
        .fill(AppColor.border.opacity(0.4))
            .frame(width: 0.5, height: 32)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        if let onEdit = onEditTapped {
            // Own Profile State
            HStack(spacing: Spacing.md) {
                // Edit Profile Button
                Button(action: onEdit) {
                    Text("Profili Düzenle")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .fill(AppColor.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(AppColor.border, lineWidth: 1)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                
                // Settings Button
                if let onSettings = onSettingsTapped {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .font(AppFont.callout)
                            .foregroundColor(AppColor.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .fill(AppColor.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .stroke(AppColor.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        } else {
            // Other User State - Refactored for Type Safety
            otherUserActionButtons
        }
    }
    
    @ViewBuilder
    private var otherUserActionButtons: some View {
        HStack(spacing: Spacing.md) {
            
            // Primary Action Button (Add/Accept/Status)
            if isBlocked {
                Button {} label: {
                    Label("Engellendi", systemImage: "nosign")
                        .frame(maxWidth: .infinity)
                }
                .disabled(true)
                .buttonStyle(PrimaryButtonStyle(backgroundColor: AppColor.error))
                
            } else {
                switch friendStatus {
                case .friends:
                    // Friends: [ Message ] [ Arkadaşsınız v ]
                    HStack(spacing: 8) {
                        Button {
                            onMessage?()
                        } label: {
                            Text("Mesaj")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        
                        Button {
                            showUnfriendAlert = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Arkadaşsınız")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    
                case .requestSent:
                    Button {
                        onCancelRequest?()
                    } label: {
                        Label("İstek Gönderildi", systemImage: "clock.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                case .requestReceived:
                    HStack(spacing: 8) {
                        Button {
                            onAcceptRequest?()
                        } label: {
                            Text("Kabul Et")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        
                        Button {
                            onRejectRequest?()
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: 44)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    
                case .none:
                    // Instagram Logic:
                    Button {
                        onAddFriend?()
                    } label: {
                        Label(user.isProfilePublic == true ? "Takip Et" : "İstek Gönder", systemImage: user.isProfilePublic == true ? "plus" : "lock.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }
}

// Helper Styles
struct PrimaryButtonStyle: ButtonStyle {
    var backgroundColor: Color = AppColor.primary
    var foregroundColor: Color = AppColor.onPrimary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(foregroundColor)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .cornerRadius(Radius.md)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(AppColor.textPrimary)
            .padding(.vertical, 10)
            .background(AppColor.surface)
            .cornerRadius(Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(AppColor.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Profile Stat Item (Inline)

private struct ProfileStatItem: View {
    let value: Int
    let label: String
    let icon: String

    @State private var animatedValue: Int = 0

    var body: some View {
        VStack(spacing: 4) {
            Text("\(animatedValue)")
                .font(AppFont.title2)
                .foregroundColor(AppColor.textPrimary)
                .contentTransition(.numericText(value: Double(animatedValue)))

            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(AppFont.caption)
            }
            .foregroundColor(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.easeOut(duration: 0.3)) {
                animatedValue = newValue
            }
        }
    }
}



// MARK: - Modern Profile Avatar

struct ModernProfileAvatar: View {
    let user: AppUser
    var isPremium: Bool = false
    var size: CGFloat = 80

    @State private var ringRotation: Double = 0

    @ViewBuilder
    private var initialsFallback: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [AppColor.primary.opacity(0.8), AppColor.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(String(user.fullName.prefix(1)).uppercased())
                    .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                    .foregroundColor(AppColor.onPrimary)
            )
    }

    var body: some View {
        ZStack {
            // Outer glow for premium
            if isPremium {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.yellow.opacity(0.25), Color.clear],
                            center: .center,
                            startRadius: size * 0.35,
                            endRadius: size * 0.6
                        )
                    )
                    .frame(width: size + 16, height: size + 16)
            }

            // Animated gradient ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: isPremium
                            ? [Color.yellow, Color.orange, Color.red.opacity(0.6), Color.orange, Color.yellow]
                            : [AppColor.primary, AppColor.secondary, AppColor.primary.opacity(0.6), AppColor.primary],
                        center: .center
                    ),
                    lineWidth: isPremium ? 3.5 : 3
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(ringRotation))

            // Avatar image
            Group {
                if let data = user.profileImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else if let avatarURL = user.avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure, .empty:
                            initialsFallback
                        @unknown default:
                            initialsFallback
                        }
                    }
                } else if let assetName = user.avatarAssetName,
                          !assetName.isEmpty,
                          UIImage(named: assetName) != nil {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                } else {
                    initialsFallback
                }
            }
            .frame(width: size - 10, height: size - 10)
            .clipShape(Circle())
        }
        .onAppear {
            if isPremium {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    ringRotation = 360
                }
            }
        }
    }
}

// MARK: - Legacy Components (For Compatibility)

struct ProfileAvatarView: View {
    let user: AppUser
    var isPremium: Bool = false

    var body: some View {
        ModernProfileAvatar(user: user, isPremium: isPremium)
    }
}

struct StatCardCompact: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }

            Text("\(value)")
                .font(AppFont.headline)
                .foregroundColor(AppColor.textPrimary)

            Text(label)
                .font(AppFont.captionBold)
                .foregroundColor(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .semtioCardStyle()
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {}
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            withAnimation(.spring(response: 0.2)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

struct ProfileStatBadge: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        StatCardCompact(value: value, label: label, icon: icon, color: color)
    }
}

struct ModernStatCard: View {
    let value: Int
    let label: String
    let icon: String
    let gradient: [Color]

    var body: some View {
        StatCardCompact(value: value, label: label, icon: icon, color: gradient.first ?? AppColor.primary)
    }
}

struct SocialStatItem: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
            Text(label)
                .font(AppFont.footnote)
                .foregroundColor(AppColor.textSecondary)
        }
    }
}

#Preview {
    ProfileHeaderView(
        user: User(
            id: "1",
            fullName: "Alaz Erekul",
            avatarAssetName: nil,
            headline: nil,
            username: "alazerekul576",
            city: "İstanbul",
            bio: "Tdım sverim",
            interests: ["Spor", "Müzik"]
        ),
        eventCount: 27,
        friendCount: 1,
        postCount: 3,
        friendStatus: .none,
        isFollowLoading: false,
        isPremium: false,
        isBlocked: false,
        onEditTapped: {},
        onSettingsTapped: {},
        onAddFriend: {},
        onCancelRequest: {},
        onAcceptRequest: {},
        onRejectRequest: {},
        onUnfriend: {},
        onMessage: {},
        onFollowTapped: nil
    )
}
