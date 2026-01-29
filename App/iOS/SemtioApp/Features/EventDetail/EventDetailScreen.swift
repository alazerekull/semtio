//
//  EventDetailScreen.swift
//  SemtioApp
//
//  Enhanced with join request support for requestApproval visibility mode.
//  CTA logic centralized in CTAConfig for maintainability.
//

import SwiftUI
import MapKit

struct EventDetailScreen: View {
    let event: Event
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var chatStore: ChatStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore

    @State private var activeSheet: SheetType? = nil
    @State private var isJoining = false
    @State private var hasJoined = false
    @State private var requestStatus: JoinRequestStatus? = nil
    @State private var pendingRequestCount: Int = 0

    // Navigation State Enum
    enum SheetType: Identifiable {
        case invite
        case requests
        
        var id: Int {
            hashValue
        }
    }

    // Check if current user is host
    private var isHost: Bool {
        event.createdBy == userStore.currentUser.id || event.hostUserId == userStore.currentUser.id
    }

    // MARK: - CTA Configuration

    /// Represents a single CTA button configuration
    struct CTAConfig: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let style: CTAStyle
        let isEnabled: Bool
        let isLoading: Bool
        let badge: Int?
        let action: () -> Void

        enum CTAStyle {
            case primary      // semtioPrimary
            case secondary    // orange (requests)
            case success      // green (joined)
            case destructive  // red
            case disabled     // gray

            var backgroundColor: Color {
                switch self {
                case .primary: return .semtioPrimary
                case .secondary: return .orange
                case .success: return .green
                case .destructive: return .red.opacity(0.6)
                case .disabled: return .gray
                }
            }
        }

