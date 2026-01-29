//
//  ViewModifiers.swift
//  SemtioApp
//
//  Created by Design System Architect.
//  Copyright © 2026 Oguzhan Cankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

// MARK: - Shadow System

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    static let none = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
    static let card = ShadowStyle(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    static let floating = ShadowStyle(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
}

struct ElevationModifier: ViewModifier {
    let style: ShadowStyle
    
    func body(content: Content) -> some View {
        content.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

extension View {
    /// Applies a standard shadow style from the Design System
    func semtioShadow(_ style: ShadowStyle = .card) -> some View {
        self.modifier(ElevationModifier(style: style))
    }
}

// MARK: - Card Styling

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColor.surface)
            .cornerRadius(Radius.md)
            .semtioShadow(.card)
    }
}

extension View {
    /// Applies the standard card look (Surface Color + Corner Radius + Shadow)
    func semtioCardStyle() -> some View {
        self.modifier(CardStyle())
    }
}
