//
//  EventsMapView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import MapKit

struct EventsMapView: View {
    @ObservedObject var viewModel: MapViewModel
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var userStore: UserStore
    
    @State private var selectedEvent: Event?
    @State private var isCardExpanded: Bool = false
    
    private var currentUserId: String {
        userStore.currentUser.id
    }
    
    var body: some View {
        ZStack {
            // Map Layer
            mapContent
            
            // Dim overlay when event is selected
            if selectedEvent != nil {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissCard()
                    }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedEvent?.id)
        .onAppear {
            print("📱 MapScreen appeared - attaching listener")
            viewModel.checkLocation()
            eventStore.startListeningMapEvents()
        }
        .onDisappear {
            print("📱 MapScreen disappeared - detaching listener")
            eventStore.stopListeningMapEvents()
        }
        .sheet(item: $selectedEvent) { event in
            EventCardSheet(
                event: event,
                isExpanded: $isCardExpanded,
                onDismiss: { dismissCard() },
                onJoin: { joinEvent(event) }
            )
            .presentationDetents(isCardExpanded ? [.fraction(0.6)] : [.fraction(0.4), .fraction(0.6)])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.4)))
            .interactiveDismissDisabled(false)
        }
    }
    
    // MARK: - Map Content
    
    // iOS 17+ Map Position
    @State private var position: MapCameraPosition = .automatic
    
    // MARK: - Map Content
    
    @ViewBuilder
    private var mapContent: some View {
        mapView
    }
    
    private var mapView: some View {
        Map(position: $position) {
            ForEach(eventStore.mapEvents) { event in
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: event.lat, longitude: event.lon)) {
                    Button {
                        selectEvent(event)
                    } label: {
                        EventMarkerView(
                            event: event,
                            isSelected: selectedEvent?.id == event.id,
                            isOwner: event.createdBy == currentUserId
                        )
                    }
                }
            }
        }
        .mapStyle(.standard)
    }
    
    // MARK: - Removed duplicate content below (was causing duplication)
    
    // MARK: - Actions
    
    private func selectEvent(_ event: Event) {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            selectedEvent = event
            isCardExpanded = false
        }
    }
    
    private func dismissCard() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedEvent = nil
            isCardExpanded = false
        }
    }
    
    private func joinEvent(_ event: Event) {
        Task {
            let userId = currentUserId
            let success = await eventStore.joinEvent(eventId: event.id, userId: userId)
            
            // Haptic feedback based on result
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(success ? .success : .error)
            
            if success {
                // Dismiss card after successful join
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismissCard()
                }
            }
        }
    }
}

