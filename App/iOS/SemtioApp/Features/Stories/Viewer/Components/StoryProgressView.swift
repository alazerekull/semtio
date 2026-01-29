//
//  StoryProgressView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct StoryProgressView: View {
    let storiesCount: Int
    let currentIndex: Int
    let currentProgress: CGFloat
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<storiesCount, id: \.self) { index in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                        
                        // Fill
                        if index < currentIndex {
                            Capsule()
                                .fill(Color.white)
                        } else if index == currentIndex {
                            Capsule()
                                .fill(Color.white)
                                .frame(width: geo.size.width * currentProgress)
                        }
                    }
                }
                .frame(height: 3)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 8)
        .padding(.top, 8) // Safe area padding handled by parent usually
    }
}
