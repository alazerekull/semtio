//
//  SecondaryButton.swift
//  SemtioApp
//
//  Created by Design System Refactor.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                    }
                    Text(title)
                        .font(AppFont.bodyBold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: ComponentSize.buttonHeight)
            .background(AppColor.surface)
            .foregroundColor(AppColor.primary)
            .cornerRadius(ComponentSize.buttonHeight / 2)
            .overlay(
                RoundedRectangle(cornerRadius: ComponentSize.buttonHeight / 2)
                    .stroke(AppColor.primary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLoading)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack {
        SecondaryButton(title: "Cancel", icon: "xmark", action: {})
            .padding()
            .background(Color.gray.opacity(0.1))
    }
}
