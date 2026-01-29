//
//  Typography.swift
//  SemtioApp
//
//  Created by Design System Architect.
//  Copyright © 2026 Oguzhan Cankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

/// Centralized Typography System
/// Uses dynamic type and semantic naming.
enum AppFont {
    
    /// Large Title (34pt Bold)
    static var largeTitle: Font {
        .system(.largeTitle, design: .default).weight(.bold)
    }
    
    /// Title (28pt Bold)
    static var title: Font {
        .system(.title, design: .default).weight(.bold)
    }
    
    /// Title 2 (22pt)
    static var title2: Font {
        .system(.title2, design: .default).weight(.bold)
    }
    
    /// Title 3 (20pt)
    static var title3: Font {
        .system(.title3, design: .default).weight(.semibold)
    }
    
    /// Headline (17pt Semibold)
    static var headline: Font {
        .system(.headline, design: .default).weight(.semibold)
    }
    
    /// Subheadline (15pt Semibold)
    static var subheadline: Font {
        .system(.subheadline, design: .default).weight(.semibold)
    }
    
    /// Body (17pt Regular)
    static var body: Font {
        .system(.body, design: .default)
    }
    
    /// Body Bold (17pt Semibold)
    static var bodyBold: Font {
        .system(.body, design: .default).weight(.semibold)
    }
    
    /// Callout (16pt Regular)
    static var callout: Font {
        .system(.callout, design: .default)
    }
    
    /// Callout Bold (16pt Semibold)
    static var calloutBold: Font {
        .system(.callout, design: .default).weight(.semibold)
    }
    
    /// Footnote (13pt Regular)
    static var footnote: Font {
        .system(.footnote, design: .default)
    }
    
    /// Footnote Bold (13pt Semibold)
    static var footnoteBold: Font {
        .system(.footnote, design: .default).weight(.semibold)
    }
    
    /// Caption (12pt Regular)
    static var caption: Font {
        .system(.caption, design: .default)
    }
    
    /// Caption Bold (12pt Semibold)
    static var captionBold: Font {
        .system(.caption, design: .default).weight(.semibold)
    }
    
    /// Button Text (17pt Semibold)
    static var button: Font {
        .system(.body, design: .rounded).weight(.semibold)
    }
}
