//
//  FlowLayout.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  A flexible flow layout that wraps items to the next line when needed.
//

import SwiftUI

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var alignment: HorizontalAlignment = .leading
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentRowWidth + size.width + spacing > containerWidth && currentRowWidth > 0 {
                // Move to next row
                height += currentRowHeight + spacing
                currentRowWidth = size.width + spacing
                currentRowHeight = size.height
            } else {
                currentRowWidth += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }
        
        height += currentRowHeight
        
        return CGSize(width: containerWidth, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var currentRowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                // Move to next row
                currentX = bounds.minX
                currentY += currentRowHeight + spacing
                currentRowHeight = 0
            }
            
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            
            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

// MARK: - Fallback for iOS 15

struct WrapStack<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    
    init(spacing: CGFloat = 6, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            FlowLayout(spacing: spacing) {
                content()
            }
        } else {
            // iOS 15 fallback - simple HStack with scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    content()
                }
            }
        }
    }
}
