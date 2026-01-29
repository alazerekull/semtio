//
//  DistrictChip.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

// MARK: - District Chip

struct DistrictChip: View {
    let district: DistrictItem
    let isSelected: Bool
    let isCenter: Bool  // User's location - most prominent
    let distanceFromCenter: Int  // 0 = center, 1 = adjacent, 2+ = further
    let onTap: () -> Void
    
    private var fontSize: CGFloat {
        if isCenter { return 20 }
        switch distanceFromCenter {
        case 1: return 16
        case 2: return 14
        default: return 13
        }
    }
    
    private var opacity: Double {
        if isCenter { return 1.0 }
        switch distanceFromCenter {
        case 1: return 0.85
        case 2: return 0.7
        default: return 0.55
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                // District Name
                HStack(spacing: 6) {
                    Text(district.name)
                        .font(.system(size: fontSize, weight: isCenter ? .bold : .semibold))
                        .foregroundColor(AppColor.onPrimary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .minimumScaleFactor(0.8)
                    
                    // Location icon for user's district
                    if district.isUserDistrict {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColor.onPrimary)
                    }
                }
                
                // Subplaces (only show for center or selected)
                if (isCenter || isSelected) && !district.subplaces.isEmpty {
                    WrapStack(spacing: 4) {
                        ForEach(district.subplaces.prefix(3), id: \.self) { place in
                            SubplaceTag(name: place, isHighlighted: isCenter)
                        }
                    }
                    .frame(maxWidth: 150)
                }
            }
            .padding(.horizontal, isCenter ? 16 : 12)
            .padding(.vertical, isCenter ? 12 : 8)
            .background(
                RoundedRectangle(cornerRadius: isCenter ? 16 : 12)
                    .fill(
                        isCenter
                            ? Color.white.opacity(0.25)
                            : (isSelected ? Color.white.opacity(0.15) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: isCenter ? 16 : 12)
                            .strokeBorder(
                                isSelected ? Color.white.opacity(0.4) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: isCenter ? .black.opacity(0.2) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(opacity)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.purple, .purple.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        VStack(spacing: 16) {
            DistrictChip(
                district: DistrictItem(name: "MALTEPE", subplaces: ["Cevizli", "Bağlarbaşı"], isUserDistrict: true),
                isSelected: false,
                isCenter: true,
                distanceFromCenter: 0,
                onTap: {}
            )
            DistrictChip(
                district: DistrictItem(name: "KADIKÖY", subplaces: ["Moda"]),
                isSelected: true,
                isCenter: false,
                distanceFromCenter: 1,
                onTap: {}
            )
            DistrictChip(
                district: DistrictItem(name: "BEŞİKTAŞ"),
                isSelected: false,
                isCenter: false,
                distanceFromCenter: 2,
                onTap: {}
            )
        }
    }
}
