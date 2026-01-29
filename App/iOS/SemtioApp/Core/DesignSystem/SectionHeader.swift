//
//  SectionHeader.swift
//  SemtioApp
//
//  Created by Design System Refactor.
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(AppFont.headline)
                .foregroundColor(AppColor.textPrimary)
            
            Spacer()
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppFont.subheadline)
                        .foregroundColor(AppColor.primaryFallback)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}
