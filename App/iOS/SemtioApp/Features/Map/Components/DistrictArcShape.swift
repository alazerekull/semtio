//
//  DistrictArcShape.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

/// Custom shape with curved left edge for right-side overlay panel
struct DistrictArcShape: Shape {
    var curveRadius: CGFloat = 60
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start from top-left with arc
        path.move(to: CGPoint(x: curveRadius, y: 0))
        
        // Top edge
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        
        // Right edge
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        
        // Bottom edge
        path.addLine(to: CGPoint(x: curveRadius, y: rect.height))
        
        // Left curved edge (arc from bottom to top)
        path.addQuadCurve(
            to: CGPoint(x: curveRadius, y: 0),
            control: CGPoint(x: 0, y: rect.height / 2)
        )
        
        path.closeSubpath()
        return path
    }
}

#Preview {
    DistrictArcShape()
        .fill(
            LinearGradient(
                colors: [Color.purple.opacity(0.8), Color.purple.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .frame(width: 200, height: 400)
}
