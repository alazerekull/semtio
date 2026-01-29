//
//  EventCard.swift
//  SemtioApp
//
//  Created by Design System Refactor.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct EventCard: View {
    let event: Event
    var onTab: (() -> Void)?
    var actionButton: AnyView? = nil // Optional trailing button
    
    var body: some View {
        Button(action: { onTab?() }) {
            VStack(alignment: .leading, spacing: 0) {
                // Cover Image
                ZStack(alignment: .topTrailing) {
                    // Image Placeholder or Actual
                    Rectangle()
                        .fill(categoryColor.opacity(0.1))
                        .frame(height: 140)
                        .overlay(
                            Image(systemName: categoryIcon)
                                .font(.system(size: 40))
                                .foregroundColor(categoryColor.opacity(0.5))
                        )
                        // If we had image URL logic:
                        // AsyncImage...
                    
                    // Badges
                    HStack {
                        // Privacy Badge
                        if event.visibility == .private {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                Text("Private")
                                    .font(AppFont.captionBold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(Radius.sm)
                        }
                        
                        Spacer()
                        
                        // Date Badge
                        Text(event.dateString) // Assuming formatted helper
                            .font(AppFont.captionBold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColor.surface)
                            .cornerRadius(Radius.sm)
                            .shadow(radius: 2)
                    }
                    .padding(Spacing.md)
                }
                
                // Content
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(AppFont.headline)
                            .foregroundColor(AppColor.textPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption)
                            Text(event.locationName ?? "Unknown Location")
                                .font(AppFont.caption)
                        }
                        .foregroundColor(AppColor.textSecondary)
                        
                        // Host info logic could go here
                        Text("by \(event.createdBy)") // In real app: resolve name
                            .font(AppFont.caption)
                            .foregroundColor(AppColor.textMuted)
                            .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    if let action = actionButton {
                        action
                    }
                }
                .padding(Spacing.md)
            }
            .background(AppColor.surface)
            .cornerRadius(Radius.lg)
            .semtioShadow(.card)
        }
        .buttonStyle(ScaleButtonStyle()) // Using our custom style
        // Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), \(event.dateString) tarihinde, \(event.locationName ?? "Konum seçilmedi") konumunda.")
        .accessibilityHint("Detayları görmek için çift dokunun.")
        .accessibilityAddTraits(.isButton)
    }

    // Helpers (Should be shared/extensions ideally)
    private var categoryColor: Color {
        // Fallback or actual logic mapping category enum to Color
        return AppColor.primary
    }
    
    private var categoryIcon: String {
        return "star.fill"
    }
}

// Temporary Helper extension for date if not exists
extension Event {
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: startDate)
    }
}

#Preview {
    // Mock Data
    let event = Event(
        id: "1",
        title: "Sunset Yoga",
        description: "Join us",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        locationName: "Caddebostan Sahil",
        semtName: nil,
        hostUserId: nil,
        participantCount: 5,
        coverColorHex: nil,
        category: .sport,
        lat: 0,
        lon: 0,
        coverImageURL: nil,
        capacityLimit: nil,
        tags: [],
        isFeatured: false,
        createdBy: "user1",
        createdAt: Date(),
        district: nil,
        visibility: .public
    )
    
    EventCard(event: event)
        .padding()
}
