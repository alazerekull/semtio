//
//  Colors.swift
//  SemtioApp
//
//  Created by Design System Architect.
//  Copyright © 2026 Oguzhan Cankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

/// Centralized Color System
/// wraps semantic names to dynamic colors (Assets or System)
enum AppColor {
    static var primary: Color {
        // Color("SemtioPrimary", bundle: nil)
        Color(hex: "6D28D9") // Purple
    }
    
    static var onPrimary: Color {
        // Color("SemtioOnPrimary", bundle: nil)
        Color.white
    }
    
    static var secondary: Color {
        // Color("SemtioSecondary", bundle: nil)
        Color(hex: "A855F7") // Lighter Purple
    }
    
    static var accent: Color {
        // Color("SemtioAccent", bundle: nil)
        Color(hex: "10B981") // Emerald Green
    }
    
    // MARK: - Backgrounds
    
    static var background: Color {
        Color(uiColor: .systemGroupedBackground)
    }
    
    static var surface: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }
    
    static var surfaceSecondary: Color {
        Color(uiColor: .tertiarySystemGroupedBackground)
    }
    
    // Alias for compatibility
    static var surface2: Color {
        surfaceSecondary
    }
    
    // MARK: - Text
    
    static var textPrimary: Color {
        Color.primary
    }
    
    static var textSecondary: Color {
        Color.secondary
    }
    
    static var textMuted: Color {
        Color(uiColor: .tertiaryLabel)
    }
    
    // MARK: - UI Elements
    
    static var divider: Color {
        Color(uiColor: .opaqueSeparator)
    }
    
    static var border: Color {
        Color(uiColor: .separator)
    }
    
    // MARK: - Semantic
    
    static var error: Color {
        Color.red
    }
    
    static var success: Color {
        Color.green
    }
    
    static var warning: Color {
        Color.orange
    }
    
    static var overlay: Color {
        Color.black.opacity(0.4)
    }
    
    // MARK: - Legacy / Fallbacks (To be removed) 
    static let primaryFallback = Color(hex: "6D28D9")
}
