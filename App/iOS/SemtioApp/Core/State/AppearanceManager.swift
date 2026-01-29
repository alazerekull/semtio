//
//  AppearanceManager.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Manages app appearance mode (System/Light/Dark) with persistence.
//

import SwiftUI
import Combine

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "Sistem"
        case .light: return "Açık"
        case .dark: return "Koyu"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "iphone"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Appearance Manager

@MainActor
final class AppearanceManager: ObservableObject {
    @AppStorage("appearanceMode") private var storedMode: String = AppearanceMode.system.rawValue
    
    @Published var currentMode: AppearanceMode = .system
    
    init() {
        // Load from storage
        if let mode = AppearanceMode(rawValue: storedMode) {
            currentMode = mode
        }
    }
    
    var colorScheme: ColorScheme? {
        currentMode.colorScheme
    }
    
    func setMode(_ mode: AppearanceMode) {
        currentMode = mode
        storedMode = mode.rawValue
    }
}
