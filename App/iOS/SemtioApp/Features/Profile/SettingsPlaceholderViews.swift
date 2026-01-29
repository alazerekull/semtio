//
//  SettingsPlaceholderViews.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

// MARK: - Settings View (Full Implementation)

// MARK: - Settings View (Removed - Moved to Features/Settings/SettingsView.swift)

// MARK: - Other Settings Views

struct PremiumView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Semtio Premium")
                .font(.title)
                .bold()
            
            Text("Yakında geliyor! Premium özelliklere erişmek için takipte kalın.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding(.top, 60)
        .background(Color.semtioBackground)
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// NOTE: PrivacyView is now in its own file: PrivacyView.swift

struct NotificationsSettingsView: View {
    @State private var pushEnabled = true
    @State private var emailEnabled = false
    @State private var eventReminders = true
    
    var body: some View {
        Form {
            Section(header: Text("Bildirim Ayarları")) {
                Toggle("Push Bildirimleri", isOn: $pushEnabled)
                Toggle("E-posta Bildirimleri", isOn: $emailEnabled)
                Toggle("Etkinlik Hatırlatıcıları", isOn: $eventReminders)
            }
        }
        .navigationTitle("Bildirimler")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ContactUsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 50))
                .foregroundColor(.semtioPrimary)
            
            Text("Bize Ulaşın")
                .font(.title2)
                .bold()
            
            Text("Sorularınız veya geri bildirimleriniz için:")
                .foregroundColor(.gray)
            
            Link("destek@semtio.app", destination: URL(string: "mailto:destek@semtio.app")!)
                .font(.headline)
                .foregroundColor(.semtioPrimary)
            
            Spacer()
        }
        .padding(.top, 60)
        .background(Color.semtioBackground)
        .navigationTitle("İletişim")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpView: View {
    var body: some View {
        PlaceholderSettingsScreen(
            title: "Yardım",
            icon: "questionmark.circle.fill",
            description: "Sık sorulan sorular ve yardım rehberi."
        )
    }
}

// MARK: - Reusable Placeholder

struct PlaceholderSettingsScreen: View {
    let title: String
    let icon: String
    let description: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.semtioPrimary)
            
            Text(title)
                .font(.title2)
                .bold()
            
            Text(description)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding(.top, 60)
        .background(Color.semtioBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
