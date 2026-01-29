//
//  FastActionBand.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct FastActionBand: View {
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: {
            appState.selectedTab = .map
        }) {
            HStack(spacing: 12) {
                Image(systemName: "location.circle.fill")
                    .font(AppFont.title3)
                    .foregroundColor(AppColor.onPrimary)
                
                VStack(alignment: .leading, spacing: 2) {
                    if eventStore.activeEvents.count > 0 {
                        Text("Yakınında \(eventStore.activeEvents.count) etkinlik var")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColor.onPrimary)
                    } else {
                        Text("Bugün katılabileceğin etkinlikler")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColor.onPrimary)
                    }
                    
                    Text("Haritada görüntülemek için dokun")
                        .font(AppFont.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.semtioPrimary, Color.purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .semtioPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
    }
}
