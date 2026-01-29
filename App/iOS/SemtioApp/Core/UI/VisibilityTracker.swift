//
//  VisibilityTracker.swift
//  SemtioApp
//
//  Tracks the visibility fraction of a view within a scroll container.
//

import SwiftUI

struct VisibilityTracker: ViewModifier {
    let onVisibilityChanged: (CGFloat) -> Void
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: VisibilityPreferenceKey.self,
                            value: [geometry.frame(in: .global)]
                        )
                }
            )
            .onPreferenceChange(VisibilityPreferenceKey.self) { frames in
                guard let frame = frames.first else { return }
                calculateVisibility(rect: frame)
            }
    }
    
    private func calculateVisibility(rect: CGRect) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return }
        
        let safeAreaTop = window.safeAreaInsets.top
        let safeAreaBottom = window.safeAreaInsets.bottom
        let screenHeight = window.bounds.height
        
        // Visible viewport (approximately)
        let viewportTop = safeAreaTop
        let viewportBottom = screenHeight - safeAreaBottom // Simplified, can be adjusted for tab bar
        
        // Intersection
        let visibleTop = max(rect.minY, viewportTop)
        let visibleBottom = min(rect.maxY, viewportBottom)
        
        let visibleHeight = max(0, visibleBottom - visibleTop)
        let totalHeight = rect.height
        
        var fraction: CGFloat = 0
        if totalHeight > 0 {
            fraction = visibleHeight / totalHeight
        }
        
        onVisibilityChanged(fraction)
    }
}

fileprivate struct VisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: [CGRect] = []
    
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    func onVisibilityChange(perform action: @escaping (CGFloat) -> Void) -> some View {
        self.modifier(VisibilityTracker(onVisibilityChanged: action))
    }
}
