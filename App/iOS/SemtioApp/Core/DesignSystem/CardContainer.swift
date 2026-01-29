//
//  CardContainer.swift
//  SemtioApp
//
//  Created by Design System Refactor.
//

import SwiftUI

struct CardContainer<Content: View>: View {
    let padding: CGFloat
    let content: Content
    
    init(padding: CGFloat = Spacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .semtioCardStyle()
    }
}
