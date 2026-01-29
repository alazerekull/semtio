//
//  LoadingStateView.swift
//  SemtioApp
//
//  Created by Design System Refactor.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct LoadingStateView: View {
    var message: String? = nil
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColor.primary)
            
            if let message = message {
                Text(message)
                    .font(AppFont.caption)
                    .foregroundColor(AppColor.textSecondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LoadingStateView(message: "Yükleniyor...")
}
