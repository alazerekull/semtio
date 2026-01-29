//
//  CategoryShortcutList.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct CategoryShortcutList: View {
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(EventCategory.allCases) { category in
                    Button(action: {
                        selectCategoryAndNavigate(category)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 14))
                            Text(category.localizedName)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .foregroundColor(.semtioDarkText)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(AppColor.textSecondary.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private func selectCategoryAndNavigate(_ category: EventCategory) {
        // Set filter
        eventStore.selectedCategory = category
        // Reset district filter to avoid confusion
        eventStore.selectedDistrict = nil
        
        // Notify tab change
        appState.selectedTab = .events
        NotificationCenter.default.post(name: NSNotification.Name("ResetTab"), object: AppTab.events)
    }
}
