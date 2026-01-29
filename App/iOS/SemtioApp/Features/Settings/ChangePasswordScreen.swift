//
//  ChangePasswordScreen.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct ChangePasswordScreen: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                if !auth.hasPasswordProvider {
                    // Non-password provider fallback
                    VStack(spacing: 16) {
                        Image(systemName: "shield.righthalf.filled")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("Şifre Yönetimi")
                            .font(.headline)
                        
                        Text("Hesabına \(auth.authProviderName) ile giriş yaptın. Şifreni \(auth.authProviderName) hesabın üzerinden yönetebilirsin.")
                            .font(.body)
                            .foregroundColor(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                    
                } else {
                    // Password Form
                    VStack(spacing: 20) {
                        
                        // Current Password
                        SecureField("Mevcut Şifre", text: $currentPassword)
                            .textContentType(.password)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        
                        Divider()
                        
                        // New Password
                        VStack(spacing: 8) {
                            SecureField("Yeni Şifre", text: $newPassword)
                                .textContentType(.newPassword)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            
                            SecureField("Yeni Şifre (Tekrar)", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                
                            Text("En az 8 karakter, 1 harf ve 1 rakam içermelidir.")
                                .font(.caption)
                                .foregroundColor(AppColor.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: changePassword) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Şifreyi Güncelle")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValid ? Color.blue : AppColor.textSecondary.opacity(0.5))
                        .foregroundColor(AppColor.onPrimary)
                        .cornerRadius(12)
                        .disabled(!isValid || isLoading)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Şifre Değiştir")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Şifre Güncellendi", isPresented: $showSuccessAlert) {
            Button("Tamam") {
                dismiss()
            }
        }
    }
    
    // MARK: - Logic
    
    private var isValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword
    }
    
    private func changePassword() {
        guard isValid else { return }
        
        // Basic Validation
        guard newPassword == confirmPassword else {
            errorMessage = "Şifreler uyuşmuyor."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 1. Re-authenticate
                try await auth.reauthenticateWithPassword(currentPassword: currentPassword)
                
                // 2. Update Password
                try await auth.updatePassword(newPassword: newPassword)
                
                showSuccessAlert = true
            } catch {
                print("❌ Password change error: \(error)")
                errorMessage = mapError(error)
            }
            isLoading = false
        }
    }
    
    private func mapError(_ error: Error) -> String {
        // Firebase Auth specific errors usually map well, but we can customize
        let nsError = error as NSError
        if nsError.domain == "FIRAuthErrorDomain" {
            if nsError.code == 17009 { // ERROR_WRONG_PASSWORD (check actual code if needed)
                return "Mevcut şifre yanlış."
            }
        }
        return error.localizedDescription
    }
}
