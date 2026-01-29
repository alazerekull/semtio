//
//  AppThemeManager.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import Combine

// MARK: - App Theme Enum

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "Açık"
    case dark = "Koyu"
    
    var id: String { rawValue }
    
    /// SF Symbol for theme icon
    var iconName: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    /// Color scheme for SwiftUI's preferredColorScheme modifier
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Theme Manager (Global, Observable)

final class AppThemeManager: ObservableObject {
    @AppStorage("appTheme") private var themeRaw: String = AppTheme.dark.rawValue
    
    init() {
        print("🎨 AppThemeManager init:", ObjectIdentifier(self))
    }
    
    /// Current theme selection
    var theme: AppTheme {
        get { AppTheme(rawValue: themeRaw) ?? .dark }
        set {
            themeRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    /// Color scheme for SwiftUI's preferredColorScheme modifier
    var colorScheme: ColorScheme? {
        theme.colorScheme
    }
    
    /// Updates theme with haptic feedback
    func setTheme(_ newTheme: AppTheme) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.25)) {
            theme = newTheme
        }
        
        print("🎨 Theme changed to \(newTheme.rawValue) -> colorScheme=\(String(describing: newTheme.colorScheme))")
    }
}
