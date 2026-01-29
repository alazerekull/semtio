//
//  CategoryFilterView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct CategoryFilterView: View {
    @Binding var selectedCategory: EventCategory?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "All" chip
                FilterCategoryChip(
                    title: "Tümü",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )
                
                // Category chips
                ForEach(EventCategory.allCases) { category in
                    FilterCategoryChip(
                        title: category.localizedName,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FilterCategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.semtioPrimary : Color.white)
            .foregroundColor(isSelected ? .white : .semtioDarkText)
            .cornerRadius(20)
            .shadow(color: .black.opacity(isSelected ? 0.15 : 0.05), radius: 6, x: 0, y: 2)
        }
    }
}
