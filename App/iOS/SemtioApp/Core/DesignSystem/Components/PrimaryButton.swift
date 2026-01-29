//
//  PrimaryButton.swift
//  SemtioApp
//
//  Created by Design System Refactor.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(AppColor.onPrimary)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text(title)
                        .font(AppFont.bodyBold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: ComponentSize.buttonHeight)
            .background(isDisabled ? AppColor.secondary.opacity(0.3) : AppColor.primary)
            .foregroundColor(isDisabled ? AppColor.textMuted : AppColor.onPrimary)
            .cornerRadius(ComponentSize.buttonHeight / 2)
            .overlay(
                RoundedRectangle(cornerRadius: ComponentSize.buttonHeight / 2)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .semtioShadow(isDisabled ? .none : .floating)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLoading || isDisabled)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "Lütfen bekleyin" : "")
        .accessibilityAddTraits(.isButton)
    }
}



#Preview {
    VStack {
        PrimaryButton(title: "Save Changes", icon: "checkmark", action: {})
            .padding()
        PrimaryButton(title: "Loading...", isLoading: true, action: {})
            .padding()
        PrimaryButton(title: "Disabled", isDisabled: true, action: {})
            .padding()
    }
}
