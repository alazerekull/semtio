//
//  PillSegmentControl.swift
//  SemtioApp
//
//  Created by Design System Refactor.
//

import SwiftUI

struct PillSegmentControl<T: Hashable & CustomStringConvertible>: View {
    let options: [T]
    @Binding var selected: T
    var namespace: Namespace.ID? = nil // Valid for matched geometry if needed
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                segmentButton(for: option)
            }
        }
        .padding(Spacing.xs)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(Radius.pill)
    }
    
    private func segmentButton(for option: T) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selected = option
            }
        }) {
            Text(option.description)
                .font(selected == option ? AppFont.subheadline : AppFont.body)
                .foregroundColor(selected == option ? AppColor.onPrimary : AppColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(backgroundView(for: option))
        }
    }
    
    @ViewBuilder
    private func backgroundView(for option: T) -> some View {
        if selected == option {
            RoundedRectangle(cornerRadius: Radius.pill)
                .fill(AppColor.primaryFallback)
                .matchedGeometryEffect(id: "selection", in: namespace ?? Namespace().wrappedValue)
        } else {
            Color.clear
        }
    }
}

// Helper wrapper for Preview to handle namespace
struct PillSegmentControlPreview: View {
    @Namespace var ns
    @State var selected = "Posts"
    
    var body: some View {
        PillSegmentControl(options: ["Posts", "Events"], selected: $selected, namespace: ns)
            .padding()
    }
}

#Preview {
    PillSegmentControlPreview()
}

