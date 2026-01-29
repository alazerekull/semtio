//
//  RoundedCornersShape.swift
//  SemtioApp
//
//  Created by Antigravity on 2026-01-28.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct RoundedCornersShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
