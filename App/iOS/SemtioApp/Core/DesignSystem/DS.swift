//
//  DS.swift
//  SemtioApp
//
//  Created by Design System Refactor.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

/// Deprecated: Use AppColor, AppFont, Spacing, and Radius instead.
@available(*, deprecated, message: "Use AppColor, AppFont, Spacing, or Radius instead")
struct DS {
    
    struct Spacing {
        static let xxs = SemtioApp.Spacing.xs
        static let xs = SemtioApp.Spacing.sm
        static let s = SemtioApp.Spacing.md
        static let m = SemtioApp.Spacing.md
        static let l = SemtioApp.Spacing.lg
        static let xl = SemtioApp.Spacing.xl
        static let xxl = SemtioApp.Spacing.xl
    }
    
    struct Radius {
        static let small = SemtioApp.Radius.sm
        static let medium = SemtioApp.Radius.md
        static let large = SemtioApp.Radius.lg
        static let xlarge = SemtioApp.Radius.lg
        static let pill = SemtioApp.Radius.pill
    }
    
    struct Colors {
        static let primary = AppColor.primary
        static let onPrimary = AppColor.onPrimary
        static let secondary = AppColor.secondary
        static let background = AppColor.background
        static let surface = AppColor.surface
        static let textPrimary = AppColor.textPrimary
        static let textSecondary = AppColor.textSecondary
        static let textMuted = AppColor.textMuted
        static let border = AppColor.border
        static let divider = AppColor.divider
        static let error = AppColor.error
        static let success = AppColor.success
        static let warning = AppColor.warning
        
        static let primaryFallback = AppColor.primaryFallback
    }
    
    struct Typography {
        static let titleLarge = AppFont.largeTitle
        static let title = AppFont.title
        static let header = AppFont.headline
        static let subheader = AppFont.subheadline
        static let body = AppFont.body
        static let bodyBold = AppFont.bodyBold
        static let caption = AppFont.caption
        static let captionBold = AppFont.captionBold
    }
    
    // Components
    struct Components {
        static let buttonHeight: CGFloat = 50
        static let iconSize: CGFloat = 24
        static let avatarSmall: CGFloat = 32
        static let avatarMedium: CGFloat = 48
        static let avatarLarge: CGFloat = 80
    }
    
    // Utilities
    static func safeHTTPURL(_ raw: String?) -> URL? {
        guard let raw = raw, !raw.isEmpty else { return nil }
        guard let url = URL(string: raw) else { return nil }
        guard let scheme = url.scheme?.lowercased() else { return nil }
        guard scheme == "http" || scheme == "https" else { return nil }
        return url
    }
}
