//
//  StoryOwnerBottomBar.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct StoryOwnerBottomBar: View {
    let viewCount: Int
    let onSwipeUp: () -> Void
    
    // Additional management actions
    let onDelete: () -> Void
    let onHighlight: () -> Void
    let onMore: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // "Swipe Up" Indicator for Viewers
            Button(action: onSwipeUp) {
                VStack(spacing: 4) {
                    Image(systemName: "chevron.up")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                        Text("\(viewCount) Görüntüleme")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.white)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.black.opacity(0.3))
                .cornerRadius(16)
            }
            
            // Management Row
            HStack(spacing: 24) {
                Button(action: onHighlight) {
                    VStack(spacing: 2) {
                        Image(systemName: "heart.circle") // Or highlight icon
                            .font(.title3)
                        Text("Highlight")
                            .font(.system(size: 10))
                    }
                }
                
                Button(action: onMore) {
                     VStack(spacing: 2) {
                         Image(systemName: "ellipsis.circle")
                             .font(.title3)
                         Text("Daha Fazla")
                             .font(.system(size: 10))
                     }
                }
                
                Spacer()
                
                Button(action: onDelete) {
                     VStack(spacing: 2) {
                         Image(systemName: "trash")
                             .font(.title3)
                         Text("Sil")
                             .font(.system(size: 10))
                     }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.bottom, 34) // Safe area
            .padding(.top, 8)
        }
        .background(
            LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()
        )
    }
}
