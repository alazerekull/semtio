//
//  SwipeToDeleteRow.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct SwipeToDeleteRow: View {
    let event: Event
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiped: Bool = false
    
    var body: some View {
        ZStack {
            // Background Delete Button
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        onDelete()
                    }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundColor(AppColor.onPrimary)
                        .frame(width: 80, height: 100)
                        .background(Color.red)
                        .cornerRadius(20)
                }
                .opacity(offset < -40 ? 1 : 0)
            }
            .padding(.trailing, 0)
            
            // Content Card with Navigation
            NavigationLink(destination: EventDetailScreen(event: event)) {
                MyEventCard(event: event)
            }
            .buttonStyle(PlainButtonStyle()) // Prevent default button styling
            .disabled(isSwiped) // Disable navigation when swiped
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            self.offset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        if value.translation.width < -100 {
                            self.offset = -100
                            self.isSwiped = true
                        } else {
                            self.offset = 0
                            self.isSwiped = false
                        }
                    }
            )
            .onTapGesture {
                // Tap to reset if swiped
                if isSwiped {
                    withAnimation {
                        self.offset = 0
                        self.isSwiped = false
                    }
                }
            }
            .animation(.spring(), value: offset)
        }
    }
}
