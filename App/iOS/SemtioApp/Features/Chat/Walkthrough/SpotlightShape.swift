//
//  SpotlightShape.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct SpotlightShape: Shape {
    var spotlightFrame: CGRect
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<CGRect.AnimatableData, CGFloat> {
        get {
            AnimatablePair(spotlightFrame.animatableData, cornerRadius)
        }
        set {
            spotlightFrame.animatableData = newValue.first
            cornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        let spotlight = Path(roundedRect: spotlightFrame, cornerRadius: cornerRadius)
        return path.subtracting(spotlight)
    }
}


