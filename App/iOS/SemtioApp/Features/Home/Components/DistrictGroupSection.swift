//
//  DistrictGroupSection.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct DistrictGroupSection: View {
    let districts: [DistrictSummary] = DistrictSummary.mockDistricts
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.semtioPrimary)
                Text("Semtler")
                    .font(AppFont.title3)
                    .foregroundColor(.semtioDarkText)
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(districts) { district in
                        NavigationLink(destination: DistrictDetailScreen(district: district)) {
                            DistrictCard(district: district)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct DistrictCard: View {
    let district: DistrictSummary
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: district.icon)
                .font(.system(size: 28))
                .foregroundColor(.semtioPrimary)
                .frame(width: 56, height: 56)
                .background(Color.semtioPrimary.opacity(0.1))
                .cornerRadius(16)
            
            Text(district.name)
                .font(AppFont.subheadline)
                .foregroundColor(.semtioDarkText)
            
            Text("\(district.eventCount) etkinlik")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(width: 100, height: 120)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}
