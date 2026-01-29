//
//  ChatComposerView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import PhotosUI

struct ChatComposerView: View {
    @Binding var messageText: String
    @FocusState var isInputFocused: Bool
    let isSendingImage: Bool
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var isCameraPresented: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button(action: { isCameraPresented = true }) {
                    Label("Fotoğraf Çek", systemImage: "camera")
                }
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Galeriden Seç", systemImage: "photo.on.rectangle")
                }
            } label: {
                 Image(systemName: "plus")
                    .font(AppFont.title3)
                    .foregroundColor(.gray)
                    .frame(width: 36, height: 36)
                    .background(AppColor.textSecondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .disabled(isSendingImage)
            
            TextField("Mesaj yaz...", text: $messageText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColor.textSecondary.opacity(0.1))
                .cornerRadius(24)
                .focused($isInputFocused)
            
            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .font(AppFont.title3)
                    .foregroundColor(AppColor.onPrimary)
                    .frame(width: 44, height: 44)
                    .background(messageText.isEmpty ? AppColor.textSecondary : Color.semtioPrimary)
                    .clipShape(Circle())
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 4, y: -2)
    }
}
