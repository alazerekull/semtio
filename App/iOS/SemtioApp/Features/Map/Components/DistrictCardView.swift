//
//  DistrictCardView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct DistrictCardView: View {
    let districtName: String
    let neighborhoods: [String]
    var onNeighborhoodTap: ((String) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // District Title
            HStack(spacing: Spacing.sm) {
                Text(districtName.uppercased())
                    .font(AppFont.title)
                    .foregroundColor(AppColor.onPrimary)
                
                Image(systemName: "location.fill")
                    .font(AppFont.callout)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Neighborhood Chips
            if !neighborhoods.isEmpty {
                FlowLayout(spacing: Spacing.sm) {
                    ForEach(neighborhoods, id: \.self) { neighborhood in
                        NeighborhoodChip(name: neighborhood) {
                            onNeighborhoodTap?(neighborhood)
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
    }
}

#Preview {
    ZStack {
        Color.purple.opacity(0.7)
        DistrictCardView(
            districtName: "Maltepe",
            neighborhoods: ["Bağlarbaşı", "Cevizli", "İdealtepe", "Küçükyalı", "Altıntepe"]
        )
    }
}
