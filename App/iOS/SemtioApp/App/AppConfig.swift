//
//  AppConfig.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  CENTRALIZED DATA SOURCE CONFIGURATION
//  Change `dataSource` to switch between mock and Firestore across the entire app.
//

import Foundation

// MARK: - Data Source Mode

/// Defines the data source for the entire application.
/// Change this single value to switch ALL repositories between mock and Firestore.
enum DataSourceMode {
    case mock
    case firestore
}

// MARK: - App Configuration

struct AppConfig {
    
    /// 🔌 PRODUCTION SETTING: Firestore is the default for production builds.
    private static let productionDataSource: DataSourceMode = .firestore
    
    /// ✅ RESOLVED DATA SOURCE: Use this everywhere instead of accessing productionDataSource directly.
    /// Returns .mock when running in SwiftUI Preview mode, otherwise returns production setting.
    static var dataSource: DataSourceMode {
        if isRunningInPreview {
            return .mock
        }
        return productionDataSource
    }
    
    /// Detects if app is running in SwiftUI Preview mode
    static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    /// Debug flag - enables additional logging
    static let isDebugMode: Bool = true
    
    /// App version info
    static let appVersion = "2.0.0"
}
