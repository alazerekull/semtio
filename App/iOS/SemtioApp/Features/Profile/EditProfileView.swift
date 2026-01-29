//
//  EditProfileView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userStore: UserStore
    
    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var isProfilePublic: Bool = true
    @State private var readReceiptsEnabled: Bool = true
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColor.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Avatar Card
                        avatarSection
                        
                        // Personal Info Section
                        personalInfoSection
                        
                        // Privacy Section
                        privacySection
                    }
                }
            }
            .navigationTitle("Profili Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Text("İptal")
                            .foregroundColor(AppColor.textPrimary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveProfile) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Kaydet")
                                .font(AppFont.bodyBold)
                                .foregroundColor(AppColor.primary)
                        }
                    }
                    .disabled(isSaving || fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            // Load from profile if available, else legacy
            if let profile = userStore.currentUserProfile {
                self.fullName = profile.displayName ?? ""
                self.username = profile.username ?? ""
                self.bio = profile.bio ?? ""
                self.isProfilePublic = profile.isProfilePublic
                self.readReceiptsEnabled = profile.readReceiptsEnabled
            } else {
                self.fullName = userStore.currentUser.fullName
                self.username = userStore.currentUser.username ?? ""
                self.bio = userStore.currentUser.bio ?? ""
            }
        }
        .onChangeCompatible(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = uiImage
                    }
                }
            }
        }
    }
    
    private var avatarSection: some View {
        VStack(spacing: Spacing.md) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let selectedImage = selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFill()
                    } else if let url = userStore.profileAvatarURLForUI ?? userStore.avatarURLForUI {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                    } else if let data = userStore.currentUser.profileImageData,
                              let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(AppColor.border)
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColor.surface, lineWidth: 3))
                .shadow(radius: 2)
                
                // Camera Icon Badge
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColor.surface)
                        .frame(width: 32, height: 32)
                        .background(AppColor.primary)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppColor.surface, lineWidth: 2))
                }
                .offset(x: 4, y: 4)
            }
            
            Text("Fotoğrafı Değiştir")
                .font(AppFont.bodyBold)
                .foregroundColor(AppColor.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .background(AppColor.surface)
        .cornerRadius(Radius.lg)
        .semtioCardStyle()
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
    }
    
    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Kişisel Bilgiler")
                .font(AppFont.subheadline)
                .foregroundColor(AppColor.textSecondary)
                .padding(.horizontal, Spacing.md)
            
            VStack(spacing: 0) {
                // Name Field
                TextField("Ad Soyad", text: $fullName)
                    .font(AppFont.body)
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.md)
                
                Divider()
                    .padding(.leading, Spacing.md)
                
                // Username Field
                HStack {
                    Text("@")
                        .foregroundColor(AppColor.textSecondary)
                    TextField("kullaniciadi", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .font(AppFont.body)
                .padding(.vertical, Spacing.md)
                .padding(.horizontal, Spacing.md)
                
                Divider()
                    .padding(.leading, Spacing.md)
                
                // Bio Field
                TextField("Hakkımda (Bio)", text: $bio, axis: .vertical)
                    .font(AppFont.body)
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.md)
                    .lineLimit(3...6)
            }
            .background(AppColor.surface)
            .cornerRadius(Radius.lg)
            .semtioCardStyle()
            .padding(.horizontal, Spacing.md)
        }
    }
    
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
             Text("Gizlilik")
                 .font(AppFont.subheadline)
                 .foregroundColor(AppColor.textSecondary)
                 .padding(.horizontal, Spacing.md)
            
            VStack(spacing: 0) {
                Toggle("Herkese Açık Profil", isOn: $isProfilePublic)
                    .padding(Spacing.md)
                
                Divider()
                    .padding(.leading, Spacing.md)
                
                Toggle("Okundu Bilgisi", isOn: $readReceiptsEnabled)
                    .padding(Spacing.md)
            }
            .background(AppColor.surface)
            .cornerRadius(Radius.lg)
            .semtioCardStyle()
            .padding(.horizontal, Spacing.md)
        }
    }

    
    private func saveProfile() {
        guard !fullName.isEmpty else { return }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            await userStore.saveProfile(
                displayName: fullName,
                username: username.isEmpty ? nil : username,
                bio: bio,
                avatarImage: selectedImage,
                isProfilePublic: isProfilePublic,
                readReceiptsEnabled: readReceiptsEnabled
            )
            
            // Brief delay for UX
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            isSaving = false
            dismiss()
        }
    }
}
