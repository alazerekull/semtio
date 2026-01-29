//
//  SettingsMenuView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct SettingsMenuView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            Color.semtioBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // List Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Menu Card
                        VStack(spacing: 0) {
                            Group {
                                SettingsRowLink(title: "Ayarlar", destination: SettingsView())
                                Divider().padding(.leading, 16)
                                
                                // Premium Row with dynamic status
                                PremiumSettingsRow(
                                    isPremium: appState.subscription.isPremium,
                                    onTap: { appState.presentPaywall() }
                                )
                                Divider().padding(.leading, 16)
                                
                                SettingsRowLink(title: "Gizlilik", destination: PrivacyView())
                                Divider().padding(.leading, 16)
                                
                                SettingsRowLink(title: "Bildirimler", destination: NotificationsSettingsView())
                                Divider().padding(.leading, 16)
                                
                                SettingsRowLink(title: "Bize Ulaşın", destination: ContactUsView())
                                Divider().padding(.leading, 16)
                                
                                SettingsRowLink(title: "Yardım", destination: HelpView())
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(20)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        Spacer()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Ayarlar")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(AppFont.calloutBold)
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                }
            }
        }
    }
}

// MARK: - Premium Settings Row

struct PremiumSettingsRow: View {
    let isPremium: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            if isPremium {
                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            } else {
                onTap()
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                        
                        Text("Semtio Premium")
                            .font(AppFont.callout)
                            .foregroundColor(.semtioDarkText)
                    }
                    
                    Text(isPremium ? "Aboneliği Yönet" : "Premium'a Geç")
                        .font(AppFont.caption)
                        .foregroundColor(isPremium ? .gray : .gray)
                }
                
                Spacer()
                
                if isPremium {
                    Image(systemName: "checkmark.seal.fill")
                        .font(AppFont.callout)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Row Link

struct SettingsRowLink<Destination: View>: View {
    let title: String
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Text(title)
                    .font(AppFont.callout)
                    .foregroundColor(.semtioDarkText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
