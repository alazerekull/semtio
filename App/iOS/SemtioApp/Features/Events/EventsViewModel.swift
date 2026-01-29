//
//  EventsViewModel.swift
//  SemtioApp
//
//  Created for Events V2 Feature.
//

import SwiftUI
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class EventsViewModel: ObservableObject {
    // MARK: - Enums
    
    enum TabMode: String, CaseIterable {
        case hosted = "Yönetiyorum"
        case joined = "Katılıyorum"
    }
    
    enum HostedFilter: String, CaseIterable, Identifiable {
        case upcoming = "Yaklaşan"
        case past = "Geçmiş"
        case draft = "Taslak"
        case all = "Tümü"
        
        var id: String { rawValue }
    }
    
    enum JoinedFilter: String, CaseIterable, Identifiable {
        case upcoming = "Yaklaşan"
        case past = "Geçmiş"
        case pending = "Beklemede"
        case all = "Tümü"
        
        var id: String { rawValue }
    }
    
    // MARK: - Dependencies
    private let eventRepo: EventRepositoryProtocol
    private let userStore: UserStore
    
    // MARK: - State
    @Published var selectedTab: TabMode = .hosted
    @Published var selectedHostedFilter: HostedFilter = .upcoming
    @Published var selectedJoinedFilter: JoinedFilter = .upcoming
    
    @Published var hostedEvents: [Event] = []
    @Published var joinedEvents: [Event] = []
    
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var hasMore: Bool = true
    @Published var errorMsg: String?
    
    // Pagination state
    #if canImport(FirebaseFirestore)
    private var hostedLastDoc: DocumentSnapshot?
    private var joinedLastDoc: DocumentSnapshot?
    #endif
    private let pageSize = 20
    
    // Sheets
    @Published var isCreateEventPresented: Bool = false
    @Published var selectedEvent: Event? // For detail sheet
    @Published var editingEvent: Event? // For "Düzenle" -> CreateEventScreen
    @Published var invitingEvent: Event? // For "Paylaş" -> InviteUserSheet
    
    // MARK: - Init
    init(eventRepo: EventRepositoryProtocol, userStore: UserStore) {
        self.eventRepo = eventRepo
        self.userStore = userStore
    }
    
    // MARK: - Public Methods
    
    func onAppear() {
        Task {
            await loadData()
        }
    }
    
    func refresh() async {
        // Reset pagination
        #if canImport(FirebaseFirestore)
        hostedLastDoc = nil
        joinedLastDoc = nil
        #endif
        hasMore = true
        
        if selectedTab == .hosted {
            hostedEvents = []
        } else {
            joinedEvents = []
        }
        
        await loadData()
    }
    
    func loadMore() async {
        guard hasMore && !isLoadingMore else { return }
        
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        // Load next page
        await loadData(append: true)
    }
    
    @MainActor
    func loadData(append: Bool = false) async {
        guard let userId = userStore.currentUser.id.isEmpty ? nil : userStore.currentUser.id else { return }
        
        if !append {
            isLoading = true
        }
        defer {
            if !append {
                isLoading = false
            }
        }
        
        do {
            if selectedTab == .hosted {
                try await loadHostedEvents(userId: userId, append: append)
            } else {
                try await loadJoinedEvents(userId: userId, append: append)
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 9 {
                print("❌ MISSING INDEX: Copy the URL from the console log to create the index.")
            }
            print("❌ EventsViewModel load error: \(error)")
            errorMsg = "Etkinlikler yüklenirken hata oluştu: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Private Loading Logic
    
    private func loadHostedEvents(userId: String, append: Bool) async throws {
        // TODO: Update repo to support pagination with lastDoc
        // For now, limit query size
        let events = try await eventRepo.fetchEvents(createdBy: userId)
        
        let filtered = events.filter { event in
            switch selectedHostedFilter {
            case .upcoming:
                return event.status == .published && !event.isPast
            case .past:
                return event.isPast
            case .draft:
                return event.status == .draft
            case .all:
                return true
            }
        }
        .sorted { $0.startDate < $1.startDate }
        
        if append {
            self.hostedEvents.append(contentsOf: filtered)
        } else {
            self.hostedEvents = filtered
        }
        
        // Update hasMore based on result count
        hasMore = events.count >= pageSize
    }
    
    private func loadJoinedEvents(userId: String, append: Bool) async throws {
        // Handle pending filter separately - fetch from join_requests
        if selectedJoinedFilter == .pending {
            let pendingEvents = try await eventRepo.fetchPendingJoinedEvents(uid: userId)
            let filtered = pendingEvents.filter { !$0.isPast }
                .sorted { $0.startDate < $1.startDate }

            if append {
                self.joinedEvents.append(contentsOf: filtered)
            } else {
                self.joinedEvents = filtered
            }
            hasMore = pendingEvents.count >= pageSize
            return
        }

        // Normal joined events fetch
        let events = try await eventRepo.fetchJoinedEvents(uid: userId)

        let filtered = events.filter { event in
            switch selectedJoinedFilter {
            case .upcoming:
                return !event.isPast
            case .past:
                return event.isPast
            case .pending:
                return false // Already handled above
            case .all:
                return true
            }
        }
        .sorted { $0.startDate < $1.startDate }

        if append {
            self.joinedEvents.append(contentsOf: filtered)
        } else {
            self.joinedEvents = filtered
        }

        hasMore = events.count >= pageSize
    }
    
    // MARK: - Actions
    
    func cancelEvent(_ event: Event) {
        Task {
            do {
                try await eventRepo.cancelEvent(eventId: event.id)
                await loadData() // Refresh
            } catch {
                errorMsg = "Etkinlik iptal edilemedi."
            }
        }
    }
    
    func convertToDraftAndEdit(_ event: Event) async {
        do {
            // 1. Update status to draft in Firestore
            try await eventRepo.updateEvent(id: event.id, data: ["status": "draft"])
            
            // 2. Refresh local data to reflect change (move to draft tab)
            await loadData()
            
            // 3. Open Edit Sheet
            // We need to pass the updated event (status=draft)
            var updatedEvent = event
            updatedEvent.status = .draft
            self.editingEvent = updatedEvent
            
        } catch {
            print("❌ Failed to convert to draft: \(error)")
            errorMsg = "Etkinlik düzenlenemedi."
        }
    }
    
    func openShareSheet(_ event: Event) {
        self.invitingEvent = event
    }
}
