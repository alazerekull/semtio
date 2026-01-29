//
//  SettingsView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif

struct SettingsView: View {
    @EnvironmentObject var themeManager: AppThemeManager
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var appState: AppState
    
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    // Mail State
    @State private var showSupportOptions = false
    @State private var isShowingMailComposer = false
    @State private var isShowingMailAlert = false
    @State private var isNavigatingToSupportChat = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // MARK: - Theme Section
                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsSectionHeader(title: "Görünüm")
                        
                        ThemePicker(
                            selectedTheme: themeManager.theme,
                            onSelect: { themeManager.setTheme($0) }
                        )
                    }
                }
                
                // MARK: - Account Section
                AccountSettingsSection(
                    signOut: signOut,
                    showDeleteConfirm: $showDeleteConfirm,
                    isDeleting: isDeleting
                )
                
                // MARK: - Support Section
                SupportSettingsSection(
                    showSupportOptions: $showSupportOptions
                )
                
                // MARK: - Error Message
                if let errorMessage {
                    Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                }
                
                // MARK: - Debug Info (Anti-Gravity Fix)
                DebugSettingsSection()
                
                // MARK: - Version
                VStack(spacing: 4) {
                    Text("Semtio v1.0.0")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.gray)
                    Text("Made with ❤️ in Istanbul")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.6))
                }
                .padding(.top, 20)
                
                Spacer(minLength: 100)
            }
            .padding()
            // Navigation Link for Support Chat using navigationDestination
            .navigationDestination(isPresented: $isNavigatingToSupportChat) {
                SupportChatScreen()
            }
        }
        .onAppear {
            print("🎨 SettingsView themeManager:", ObjectIdentifier(themeManager))
        }
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
        // ALERTS & SHEETS
        .alert("Hesabı silmek istiyor musun?", isPresented: $showDeleteConfirm) {
            Button("Vazgeç", role: .cancel) {}
            Button("Sil", role: .destructive) {
                Task { await handleDelete() }
            }
        } message: {
            Text("Bu işlem geri alınamaz. Tüm verileriniz silinecektir.")
        }
        .confirmationDialog("Destek", isPresented: $showSupportOptions, titleVisibility: .visible) {
            Button("Uygulama İçi Sohbet") {
                isNavigatingToSupportChat = true
            }
            Button("Mail ile İletişim") {
                openSupportMail()
            }
            Button("İptal", role: .cancel) {}
        }
        .sheet(isPresented: $isShowingMailComposer) {
            MailComposer(
                isPresented: $isShowingMailComposer,
                recipients: ["semtioapp@gmail.com"],
                subject: "Semtio Destek",
                body: supportEmailBody
            )
        }
        .alert("Mail ayarlı değil", isPresented: $isShowingMailAlert) {
            Button("Kopyala") {
                UIPasteboard.general.string = "semtioapp@gmail.com"
            }
            Button("Mail'i Aç") {
            }
            Button("Kapat", role: .cancel) { }
        } message: {
            Text("semtioapp@gmail.com adresine mail atabilirsiniz.")
        }
    }

    private func openSupportMail() {
        if MailComposer.canSendMail() {
            isShowingMailComposer = true
        } else {
            isShowingMailAlert = true
        }
    }
    
    private var supportEmailBody: String {
        let device = UIDevice.current
        let systemName = device.systemName
        let systemVersion = device.systemVersion
        let model = device.model
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let userId = session.state == .signedIn ? (appState.auth.uid ?? "unknown") : "guest"
        
        return """
        
        ------------------------------
        App Version: \(version) (\(build))
        iOS: \(systemName) \(systemVersion)
        Device: \(model)
        User ID: \(userId)
        ------------------------------
        """
    }

    private func signOut() {
        Task {
        session.signOut()
        }
    }

    private func handleDelete() async {
        isDeleting = true
        errorMessage = nil
        do {
            try await deleteAccount()
            session.signOut()
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
        }
    }

    private func deleteAccount() async throws {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid

        // Delete Firestore Data
        try await Firestore.firestore().collection("users").document(uid).delete()
        
        // Delete Auth Account
        try await user.delete()
        #else
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        #endif
    }
}

// MARK: - Subviews

struct AccountSettingsSection: View {
    let signOut: () -> Void
    @Binding var showDeleteConfirm: Bool
    let isDeleting: Bool
    
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader(title: "Hesap")
                    .padding(.bottom, 12)
                
