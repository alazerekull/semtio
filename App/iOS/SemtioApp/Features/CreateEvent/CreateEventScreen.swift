//
//  CreateEventScreen.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import PhotosUI

struct CreateEventScreen: View {
    @StateObject private var viewModel: CreateEventViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var showLocationPicker = false
    @State private var showImagePicker = false
    @State private var pickedItem: PhotosPickerItem? = nil
    
    /// Called after successful event creation (for usage tracking)
    var onCreated: (() -> Void)?
    
    // Environment-based init (preferred for global presentation)
    init(onCreated: (() -> Void)? = nil) {
        // Use shared mock/factory instances - will be overridden by environment
        let eventStore = EventStore(repo: RepositoryFactory.makeEventRepository())
        let userStore = UserStore(repo: RepositoryFactory.makeUserRepository())
        _viewModel = StateObject(wrappedValue: CreateEventViewModel(eventStore: eventStore, userStore: userStore))
        self.onCreated = onCreated
    }
    
    // Legacy init for direct usage with explicit stores
    init(eventStore: EventStore, userStore: UserStore, event: Event? = nil, onCreated: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: CreateEventViewModel(eventStore: eventStore, userStore: userStore, event: event))
        self.onCreated = onCreated
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                AppColor.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        headerView

                        // Error Banner
                        if let error = viewModel.errorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppColor.error)
                                Text(error)
                                    .font(AppFont.body)
                                    .foregroundColor(AppColor.textPrimary)
                                Spacer()
                                Button("✕") {
                                    viewModel.errorMessage = nil
                                }
                                .foregroundColor(AppColor.textSecondary)
                            }
                            .padding()
                            .background(AppColor.error.opacity(0.15))
                            .cornerRadius(Radius.md)
                            .padding(.horizontal)
                        }

                        VStack(spacing: Spacing.lg) {
                            titleSection
                            Divider().padding(.horizontal)
                            categorySection
                            timeSection
                            locationSection
                            privacySection
                        }
                        
                        Spacer().frame(height: 100)
                    }
                }
                .edgesIgnoringSafeArea(.top)
                
                submitButton
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerScreen { pickedLocation in
                    Task { @MainActor in
                        print("📍 Location selected in callback")
                        print("   Coordinate: \(pickedLocation.coordinate.latitude), \(pickedLocation.coordinate.longitude)")
                        viewModel.duplicateLocation(pickedLocation)
                        print("   ViewModel.selectedCoordinate: \(String(describing: viewModel.selectedCoordinate))")
                        print("   ViewModel.isValid: \(viewModel.isValid)")
                    }
                }
            }
            .onChangeCompatible(of: pickedItem) { newItem in
                 Task {
                     if let data = try? await newItem?.loadTransferable(type: Data.self),
                        let uiImage = UIImage(data: data) {
                         viewModel.selectedImage = uiImage
                     }
                 }
            }
            .onChangeCompatible(of: viewModel.shouldDismiss) { should in
                if should {
                    // Record usage and notify parent
                    onCreated?()
                    dismiss()
                }
            }
        }
        .environment(\.locale, Locale(identifier: "tr_TR"))
        .onAppear {
            appState.isTabBarHidden = true
        }
        .onDisappear {
            appState.isTabBarHidden = false
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        ZStack(alignment: .bottomTrailing) {
            if let selectedImage = viewModel.selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 250)
                    .clipped()
            } else {
                // Default category image
                ZStack {
                    Rectangle()
                        .fill(categoryColor)
                    
                    Image(systemName: categoryIcon)
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(height: 250)
            }
            
            // Photo Change Button
            PhotosPicker(selection: $pickedItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                    Text("Fotoğraf Ekle")
                        .fontWeight(.medium)
                }
                .font(AppFont.captionBold)
                .foregroundColor(AppColor.textPrimary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(AppColor.surface)
                .cornerRadius(Radius.lg)
                .semtioShadow(.card)
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var titleSection: some View {
        VStack(spacing: Spacing.md) {
            TextField("Etkinlik Başlığı", text: $viewModel.title)
                .font(AppFont.title)
                .foregroundColor(AppColor.textPrimary)
                .padding(.horizontal)
                .submitLabel(.next)
            
            TextField("Açıklama (İsteğe bağlı)", text: $viewModel.description, axis: .vertical)
                .font(AppFont.body)
                .foregroundColor(AppColor.textSecondary)
                .lineLimit(2...5)
                .padding(.horizontal)
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Kategori")
                .font(AppFont.headline)
                .foregroundColor(AppColor.textPrimary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(EventCategory.allCases, id: \.self) { cat in
                        CategoryChip(
                            title: cat.localizedName,
                            isSelected: viewModel.category == cat,
                            action: {
                                withAnimation {
                                    viewModel.category = cat
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.trailing, 20)
            }
        }
    }
    
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Zaman")
                .font(AppFont.headline)
                .foregroundColor(AppColor.textPrimary)
                .padding(.horizontal)
            
            HStack(spacing: Spacing.md) {
                // Start
                VStack(alignment: .leading, spacing: 4) {
                    Text("Başlangıç")
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textSecondary)
                    DatePicker("", selection: $viewModel.startDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
                .padding()
                .background(AppColor.surface)
                .cornerRadius(Radius.md)
                
                // End
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bitiş")
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textSecondary)
                    DatePicker("", selection: $viewModel.endDate, in: viewModel.startDate..., displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                }
                .padding()
                .background(AppColor.surface)
                .cornerRadius(Radius.md)
            }
            .padding(.horizontal)
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Konum")
                .font(AppFont.headline)
                .foregroundColor(AppColor.textPrimary)
                .padding(.horizontal)
            
            Button(action: { showLocationPicker = true }) {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.red)
                    
                    if let name = viewModel.locationName, !name.isEmpty {
                        Text(name)
                            .foregroundColor(AppColor.textPrimary)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    } else {
                        Text("Konum Seç")
                            .foregroundColor(AppColor.textSecondary) // Changed to textSecondary for better visibility/convention
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColor.textMuted)
                        .font(AppFont.caption)
                }
                .padding()
                .background(AppColor.surface)
                .cornerRadius(Radius.lg)
                .semtioShadow(.card)
            }
            .padding(.horizontal)

            // Coordinate Display
            if let coord = viewModel.selectedCoordinate {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                    Text("📍 \(coord.latitude.formatted(.number.precision(.fractionLength(4)))), \(coord.longitude.formatted(.number.precision(.fractionLength(4))))")
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Gizlilik & Kapasite")
                .font(AppFont.headline)
                .foregroundColor(AppColor.textPrimary)
                .padding(.horizontal)
            
            visibilitySelector
            capacitySection
        }
    }
    
    private var visibilitySelector: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(EventVisibility.allCases) { mode in
                VisibilityOptionView(
                    mode: mode,
                    isSelected: viewModel.visibility == mode,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.visibility = mode
                        }
                    }
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var capacitySection: some View {
        VStack(spacing: Spacing.md) {
            Toggle(isOn: $viewModel.hasCapacityLimit) {
                HStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(AppColor.primary)
                    Text("Kontenjan Limiti")
                        .font(AppFont.body)
                        .foregroundColor(AppColor.textPrimary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: AppColor.primary))
            .padding()
            .background(AppColor.surface)
            .cornerRadius(Radius.md)
            .semtioShadow(.card)
            
            if viewModel.hasCapacityLimit {
                HStack {
                    Text("Maksimum katılımcı:")
                        .font(AppFont.captionBold)
                        .foregroundColor(AppColor.textSecondary)
                    
                    Spacer()
                    
                    // Value shown explicitly outside stepper
                    Text("\(viewModel.capacityLimit)")
                        .font(AppFont.bodyBold)
                        .foregroundColor(AppColor.primary)
                        .frame(minWidth: 30)
                    
                    Stepper("", value: $viewModel.capacityLimit, in: 2...500, step: 5)
                        .labelsHidden()
                }
                .padding()
                .background(AppColor.surface)
                .cornerRadius(Radius.md)
                .semtioShadow(.card)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 100)
    }

    private var submitButton: some View {
        VStack(spacing: 8) {
            // Validation hint when disabled
            if !viewModel.isValid {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(AppColor.error)
                        .font(.system(size: 12))
                    Text(validationHint)
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.error)
                }
            }

            Button(action: {
                Task { await viewModel.createEvent() }
            }) {
                HStack {
                    if viewModel.isSubmitting {
                        ProgressView().tint(AppColor.onPrimary)
                    } else {
                        Text(viewModel.isEditing ? "Etkinliği Güncelle" : "Etkinliği Oluştur")
                            .fontWeight(.bold)
                    }
                }
                .foregroundColor(AppColor.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(viewModel.isValid ? AppColor.primary : AppColor.textMuted)
                .cornerRadius(28)
                .padding(.horizontal, 24)
                .semtioShadow(.floating)
            }
            .disabled(viewModel.isSubmitting || !viewModel.isValid)
        }
        .padding(.bottom, 20)
    }

    private var validationHint: String {
        if viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "⚠️ Lütfen etkinlik başlığı girin"
        }
        if viewModel.selectedCoordinate == nil {
            return "⚠️ Lütfen konum seçin"
        }
        return ""
    }
    
    // Helper for placeholder UI
    private var categoryColor: Color {
        switch viewModel.category {
        case .party: return .purple
        case .sport: return .green
        case .music: return .red
        case .food: return .orange
        case .meetup: return .blue
        case .other: return .gray
        }
    }
    
    private var categoryIcon: String {
        switch viewModel.category {
        case .party: return "party.popper.fill"
        case .sport: return "figure.run"
        case .music: return "music.note"
        case .food: return "fork.knife"
        case .meetup: return "person.3.fill"
        case .other: return "star.fill"
        }
    }
}

struct VisibilityOptionView: View {
    let mode: EventVisibility
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : AppColor.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(isSelected ? AppColor.primary : AppColor.primary.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.localizedName)
                        .font(AppFont.subheadline)
                        .foregroundColor(AppColor.textPrimary)
                    
                    Text(mode.description)
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColor.primary)
                        .font(AppFont.title3)
                }
            }
            .padding(12)
            .background(AppColor.surface)
            .cornerRadius(Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(isSelected ? AppColor.primary : Color.clear, lineWidth: 2)
            )
            .semtioShadow(.card)
        }
        .buttonStyle(PlainButtonStyle()) // Tıklama efektini düzeltmek için
    }
}
    


// MARK: - Components

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.captionBold)
                .foregroundColor(isSelected ? AppColor.onPrimary : AppColor.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppColor.primary : AppColor.surface)
                .cornerRadius(Radius.pill)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.pill)
                        .stroke(isSelected ? Color.clear : AppColor.border, lineWidth: 1)
                )
        }
    }
}
