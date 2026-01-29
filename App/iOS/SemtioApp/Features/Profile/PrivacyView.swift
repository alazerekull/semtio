//
//  PrivacyView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var auth: AuthManager
    
    @State private var isProfilePublic: Bool = true
    @State private var isLoadingPrivacy = true
    @State private var isSavingPrivacy = false
    @State private var showPasswordSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    
    private var userId: String {
        auth.uid ?? ""
    }
    
    var body: some View {
        List {
            // MARK: - Profil Görünürlüğü
            Section(header: Text("Profil Görünürlüğü"), footer: privacyFooter) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profilim Herkese Açık")
                            .font(.body)
                        
                        Text(isProfilePublic ? "Açık" : "Kapalı")
                            .font(.caption)
                            .foregroundColor(isProfilePublic ? .green : .red)
                    }
                    
                    Spacer()
                    
                    if isLoadingPrivacy {
                        ProgressView()
                    } else {
                        Toggle("", isOn: $isProfilePublic)
                            .labelsHidden()
                            .disabled(isSavingPrivacy)
                            .onChange(of: isProfilePublic) { _, newValue in
                                savePrivacySetting(isPublic: newValue)
                            }
                    }
                }
            }
            
            // MARK: - Şifre Değiştir
            Section(header: Text("Güvenlik")) {
                if auth.hasPasswordProvider {
                    Button {
                        showPasswordSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.semtioPrimary)
                                .frame(width: 24)
                            
                            Text("Şifre Değiştir")
                                .foregroundColor(AppColor.textPrimary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(AppColor.accent)
                            Text("Şifre Değiştirme")
                                .font(.headline)
                        }
                        
                        Text("Bu hesap \(auth.authProviderName) ile bağlı; şifre Firebase'de tutulmuyor.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // MARK: - Hesap Bilgileri
            Section(header: Text("Hesap")) {
                HStack {
                    Text("Giriş Yöntemi")
                    Spacer()
                    Text(auth.authProviderName)
                        .foregroundColor(.gray)
                }
                
                if let email = auth.email {
                    HStack {
                        Text("E-posta")
                        Spacer()
                        Text(email)
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Gizlilik")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPrivacySetting()
        }
        .sheet(isPresented: $showPasswordSheet) {
            ChangePasswordSheet()
        }
        .alert("Hata", isPresented: $showErrorAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Bilinmeyen bir hata oluştu.")
        }
    }
    
    private var privacyFooter: some View {
        Text(isProfilePublic
            ? "Profiliniz tüm kullanıcılar tarafından görülebilir."
            : "Profiliniz sadece arkadaşlarınız tarafından görülebilir.")
    }
    
    // MARK: - Data Operations
    
    private func loadPrivacySetting() async {
        guard !userId.isEmpty else {
            isLoadingPrivacy = false
            return
        }
        
        do {
            let isPublic = try await appState.userStore.repo.fetchProfilePrivacy(uid: userId)
            isProfilePublic = isPublic
        } catch {
            print("⚠️ PrivacyView: Failed to load privacy: \(error)")
        }
        isLoadingPrivacy = false
    }
    
    private func savePrivacySetting(isPublic: Bool) {
        guard !userId.isEmpty else { return }
        
        isSavingPrivacy = true
        
        Task {
            do {
                try await appState.userStore.repo.updateProfilePrivacy(uid: userId, isPublic: isPublic)
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
                // Revert on error
                isProfilePublic = !isPublic
            }
            isSavingPrivacy = false
        }
    }
}

// MARK: - Change Password Sheet

struct ChangePasswordSheet: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Mevcut Şifre")) {
                    SecureField("Mevcut şifrenizi girin", text: $currentPassword)
                }
                
                Section(header: Text("Yeni Şifre"), footer: Text("En az 8 karakter olmalı.")) {
                    SecureField("Yeni şifre", text: $newPassword)
                    SecureField("Yeni şifre (tekrar)", text: $confirmPassword)
                }
                
                Section {
                    Button {
                        changePassword()
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Şifreyi Değiştir")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .navigationTitle("Şifre Değiştir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { dismiss() }
                }
            }
            .alert("Hata", isPresented: $showError) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Bilinmeyen bir hata oluştu.")
            }
            .alert("Başarılı", isPresented: $showSuccess) {
                Button("Tamam") { dismiss() }
            } message: {
                Text("Şifreniz başarıyla değiştirildi.")
            }
        }
    }
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword
    }
    
    private func changePassword() {
        // Validation
        guard newPassword.count >= 8 else {
            errorMessage = PasswordError.passwordTooShort.errorDescription
            showError = true
            return
        }
        
        guard newPassword == confirmPassword else {
            errorMessage = PasswordError.passwordMismatch.errorDescription
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Step 1: Re-authenticate
                try await auth.reauthenticateWithPassword(currentPassword: currentPassword)
                
                // Step 2: Update password
                try await auth.updatePassword(newPassword: newPassword)
                
                isLoading = false
                showSuccess = true
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
