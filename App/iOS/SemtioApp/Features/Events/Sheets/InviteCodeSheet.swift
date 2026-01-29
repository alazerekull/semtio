//
//  InviteCodeSheet.swift
//  SemtioApp
//
//  Created for Events V2 Feature.
//

import SwiftUI

struct InviteCodeSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var inviteCode: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMsg: String?
    
    // Dependencies (could be injected via ViewModel)
    private let inviteRepo: InviteRepositoryProtocol = FirestoreInviteRepository()
    @EnvironmentObject var userStore: UserStore
    
    var body: some View {
        NavigationView {
            VStack(spacing: Spacing.lg) {
                Spacer()
                
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 64))
                    .foregroundColor(AppColor.primaryFallback)
                    .padding(.bottom, Spacing.md)
                
                Text("Davet Kodunu Gir")
                    .font(AppFont.headline)
                    .foregroundColor(AppColor.textPrimary)
                
                Text("Özel bir etkinliğe katılmak için organizatörden aldığın kodu gir.")
                    .font(AppFont.caption)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField("Kod (ör: XY92K)", text: $inviteCode)
                    .font(AppFont.subheadline)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(AppColor.surface)
                    .cornerRadius(Radius.md)
                    .padding(.horizontal, Spacing.lg)
                    .textInputAutocapitalization(.characters)
                
                if let error = errorMsg {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Button(action: redeemCode) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Katıl")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(inviteCode.isEmpty ? AppColor.textSecondary : AppColor.primaryFallback)
                .foregroundColor(AppColor.onPrimary)
                .cornerRadius(Radius.lg)
                .padding(.horizontal, Spacing.lg)
                .disabled(inviteCode.isEmpty || isLoading)
                
                Spacer()
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { dismiss() }
                }
            }
        }
    }
    
    private func redeemCode() {
        guard !inviteCode.isEmpty else { return }
        
        Task {
            isLoading = true
            errorMsg = nil
            do {
                if let _ = try await inviteRepo.redeemInviteCode(code: inviteCode, userId: userStore.currentUser.id) {
                    // Success - navigate to event or show success
                    // For now, just dismiss. Ideally inform parent to open event.
                    dismiss()
                } else {
                    errorMsg = "Geçersiz veya süresi dolmuş kod."
                }
            } catch {
                errorMsg = "Bir hata oluştu. Tekrar dene."
            }
            isLoading = false
        }
    }
}