                // Sign Out
                Button(action: signOut) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(AppFont.callout)
                            .frame(width: 24)
                        Text("Çıkış Yap")
                            .font(AppFont.callout)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                    .foregroundColor(.red)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                
                // Change Password
                NavigationLink(destination: ChangePasswordScreen()) {
                    SettingsRowContent(
                        icon: "key.fill",
                        title: "Şifre Değiştir",
                        color: .orange
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                
                // Delete Account
                Button(action: { showDeleteConfirm = true }) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(AppFont.callout)
                            .frame(width: 24)
                        Text(isDeleting ? "Siliniyor..." : "Hesabımı Sil")
                            .font(AppFont.callout)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .disabled(isDeleting)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct SupportSettingsSection: View {
    @Binding var showSupportOptions: Bool
    
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionHeader(title: "Destek")
                    .padding(.bottom, 12)
                
                // Contact (Dialog)
                Button {
                    showSupportOptions = true
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .font(AppFont.callout)
                            .foregroundColor(AppColor.accent)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Destek")
                                .font(AppFont.callout)
                                .foregroundColor(AppColor.textPrimary)
                            Text("Bizimle iletişime geçin")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .padding(.leading, 32)
                
                // Privacy Policy
                Link(destination: URL(string: "https://semtio.app/privacy")!) {
                    SettingsRowContent(icon: "hand.raised.fill", title: "Gizlilik Politikası", color: .gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .padding(.leading, 32)
                
                // Terms of Use
                Link(destination: URL(string: "https://semtio.app/terms")!) {
                    SettingsRowContent(icon: "doc.text.fill", title: "Kullanım Şartları", color: .gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct DebugSettingsSection: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                SettingsSectionHeader(title: "DEBUG CONTROL")
                
                if let _ = FirebaseApp.app() {
                    Text("🔥 Firebase: CONFIGURED")
                        .foregroundColor(.green)
                } else {
                    Text("🔥 Firebase: NOT CONFIGURED")
                        .foregroundColor(.red)
                        .bold()
                }
                
                Text("👤 UID: \(appState.auth.uid ?? "nil")")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("💾 Repo: \(String(describing: AppConfig.dataSource))")
                    .font(.caption)
                    .foregroundColor(AppConfig.dataSource == .firestore ? .green : .orange)
                
                Text("⚡ SaveStatus: \(appState.userStore.lastSaveStatus)")
                    .font(.caption)
                    .foregroundColor(AppColor.accent)
                
                Text("📨 ThreadsIndex: \(appState.chat.threadsIndexStatus)")
                    .font(.caption)
                    .foregroundColor(appState.chat.threadsIndexStatus.contains("OK") ? .green : .red)
                
                Text("📅 EventsIndex: \(appState.events.eventsIndexStatus)")
                    .font(.caption)
                    .foregroundColor(appState.events.eventsIndexStatus.contains("OK") ? .green : .red)
            }
            .font(.system(size: 13, design: .monospaced))
        }
    }
}

// MARK: - Settings Row Content Helper
struct SettingsRowContent: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(AppFont.callout)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(AppFont.callout)
                .foregroundColor(AppColor.textPrimary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray.opacity(0.4))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Theme Picker (Pill Style)

struct ThemePicker: View {
    let selectedTheme: AppTheme
    let onSelect: (AppTheme) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTheme.allCases) { theme in
                ThemePillButton(
                    theme: theme,
                    isSelected: selectedTheme == theme,
                    onTap: { onSelect(theme) }
                )
            }
        }
        .padding(4)
        .background(Color(.systemGray5))
        .cornerRadius(12)
    }
}

struct ThemePillButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: theme.iconName)
                    .font(.system(size: 14, weight: .medium))
                Text(theme.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                isSelected
                    ? Color.semtioPrimary
                    : Color.clear
            )
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Settings Card

struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Settings Section Header

struct SettingsSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title.uppercased())
            .font(AppFont.captionBold)
            .foregroundColor(.gray)
            .tracking(0.5)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppThemeManager())
            .environmentObject(SessionManager())
            .environmentObject(AppState(
                session: SessionManager(),
                theme: AppThemeManager(),
                location: LocationManager()
            ))
    }
}
