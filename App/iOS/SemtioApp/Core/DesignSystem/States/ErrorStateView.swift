//
//  ErrorStateView.swift
//  SemtioApp
//
//  Created by Design System Refactor.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct ErrorStateView: View {
    var title: String = "Bir Hata Oluştu"
    var message: String = "Beklenmedik bir sorun meydana geldi."
    var retryAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColor.error.opacity(0.8))
                .padding(.bottom, Spacing.sm)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(AppFont.headline)
                    .foregroundColor(AppColor.textPrimary)
                
                Text(message)
                    .font(AppFont.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if let retry = retryAction {
                SecondaryButton(title: "Tekrar Dene", icon: "arrow.clockwise", action: retry)
                    .frame(width: 160)
                    .padding(.top, Spacing.md)
            }
            
            Spacer()
        }
        .padding(Spacing.lg)
    }
}

#Preview {
    ErrorStateView(
        message: "Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol ediniz.",
        retryAction: {}
    )
}
