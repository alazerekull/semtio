//
//  ProfileStatsView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Instagram-style stats row

import SwiftUI

struct ProfileStatsView: View {
    let createdCount: Int
    let joinedCount: Int
    let friendCount: Int
    
    var body: some View {
        HStack(spacing: 0) {
            StatItem(value: createdCount, label: "Etkinlik")
            StatItem(value: joinedCount, label: "Katılım")
            StatItem(value: friendCount, label: "Arkadaş")
        }
        .padding(.vertical, 12)
    }
}

private struct StatItem: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(AppFont.headline)
                .foregroundColor(AppColor.textPrimary)
            
            Text(label)
                .font(AppFont.caption)
                .foregroundColor(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfileStatsView(createdCount: 12, joinedCount: 48, friendCount: 156)
}
