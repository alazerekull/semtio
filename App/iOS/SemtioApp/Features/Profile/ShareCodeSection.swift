//
//  ShareCodeSection.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct ShareCodeSection: View {
    @EnvironmentObject var userStore: UserStore
    @State private var shareCode: String = ""
    @State private var isLoading = false
    @State private var showCopiedToast = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.rectangle")
                    .foregroundColor(.semtioPrimary)
                Text("Paylaş Kodu")
                    .font(AppFont.headline)
                    .foregroundColor(.semtioDarkText)
            }
            
            VStack(spacing: 12) {
                // Code Display
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if !shareCode.isEmpty {
                    Text(shareCode)
                        .font(AppFont.title2)
                        .foregroundColor(.semtioPrimary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.semtioPrimary.opacity(0.1))
                        .cornerRadius(12)
                } else {
                    Text("Kod yükleniyor...")
                        .foregroundColor(.gray)
                        .padding()
                }
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button(action: copyCode) {
                        Label("Kopyala", systemImage: "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColor.onPrimary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.semtioPrimary)
                            .cornerRadius(12)
                    }
                    .disabled(shareCode.isEmpty)
                    
                    Button(action: shareCodeAction) {
                        Label("Paylaş", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.semtioPrimary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.semtioPrimary.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .disabled(shareCode.isEmpty)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .overlay(
            Group {
                if showCopiedToast {
                    VStack {
                        Spacer()
                        Text("Kopyalandı!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColor.onPrimary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .padding(.bottom, 20)
                }
            }
        )
        .animation(.easeInOut, value: showCopiedToast)
        .task {
            await loadShareCode()
        }
    }
    
    private func loadShareCode() async {
        isLoading = true
        if let code = await userStore.ensureShareCode() {
            shareCode = code
        }
        isLoading = false
    }
    
    private func copyCode() {
        UIPasteboard.general.string = shareCode
        showCopiedToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }
    
    private func shareCodeAction() {
        let text = "Semtio'da beni ekle: \(shareCode)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
