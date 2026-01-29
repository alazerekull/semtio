//
//  StoryViewerBottomBar.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct StoryViewerBottomBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    
    let onSend: () -> Void
    let onLike: () -> Void
    let onShare: () -> Void
    
    // Quick Reactions
    let reactions = ["🔥", "😍", "😂", "😮", "😢", "👏"]
    let onReaction: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Emoji Quick Reactions (Only visible when typing or focused usually? Or always?
            // Instagram shows them when you tap the text field usually.
            // For now, let's keep it simple: Show them if focused?)
            if isFocused {
               ScrollView(.horizontal, showsIndicators: false) {
                   HStack(spacing: 16) {
                       ForEach(reactions, id: \.self) { emoji in
                           Button {
                               onReaction(emoji)
                           } label: {
                               Text(emoji)
                                   .font(.system(size: 32))
                           }
                       }
                   }
                   .padding(.horizontal)
                   .padding(.bottom, 12)
               }
               //.transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 12) {
                // Message Input
                HStack {
                    TextField("Yanıtla...", text: $text)
                        .focused($isFocused)
                        .foregroundColor(.white)
                        .submitLabel(.send)
                        .onSubmit(onSend)
                    
                    if !text.isEmpty {
                        Button("Gönder", action: onSend)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1))
                
                if !isFocused {
                    // Likes
                    Button(action: onLike) {
                        Image(systemName: "heart")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    // Share
                    Button(action: onShare) {
                        Image(systemName: "paperplane")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 34) // Safe Area
            .padding(.top, 12)
            .background(
                LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .bottom, endPoint: .top)
                    .ignoresSafeArea()
            )
        }
    }
}
