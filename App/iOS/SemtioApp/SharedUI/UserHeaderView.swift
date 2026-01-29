//
//  UserHeaderView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct UserHeaderView: View {
    @EnvironmentObject var userStore: UserStore
    
    // NEW: Settings destination as AnyView (simpler than generic)
    let settingsDestination: AnyView?
    
    init(settingsDestination: AnyView? = nil) {
        self.settingsDestination = settingsDestination
    }
    
    var body: some View {
        HStack {
            // Avatar
            ZStack {
                Circle()
                    .fill(AppColor.textSecondary.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                if let assetName = userStore.currentUser.avatarAssetName,
                   let uiImage = UIImage(named: assetName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .foregroundColor(.gray)
                }
            }
            
            // Name & ID
            VStack(alignment: .leading, spacing: 2) {
                Text(userStore.currentUser.fullName)
                    .font(.headline)
                    .foregroundColor(.semtioDarkText)
                Text("ID: \(userStore.currentUser.id)")
                    .font(.caption)
                    .foregroundColor(.semtioGrayText)
            }
            
            Spacer()
            
            // Icons
            HStack(spacing: 12) {
                // LEFT: Share (swapped from right)
                Button(action: {
                    // TODO: Share Sheet (next step)
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Circle().stroke(AppColor.textSecondary.opacity(0.3), lineWidth: 1))
                }
                
                // RIGHT: Settings (replaces reload)
                if let settingsDestination {
                    NavigationLink(destination: settingsDestination) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(8)
                            .background(Circle().stroke(AppColor.textSecondary.opacity(0.3), lineWidth: 1))
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(35)
        .overlay(
            RoundedRectangle(cornerRadius: 35)
                .stroke(AppColor.textSecondary.opacity(0.1), lineWidth: 1)
        )
    }
}

