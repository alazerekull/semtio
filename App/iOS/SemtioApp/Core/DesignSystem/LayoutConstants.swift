//
//  LayoutConstants.swift
//  SemtioApp
//
//  Created by Design System Architect.
//  Copyright © 2026 Oguzhan Cankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

/// Centralized Spacing Constants
struct Spacing {
    /// 4 pts
    static let xs: CGFloat = 4
    /// 8 pts
    static let sm: CGFloat = 8
    /// 16 pts
    static let md: CGFloat = 16
    /// 24 pts
    static let lg: CGFloat = 24
    /// 32 pts
    static let xl: CGFloat = 32
    /// 48 pts
    static let xxl: CGFloat = 48
}

/// Centralized Radius Constants
struct Radius {
    /// 8 pts
    static let sm: CGFloat = 8
    /// 14 pts
    static let md: CGFloat = 14
    /// 22 pts
    static let lg: CGFloat = 22
    /// 100 pts (Capsule-like)
    static let pill: CGFloat = 100
}

/// Centralized Component Sizes
struct ComponentSize {
    static let avatarSmall: CGFloat = 32
    static let avatarMedium: CGFloat = 48
    static let avatarLarge: CGFloat = 80
    static let buttonHeight: CGFloat = 50
    static let iconSmall: CGFloat = 24
}

// MARK: - View Modifiers (Previously here, now in ViewModifiers.swift)
// Removing duplicate declarations to fix "Ambiguous use" error.

