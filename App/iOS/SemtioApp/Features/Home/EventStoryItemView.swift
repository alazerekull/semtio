//
//  EventStoryItemView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct EventStoryItemView: View {
    let event: Event?
    let isCreateButton: Bool
    let onTap: () -> Void
    
    init(event: Event? = nil, isCreateButton: Bool = false, onTap: @escaping () -> Void) {
        self.event = event
        self.isCreateButton = isCreateButton
        self.onTap = onTap
    }
    
    private let storySize: CGFloat = 68
    private let ringWidth: CGFloat = 3
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.sm) {
                ZStack {
                    if isCreateButton {
                        // Create Event Button
                        Circle()
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                            )
                            .foregroundColor(AppColor.primaryFallback)
                            .frame(width: storySize, height: storySize)
                        
                        Image(systemName: "plus")
                            .font(AppFont.title2)
                            .foregroundColor(AppColor.primaryFallback)
                    } else if let event = event {
                        // Event Story Ring (Gradient)
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.purple, Color.pink, Color.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: ringWidth
                            )
                            .frame(width: storySize, height: storySize)
                        
                        // Inner Content (Icon or Image)
                        ZStack {
                            Circle()
                                .fill(Color(hex: event.coverColorHex ?? "#8A2BE2")) // Default purple if nil
                            
                            Image(systemName: event.category.icon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(width: storySize - 8, height: storySize - 8)
                        .clipShape(Circle())
                    }
                }
                
                // Label
                Text(isCreateButton ? "Oluştur" : (event?.title ?? ""))
                    .font(AppFont.caption)
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)
                    .frame(width: storySize)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
