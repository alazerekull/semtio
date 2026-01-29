//
//  CreateGroupView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import PhotosUI

enum GroupCreationStep {
    case selectParticipants
    case groupDetails
}

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var chatStore: ChatStore
    @EnvironmentObject var friendStore: FriendStore

    @State private var step: GroupCreationStep = .selectParticipants
    @State private var selectedFriendIds: Set<String> = []
    @State private var groupName: String = ""
    @State private var groupDescription: String = ""
    @State private var groupImage: UIImage? = nil
    @State private var searchQuery: String = ""
    @State private var isCreating: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var filteredFriends: [AppUser] {
        if searchQuery.isEmpty {
            return friendStore.friends
        }
        return friendStore.friends.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchQuery) ||
            ($0.username?.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
    }

    var selectedFriends: [AppUser] {
        friendStore.friends.filter { selectedFriendIds.contains($0.id) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                switch step {
                case .selectParticipants:
                    participantSelectionView
                case .groupDetails:
                    groupDetailsView
                }

                if isCreating {
                    creatingOverlay
                }
            }
            .navigationTitle(step == .selectParticipants ? "Yeni Grup" : "Grup Detayları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(step == .selectParticipants ? "İptal" : "Geri") {
                        if step == .groupDetails {
                            withAnimation {
                                step = .selectParticipants
                            }
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if step == .selectParticipants {
                        Button("İleri") {
                            withAnimation {
                                step = .groupDetails
                            }
                        }
                        .disabled(selectedFriendIds.count < 1)
                    } else {
                        Button("Oluştur") {
                            createGroup()
                        }
                        .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    }
                }
            }
            .onAppear {
                if let uid = appState.auth.uid {
                    Task {
                        await friendStore.loadFriends(userId: uid)
                    }
                }
            }
        }
    }

    // MARK: - Step 1: Participant Selection

    private var participantSelectionView: some View {
        VStack(spacing: 0) {
            // Search Bar
            searchBar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // Selected Count
            if !selectedFriendIds.isEmpty {
                HStack {
                    Text("\(selectedFriendIds.count) kişi seçildi")
                        .font(AppFont.subheadline)
                        .foregroundColor(AppColor.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppColor.surface)
            }

            // Friends List
            ScrollView {
                LazyVStack(spacing: 0) {
                    if filteredFriends.isEmpty {
                        emptyFriendsPlaceholder
                    } else {
                        ForEach(filteredFriends) { friend in
                            ParticipantRow(
                                user: friend,
                                isSelected: selectedFriendIds.contains(friend.id)
                            ) {
                                toggleSelection(friend.id)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .background(AppColor.background)
    }

    // MARK: - Step 2: Group Details

    private var groupDetailsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Group Photo
                VStack(spacing: 12) {
                    Button {
                        showImagePicker = true
                    } label: {
                        if let groupImage = groupImage {
                            Image(uiImage: groupImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(AppColor.surface)
                                    .frame(width: 100, height: 100)

                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppColor.textSecondary)

                                    Text("Fotoğraf Ekle")
                                        .font(AppFont.caption)
                                        .foregroundColor(AppColor.textSecondary)
                                }
                            }
                        }
                    }

                    Text("İsteğe Bağlı")
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
                .padding(.top, 20)

                // Group Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Grup Adı")
                        .font(AppFont.subheadline)
                        .foregroundColor(AppColor.textPrimary)

                    TextField("Grup adını girin", text: $groupName)
                        .font(AppFont.body)
                        .foregroundColor(AppColor.textPrimary)
                        .padding(12)
                        .background(AppColor.surface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(AppColor.border, lineWidth: 1)
                        )

                    Text("\(groupName.count)/50")
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .onChange(of: groupName) { _, newValue in
                    if newValue.count > 50 {
                        groupName = String(newValue.prefix(50))
                    }
                }

                // Group Description (Optional)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Açıklama (İsteğe Bağlı)")
                        .font(AppFont.subheadline)
                        .foregroundColor(AppColor.textPrimary)

                    TextField("Grup hakkında...", text: $groupDescription, axis: .vertical)
                        .font(AppFont.body)
                        .foregroundColor(AppColor.textPrimary)
                        .lineLimit(3...5)
                        .padding(12)
                        .background(AppColor.surface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(AppColor.border, lineWidth: 1)
                        )
                }

                // Selected Participants
                VStack(alignment: .leading, spacing: 12) {
                    Text("Katılımcılar (\(selectedFriends.count))")
                        .font(AppFont.subheadline)
                        .foregroundColor(AppColor.textPrimary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(selectedFriends) { friend in
                                ParticipantChip(user: friend) {
                                    selectedFriendIds.remove(friend.id)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AppColor.background)
        .photosPicker(isPresented: $showImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    groupImage = image
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColor.textSecondary)
                .font(.system(size: 16))

            TextField("Katılımcı ara...", text: $searchQuery)
                .font(AppFont.body)
                .foregroundColor(AppColor.textPrimary)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColor.textSecondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColor.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(AppColor.border, lineWidth: 1)
        )
    }

    // MARK: - Empty State

    private var emptyFriendsPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)

            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(AppColor.textSecondary.opacity(0.5))

            Text("Arkadaş bulunamadı")
                .font(AppFont.subheadline)
                .foregroundColor(AppColor.textSecondary)

            Spacer()
        }
    }

    // MARK: - Creating Overlay

    private var creatingOverlay: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)

                    Text("Grup oluşturuluyor...")
                        .font(AppFont.subheadline)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(Color.black.opacity(0.7))
                .cornerRadius(16)
            }
    }

    // MARK: - Actions

    private func toggleSelection(_ friendId: String) {
        if selectedFriendIds.contains(friendId) {
            selectedFriendIds.remove(friendId)
        } else {
            selectedFriendIds.insert(friendId)
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func createGroup() {
        guard let currentUserId = appState.auth.uid else { return }
        guard !groupName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isCreating = true

        Task {
            do {
                // Prepare participant IDs (include creator)
                var participantIds = Array(selectedFriendIds)
                participantIds.append(currentUserId)

                // Convert image to data if available
                let photoData = groupImage?.jpegData(compressionQuality: 0.7)

                // Create group
                let threadId = try await chatStore.createGroupChat(
                    name: groupName.trimmingCharacters(in: .whitespaces),
                    description: groupDescription.isEmpty ? nil : groupDescription,
                    participantIds: participantIds,
                    creatorId: currentUserId,
                    photoData: photoData
                )

                await MainActor.run {
                    isCreating = false
                    dismiss()

                    // Navigate to the new group chat
                    appState.deepLinkChatThreadId = threadId

                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    // Show error
                    print("Error creating group: \(error.localizedDescription)")

                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Participant Row

struct ParticipantRow: View {
    let user: AppUser
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Avatar
                if let avatarURL = user.avatarURL, !avatarURL.isEmpty {
                    AsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(AppColor.surface)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(AppColor.textSecondary)
                            )
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppColor.surface)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(AppColor.textSecondary)
                                .font(.system(size: 20))
                        )
                }

                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName)
                        .font(AppFont.subheadline)
                        .foregroundColor(AppColor.textPrimary)

                    if let username = user.username {
                        Text("@\(username)")
                            .font(AppFont.caption)
                            .foregroundColor(AppColor.textSecondary)
                    }
                }

                Spacer()

                // Checkbox
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? AppColor.primary : AppColor.border, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(AppColor.primary)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColor.onPrimary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Participant Chip

struct ParticipantChip: View {
    let user: AppUser
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // Avatar
                if let avatarURL = user.avatarURL, !avatarURL.isEmpty {
                    AsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(AppColor.surface)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppColor.surface)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text(String(user.fullName.prefix(1)).uppercased())
                                .font(AppFont.headline)
                                .foregroundColor(AppColor.textPrimary)
                        )
                }

                // Remove Button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColor.error)
                        .background(Circle().fill(Color.white))
                }
                .offset(x: 4, y: -4)
            }

            Text(user.fullName.split(separator: " ").first.map(String.init) ?? user.fullName)
                .font(AppFont.caption)
                .foregroundColor(AppColor.textPrimary)
                .lineLimit(1)
                .frame(width: 60)
        }
    }
}

// MARK: - Preview

#Preview {
    CreateGroupView()
        .environmentObject(AppState(
            session: SessionManager(),
            theme: AppThemeManager(),
            location: LocationManager()
        ))
        .environmentObject(ChatStore(repo: MockChatRepository()))
        .environmentObject(FriendStore(repo: MockFriendRepository(), notificationRepo: MockNotificationRepository(), userStore: UserStore(repo: MockUserRepository())))
}
