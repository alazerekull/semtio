//
//  NeighborhoodChip.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct NeighborhoodChip: View {
    let name: String
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() }) {
            Text(name)
                .font(AppFont.caption)
                .foregroundColor(AppColor.onPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColor.primaryFallback : Color.white.opacity(0.2))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        Color.purple.opacity(0.7)
        HStack {
            NeighborhoodChip(name: "Bağlarbaşı")
            NeighborhoodChip(name: "Cevizli", isSelected: true)
            NeighborhoodChip(name: "İdealtepe")
        }
    }
}
