//
//  TabBarHeightPreference.swift
//  SemtioApp
//
//  Created for SemtioApp
//

import SwiftUI

// MARK: - Preference Key

/// Preference key to bubble up the Tab Bar height from the tab bar component to its container.
struct TabBarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Environment Key

/// Environment key to propagate the measured Tab Bar height down to child views.
struct TabBarHeightEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// The dynamic height of the custom floating tab bar.
    var tabBarHeight: CGFloat {
        get { self[TabBarHeightEnvironmentKey.self] }
        set { self[TabBarHeightEnvironmentKey.self] = newValue }
    }
}
