//
//  SubplaceTag.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

// MARK: - Subplace Tag

struct SubplaceTag: View {
    let name: String
    var isHighlighted: Bool = false
    
    var body: some View {
        Text(name)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(isHighlighted ? .white : .white.opacity(0.8))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(
                        isHighlighted
                            ? Color.semtioPrimary.opacity(0.6)
                            : Color.white.opacity(0.15)
                    )
            )
    }
}

#Preview {
    ZStack {
        Color.purple.opacity(0.8)
        VStack {
            SubplaceTag(name: "Moda")
            SubplaceTag(name: "Fenerbahçe", isHighlighted: true)
            SubplaceTag(name: "Yeldeğirmeni Mahallesi")
        }
    }
}