        static func label(title: String, icon: String) -> CTAConfig {
            CTAConfig(
                title: title,
                icon: icon,
                style: .disabled,
                isEnabled: false,
                isLoading: false,
                badge: nil,
                action: {}
            )
        }
    }

    /// Centralized CTA decision tree - returns all CTA configs to display
    private var ctaConfigs: [CTAConfig] {
        if isHost {
            return buildHostCTAs()
        } else {
            return buildGuestCTAs()
        }
    }

    private func buildHostCTAs() -> [CTAConfig] {
        var configs: [CTAConfig] = []

        // 1. requestApproval mode: Show "İstekler" button
        if event.visibility == .requestApproval {
            configs.append(CTAConfig(
                title: "İstekler",
                icon: "person.crop.circle.badge.questionmark",
                style: .secondary,
                isEnabled: true,
                isLoading: false,
                badge: pendingRequestCount > 0 ? pendingRequestCount : nil,
                action: { activeSheet = .requests }
            ))
        }

        // 2. Always show "Davet Et" button for host (all visibility modes)
        configs.append(CTAConfig(
            title: "Davet Et",
            icon: "person.badge.plus",
            style: .primary,
            isEnabled: true,
            isLoading: false,
            badge: nil,
            action: { activeSheet = .invite }
        ))

        return configs
    }

    private func buildGuestCTAs() -> [CTAConfig] {
        switch event.visibility {
        case .public:
            return [buildPublicJoinCTA()]
        case .requestApproval:
            return [buildRequestApprovalCTA()]
        case .private:
            // Private: Non-host sees only label, no actionable button
            return [CTAConfig.label(title: "Sadece Davetliler", icon: "lock.fill")]
        }
    }

    private func buildPublicJoinCTA() -> CTAConfig {
        // Determine state
        if isJoining {
            return CTAConfig(
                title: "",
                icon: "",
                style: .primary,
                isEnabled: false,
                isLoading: true,
                badge: nil,
                action: {}
            )
        } else if hasJoined {
            return CTAConfig(
                title: "Katıldın",
                icon: "checkmark.circle.fill",
                style: .success,
                isEnabled: false,
                isLoading: false,
                badge: nil,
                action: {}
            )
        } else if event.isFull {
            return CTAConfig(
                title: "Dolu",
                icon: "xmark.circle",
                style: .disabled,
                isEnabled: false,
                isLoading: false,
                badge: nil,
                action: {}
            )
        } else {
            return CTAConfig(
                title: "Katıl",
                icon: "person.badge.plus",
                style: .primary,
                isEnabled: true,
                isLoading: false,
                badge: nil,
                action: joinEvent
            )
        }
    }

    private func buildRequestApprovalCTA() -> CTAConfig {
        if isJoining {
            return CTAConfig(
                title: "",
                icon: "",
                style: .primary,
                isEnabled: false,
                isLoading: true,
                badge: nil,
                action: {}
            )
        } else if hasJoined {
            return CTAConfig(
                title: "Katıldın",
                icon: "checkmark.circle.fill",
                style: .success,
                isEnabled: false,
                isLoading: false,
                badge: nil,
                action: {}
            )
        } else if requestStatus == .pending {
            return CTAConfig(
                title: "Beklemede",
                icon: "clock.fill",
                style: .secondary,
                isEnabled: false,
                isLoading: false,
                badge: nil,
                action: {}
            )
        } else if requestStatus == .rejected {
            return CTAConfig(
                title: "Reddedildi",
                icon: "xmark.circle",
                style: .destructive,
                isEnabled: false,
                isLoading: false,
                badge: nil,
                action: {}
            )
        } else if event.isFull {
            return CTAConfig(
                title: "Dolu",
                icon: "xmark.circle",
                style: .disabled,
                isEnabled: false,
                isLoading: false,
                badge: nil,
                action: {}
            )
        } else {
            return CTAConfig(
                title: "Katılım İste",
                icon: "hand.raised.fill",
                style: .primary,
                isEnabled: true,
                isLoading: false,
                badge: nil,
                action: submitRequest
            )
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero Image
                    // Hero Image
                    Rectangle()
                        .fill(AppColor.textSecondary.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            Group {
                                if let urlString = event.coverImageURL, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        case .failure:
                                            Image(event.category.defaultImageName).resizable().scaledToFill()
                                        case .empty:
                                            ProgressView()
                                        @unknown default:
                                            Image(event.category.defaultImageName).resizable().scaledToFill()
                                        }
                                    }
                                } else {
                                    Image(event.category.defaultImageName)
                                        .resizable()
                                        .scaledToFill()
                                }
                            }
                        )
                        .clipped()
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(event.title)
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(AppColor.textPrimary)
                                Spacer()
                                // Visibility Badge
                                HStack(spacing: 4) {
                                    Image(systemName: event.visibility.icon)
                                        .font(.system(size: 10))
                                    Text(event.visibility.localizedName)
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.semtioPrimary.opacity(0.1))
                                .foregroundColor(.semtioPrimary)
                                .cornerRadius(8)
                            }
                            
                            // Capacity Indicator
                            if let limit = event.capacityLimit, limit > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.3.fill")
                                        .font(.caption)
                                    Text("\(event.participantCount)/\(limit) katılımcı")
                                        .font(.caption)
                                    
                                    if event.isFull {
                                        Text("DOLU")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColor.onPrimary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.red)
                                            .cornerRadius(4)
                                    }
                                }
                                .foregroundColor(event.isFull ? .red : .secondary)
                            }
                            
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.gray)
                                Text("Düzenleyen: \(event.hostUserId ?? "Bilinmiyor")")
                                    .font(.subheadline)
                                    .foregroundColor(AppColor.textSecondary)
                            }
                        }
                        
                        Divider()
                        
                        // Time & Location
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                Image(systemName: "calendar")
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text(event.dayLabel)
                                        .fontWeight(.medium)
                                    Text(event.timeLabel)
                                        .foregroundColor(AppColor.textSecondary)
                                }
                            }
                            
                            HStack(alignment: .top) {
                                Image(systemName: "mappin.and.ellipse")
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text(event.locationName ?? "Konum seçilmedi")
                                        .fontWeight(.medium)
                                    Text(event.district ?? "")
                                        .foregroundColor(AppColor.textSecondary)
                                }
                            }
                        }
                        .foregroundColor(AppColor.textPrimary)
                        
                        Divider()
                        
                        // Description
                        if let desc = event.description {
                            Text("Hakkında")
                                .font(.headline)
                            Text(desc)
                                .font(.body)
                                .foregroundColor(AppColor.textSecondary)
                        }
                        
                        // Map Preview
                        Map(position: .constant(.region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: event.lat, longitude: event.lon),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )))) {
                             Marker("", coordinate: CLLocationCoordinate2D(latitude: event.lat, longitude: event.lon))
                        }
                        .frame(height: 150)
                        .cornerRadius(12)
                        .disabled(true)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColor.textSecondary.opacity(0.2), lineWidth: 1)
                        )
                        .onTapGesture {
                            DirectionsService.openMaps(for: event)
                        }
                        
                        // Directions Button
                        Button {
                            DirectionsService.openMaps(for: event)
                        } label: {
                            HStack {
                                Text("Haritada Gör")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.subheadline)
                            .foregroundColor(.semtioPrimary)
                        }

                        // Bottom padding for sticky bar
                        Color.clear.frame(height: 100)
                    }
                    .padding()
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // Sticky CTA Bar - Unified rendering from CTAConfig
            VStack(spacing: 0) {
                Divider()

                HStack(spacing: 12) {
                    ForEach(ctaConfigs) { config in
                        ctaButton(for: config)
                    }
                }
                .padding()
                .background(Material.regular)
            }
        }
        .sheet(item: $activeSheet) { type in
            switch type {
            case .invite:
                InviteUserSheet(event: event)
                    .presentationDetents([.medium, .large])
            case .requests:
                JoinRequestsSheet(
                    event: event,
                    eventRepo: appState.events.repo,
                    userRepo: appState.userStore.repo,
                    onUpdate: { await loadPendingCount() }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .task {
            await checkAttendance()
            await loadRequestStatus()
            if isHost {
                await loadPendingCount()
            }
        }
    }
    
    // MARK: - Unified CTA Button Renderer

    @ViewBuilder
    private func ctaButton(for config: CTAConfig) -> some View {
        if config.isEnabled {
            // Actionable button
            PrimaryButton(
                title: config.title,
                icon: config.icon,
                isLoading: config.isLoading,
                action: config.action
            )
            .background(config.style == .destructive ? AppColor.error : nil) // Override for destructive if needed
            .overlay(
                  // Badge logic overlay
                  Group {
                      if let badge = config.badge {
                          Text("\(badge)")
                              .font(.caption.bold())
                              .foregroundColor(AppColor.onPrimary)
                              .padding(6)
                              .background(Color.red)
                              .clipShape(Circle())
                              .offset(x: 10, y: -10)
                      }
                  }, 
                  alignment: .topTrailing
            )
        } else {
            // Non-actionable label/disabled state
            // Reusing PrimaryButton with disabled state for consistency or custom view
            PrimaryButton(
                title: config.title,
                icon: config.icon,
                isLoading: config.isLoading,
                isDisabled: true,
                action: {}
            )
        }
    }
    
    // MARK: - Actions
    
    private func joinEvent() {
        guard !hasJoined && !event.isFull else { return }
        isJoining = true
        Task {
            do {
                try await appState.events.repo.joinEvent(eventId: event.id, uid: userStore.currentUser.id)
                hasJoined = true
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            } catch {
                print("❌ Join failed: \(error)")
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.error)
            }
            isJoining = false
        }
    }
    
    private func submitRequest() {
        guard requestStatus == nil && !hasJoined && !event.isFull else { return }
        isJoining = true
        Task {
            do {
                try await appState.events.repo.submitJoinRequest(
                    eventId: event.id,
                    userId: userStore.currentUser.id,
                    userName: userStore.currentUser.fullName,
                    userAvatarURL: userStore.currentUser.avatarURL
                )
                requestStatus = .pending
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            } catch {
                print("❌ Submit request failed: \(error)")
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.error)
            }
            isJoining = false
        }
    }
    
    private func checkAttendance() async {
        do {
            hasJoined = try await appState.events.repo.isUserJoined(eventId: event.id, uid: userStore.currentUser.id)
        } catch {
            print("❌ Check attendance failed: \(error)")
        }
    }
    
    private func loadRequestStatus() async {
        guard event.visibility == .requestApproval else { return }
        do {
            requestStatus = try await appState.events.repo.getJoinRequestStatus(eventId: event.id, userId: userStore.currentUser.id)
        } catch {
            print("❌ Load request status failed: \(error)")
        }
    }
    
    private func loadPendingCount() async {
        guard isHost else { return }
        do {
            let requests = try await appState.events.repo.fetchPendingJoinRequests(eventId: event.id)
            pendingRequestCount = requests.count
        } catch {
            print("❌ Load pending count failed: \(error)")
        }
    }
}
