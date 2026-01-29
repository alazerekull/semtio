//
//  EventsScreenV2.swift
//  SemtioApp
//
//  Enhanced for premium UI/UX.
//

import SwiftUI

struct EventsScreenV2: View {
    @StateObject private var viewModel: EventsViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var eventStore: EventStore
    
    init(eventRepo: EventRepositoryProtocol = FirestoreEventRepository(), userStore: UserStore) {
        _viewModel = StateObject(wrappedValue: EventsViewModel(eventRepo: eventRepo, userStore: userStore))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [AppColor.background, AppColor.background.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Premium Header
                    headerView
                    
                    // MARK: - Segmented Control
                    segmentedControl
                    
                    // MARK: - Filter Pills
                    if viewModel.selectedTab == .hosted {
                        FilterPillsView(options: EventsViewModel.HostedFilter.allCases, selected: $viewModel.selectedHostedFilter)
                    } else {
                        FilterPillsView(options: EventsViewModel.JoinedFilter.allCases, selected: $viewModel.selectedJoinedFilter)
                    }
                    
                    // MARK: - Content
                    contentView
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.onAppear()
            }
            .onChange(of: viewModel.selectedTab) {
                Task { await viewModel.refresh() }
            }
            .onChange(of: viewModel.selectedHostedFilter) {
                Task { await viewModel.refresh() }
            }
            .onChange(of: viewModel.selectedJoinedFilter) {
                Task { await viewModel.refresh() }
            }
            .sheet(isPresented: $viewModel.isCreateEventPresented) {
                CreateEventScreen(eventStore: eventStore, userStore: userStore)
            }
            .sheet(item: $viewModel.selectedEvent) { event in
                EventDetailScreen(event: event)
            }
            .sheet(item: $viewModel.editingEvent) { event in
                CreateEventScreen(eventStore: eventStore, userStore: userStore, event: event)
            }
            .sheet(item: $viewModel.invitingEvent) { event in
                InviteUserSheet(event: event)
            }
            .alert("Hata", isPresented: Binding(
                get: { viewModel.errorMsg != nil },
                set: { if !$0 { viewModel.errorMsg = nil } }
            )) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(viewModel.errorMsg ?? "Bilinmeyen bir hata olustu.")
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        ZStack {
            // Centered Title & Subtitle
            VStack(spacing: 4) {
                Text("Etkinlikler")
                    .font(.system(size: 17, weight: .semibold)) // Matches .inline navigation title
                    .foregroundColor(AppColor.textPrimary)
                
                // Dynamic animated subtitle
                Group {
                    if viewModel.selectedTab == .hosted {
                        Label("\(viewModel.hostedEvents.count) Etkinlik Yönetiliyor", systemImage: "star.fill")
                    } else {
                        Label("\(viewModel.joinedEvents.count) Etkinliğe Katıldın", systemImage: "ticket.fill")
                    }
                }
                .font(AppFont.caption) // Smaller subtitle
                .foregroundColor(AppColor.textSecondary)
            }
            
            // Right-aligned Action Button
            HStack {
                Spacer()
                
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    viewModel.isCreateEventPresented = true
                }) {
                    ZStack {
                        Circle()
                            .fill(AppColor.primary)
                            .frame(width: 36, height: 36) // Slightly smaller to match inline header balance
                            .shadow(color: AppColor.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Segmented Control
    
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(EventsViewModel.TabMode.allCases, id: \.self) { mode in
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.selectedTab = mode
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: mode == .hosted ? "star.circle.fill" : "ticket.fill")
                                .font(.system(size: 14))
                            Text(mode.rawValue)
                                .font(AppFont.subheadline)
                        }
                        .foregroundColor(viewModel.selectedTab == mode ? AppColor.primaryFallback : AppColor.textSecondary)
                        .padding(.vertical, 10)
                        
                        // Underline indicator
                        Rectangle()
                            .fill(viewModel.selectedTab == mode ? AppColor.primaryFallback : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(
            Rectangle()
                .fill(AppColor.border.opacity(0.2))
                .frame(height: 1)
                .offset(y: 20)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            Spacer()
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Yükleniyor...")
                    .font(.system(size: 14))
                    .foregroundColor(AppColor.textSecondary)
            }
            Spacer()
        } else if viewModel.selectedTab == .hosted && viewModel.hostedEvents.isEmpty {
            emptyStateHosted
        } else if viewModel.selectedTab == .joined && viewModel.joinedEvents.isEmpty {
            emptyStateJoined
        } else {
            eventsList
        }
    }
    
    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                let events = viewModel.selectedTab == .hosted ? viewModel.hostedEvents : viewModel.joinedEvents
                
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    EventListCard(event: event, mode: viewModel.selectedTab) { action in
                        switch action {
                        case .tap, .detail:
                            viewModel.selectedEvent = event
                        case .edit:
                            Task {
                                await viewModel.convertToDraftAndEdit(event)
                            }
                        case .share:
                            viewModel.openShareSheet(event)
                        case .cancel:
                            viewModel.cancelEvent(event)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity
                    ))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: events.count)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // MARK: - Empty States
    
    private var emptyStateHosted: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(AppColor.primaryFallback.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 44))
                    .foregroundColor(AppColor.primaryFallback)
            }
            
            VStack(spacing: 8) {
                Text("Henüz Etkinlik Oluşturmadın")
                    .font(AppFont.title3)
                    .foregroundColor(AppColor.textPrimary)
                
                Text("Topluluğunu bir araya getirmek için\nhemen bir etkinlik planla.")
                    .font(AppFont.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                viewModel.isCreateEventPresented = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Etkinlik Oluştur")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(AppColor.primary)
                .cornerRadius(28)
                .shadow(color: AppColor.primary.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    private var emptyStateJoined: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "ticket.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 8) {
                Text("Henüz Katıldığın Etkinlik Yok")
                    .font(AppFont.title3)
                    .foregroundColor(AppColor.textPrimary)
                
                Text("Çevrendeki etkinlikleri keşfet\nve hemen katıl!")
                    .font(AppFont.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    appState.selectedTab = .map
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                        Text("Haritada Keşfet")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(AppColor.onPrimary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(28)
                    .shadow(color: Color.orange.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                
                Button(action: {
                    // TODO: Show InviteCodeSheet
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "qrcode")
                        Text("Davet Kodu Gir")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(AppColor.primaryFallback)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
