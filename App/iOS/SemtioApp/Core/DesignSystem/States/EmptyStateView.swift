//
//  EmptyStateView.swift
//  SemtioApp
//
//  Created by Design System Refactor.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct EmptyStateView: View {
    var iconName: String = "tray"
    var title: String = "Burada bir şey yok"
    var subtitle: String = "Henüz eklenmiş bir içerik bulunmuyor."
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(AppColor.surface2)
                    .frame(width: 100, height: 100)
                
                Image(systemName: iconName)
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColor.textSecondary.opacity(0.5), AppColor.textSecondary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(AppFont.headline)
                    .foregroundColor(AppColor.textPrimary)
                
                Text(subtitle)
                    .font(AppFont.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if let btnTitle = actionTitle, let btnAction = action {
                PrimaryButton(title: btnTitle, action: btnAction)
                    .frame(width: 200)
                    .padding(.top, Spacing.md)
            }
            
            Spacer()
        }
        .padding(Spacing.lg)
    }
}

#Preview {
    EmptyStateView(
        iconName: "network",
        title: "Bağlantı Yok",
        subtitle: "Lütfen internet bağlantınızı kontrol edip tekrar deneyin.",
        actionTitle: "Tekrar Dene",
        action: {}
    )
}
