//
//  EventStoriesRowView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct EventStoriesRowView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                // Create Event Button (First Item)
                EventStoryItemView(isCreateButton: true) {
                    appState.presentCreateEvent()
                }
                
                // Event Stories
                ForEach(appState.feed.feedEvents.prefix(10)) { event in
                    NavigationLink(destination: EventDetailScreen(event: event)) {
                        EventStoryItemView(event: event) {
                            // Navigation handled by NavigationLink
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .background(AppColor.surface)
    }
}

#Preview {
    EventStoriesRowView()
        .environmentObject(AppState(
            session: SessionManager(),
            theme: AppThemeManager(),
            location: LocationManager()
        ))
}
