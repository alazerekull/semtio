//
//  LoginScreen.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import AuthenticationServices

struct LoginScreen: View {
    @EnvironmentObject var appState: AppState
    @State private var currentNonce: String?
    
    // Animation States
    @State private var isLogoAnimated = false
    @State private var showButtons = false
    @State private var errorMessage: String?
    
    // Sign Up Sheet
    @State private var showSignUpSheet = false
    
    var body: some View {
        ZStack {
            // Background
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo Section
                VStack(spacing: 8) {
                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: isLogoAnimated ? 280 : 320, height: isLogoAnimated ? 140 : 160)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .offset(y: isLogoAnimated ? -20 : 0)
                
                Spacer()
                
                // Action Buttons
                if showButtons {
                    VStack(spacing: 20) {
                        Text("Hoş Geldiniz")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Text("Semtio dünyasına katılmak için giriş yapın.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 10)
                        
                        // Apple Sign In
                        SignInWithAppleButton(.signIn) { request in
                            let nonce = AuthUtils.randomNonceString()
                            currentNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = AuthUtils.sha256(nonce)
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        // Google Sign In
                        Button(action: {
                            Task { await appState.auth.signInWithGoogle() }
                        }) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                    .font(.title2)
                                Text("Google ile Giriş Yap")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(25)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        
                        // Email Sign Up / Sign In Button
                        Button(action: {
                            showSignUpSheet = true
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .font(.title2)
                                Text("E-posta ile Kayıt Ol")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(AppColor.onPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.semtioPrimary)
                            .cornerRadius(25)
                            .shadow(color: .semtioPrimary.opacity(0.3), radius: 5, x: 0, y: 2)
                        }
                        
                        // All users must sign in with Apple, Google, or Email
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Error Message Display
                if let error = appState.auth.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 10)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0)) {
                isLogoAnimated = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showButtons = true
                }
            }
        }
        .sheet(isPresented: $showSignUpSheet) {
            EmailAuthSheet()
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else { return }
                guard let appleIDToken = appleIDCredential.identityToken else { return }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else { return }
                
                Task {
                    await appState.auth.signInWithApple(idToken: idTokenString, nonce: nonce)
                }
            }
        case .failure(let error):
            print("Sign in with Apple failed: \(error.localizedDescription)")
            // TODO: Catch specific error code for existing account credential
            // NSError domain: FIRAuthErrorDomain code: 17012 (accountExistsWithDifferentCredential)
        }
    }
    
    // Internal helper to handle the linking logic if we want to auto-recover (future scope)
    func handleAuthError(_ error: Error) {
        let _ = error as NSError
        // if nsError.code == AuthErrorCode.accountExistsWithDifferentCredential.rawValue ...
        errorMessage = error.localizedDescription
    }
}

// MARK: - Email Authentication Sheet

struct EmailAuthSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var isSignUp = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Toggle Sign Up / Sign In
                Picker("", selection: $isSignUp) {
                    Text("Kayıt Ol").tag(true)
                    Text("Giriş Yap").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                VStack(spacing: 16) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("E-posta")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        TextField("ornek@email.com", text: $email)
                            .textFieldStyle(PlainTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding()
                            .background(AppColor.textSecondary.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Şifre")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        SecureField("En az 6 karakter", text: $password)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(AppColor.textSecondary.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Confirm Password (Sign Up only)
                    if isSignUp {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Şifre Tekrar")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            SecureField("Şifrenizi tekrar girin", text: $confirmPassword)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding()
                                .background(AppColor.textSecondary.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Submit Button
                Button(action: submit) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isSignUp ? "Kayıt Ol" : "Giriş Yap")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(AppColor.onPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isFormValid ? Color.semtioPrimary : AppColor.textSecondary)
                    .cornerRadius(25)
                }
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle(isSignUp ? "Hesap Oluştur" : "Giriş Yap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { dismiss() }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        
        if isSignUp {
            return emailValid && passwordValid && password == confirmPassword
        } else {
            return emailValid && passwordValid
        }
    }
    
    private func submit() {
        errorMessage = nil
        isLoading = true
        
        Task {
            let success: Bool
            
            if isSignUp {
                success = await appState.auth.signUpWithEmail(email: email, password: password)
            } else {
                success = await appState.auth.signInWithEmail(email: email, password: password)
            }
            
            isLoading = false
            
            if success {
                dismiss()
            } else {
                errorMessage = appState.auth.errorMessage ?? "Bir hata oluştu. Lütfen tekrar deneyin."
            }
        }
    }
}
