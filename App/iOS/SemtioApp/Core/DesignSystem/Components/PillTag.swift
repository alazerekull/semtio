//
//  PillTag.swift
//  SemtioApp
//
//  Created by Design System Refactor.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct PillTag: View {
    let text: String
    var icon: String? = nil
    var isSelected: Bool = false
    var color: Color = AppColor.primary
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(text)
                    .font(AppFont.captionBold)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(isSelected ? color : AppColor.surface)
            .foregroundColor(isSelected ? .white : AppColor.textSecondary)
            .cornerRadius(Radius.pill)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.pill)
                    .stroke(isSelected ? Color.clear : AppColor.border, lineWidth: 1)
            )
        }
        .disabled(action == nil)
    }
}

#Preview {
    HStack {
        PillTag(text: "Music", icon: "music.note", isSelected: true)
        PillTag(text: "Sport", icon: "figure.run", isSelected: false)
    }
    .padding()
}
