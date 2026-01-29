//
//  PaywallView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Premium subscription paywall with StoreKit 2 integration.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProductId: String?
    @State private var showError = false
    
    private var subscription: SubscriptionStore {
        appState.subscription
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.semtioPrimary.opacity(0.15),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    .padding()
                }
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Semtio Premium")
                                .font(AppFont.largeTitle)
                                .foregroundColor(.semtioDarkText)
                            
                            if subscription.isPremium {
                                PremiumActiveTag()
                            }
                        }
                        .padding(.top, 8)
                        
                        // Benefits list
                        BenefitsSection()
                        
                        // Product picker (only show if not already premium)
                        if !subscription.isPremium {
                            ProductPickerSection(
                                products: subscription.products,
                                selectedProductId: $selectedProductId,
                                isLoading: subscription.isLoading
                            )
                        }
                        
                        // Action buttons
                        ActionButtonsSection(
                            isPremium: subscription.isPremium,
                            isLoading: subscription.isLoading,
                            selectedProduct: selectedProduct,
                            onPurchase: {
                                Task {
                                    if let product = selectedProduct {
                                        await subscription.purchase(product)
                                    }
                                }
                            },
                            onRestore: {
                                Task {
                                    await subscription.restore()
                                }
                            }
                        )
                        
                        // Legal links
                        LegalLinksSection()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            await subscription.loadProducts()
            await subscription.refreshEntitlements()
            
            // Auto-select first product
            if selectedProductId == nil, let first = subscription.products.first {
                selectedProductId = first.id
            }
        }
        .onChange(of: subscription.errorMessage) { _, error in
            showError = error != nil
        }
        .alert("Hata", isPresented: $showError) {
            Button("Tamam") {
                appState.subscription.errorMessage = nil
            }
        } message: {
            Text(subscription.errorMessage ?? "Bir hata oluştu.")
        }
    }
    
    private var selectedProduct: Product? {
        subscription.products.first { $0.id == selectedProductId }
    }
}

// MARK: - Premium Active Tag

private struct PremiumActiveTag: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
            Text("Premium Aktif")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundColor(AppColor.onPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
    }
}

// MARK: - Benefits Section

private struct BenefitsSection: View {
    private let benefits = [
        ("infinity", "Sınırsız etkinlik oluşturma"),
        ("slider.horizontal.3", "Gelişmiş filtreler"),
        ("star.fill", "Öne çıkan görünüm"),
        ("sparkle.magnifyingglass", "Daha iyi keşif")
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(benefits, id: \.1) { icon, text in
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.semtioPrimary.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.semtioPrimary)
                    }
                    
                    Text(text)
                        .font(.body)
                        .foregroundColor(.semtioDarkText)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
}

// MARK: - Product Picker Section

private struct ProductPickerSection: View {
    let products: [Product]
    @Binding var selectedProductId: String?
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            if isLoading && products.isEmpty {
                HStack {
                    ProgressView()
                    Text("Planlar yükleniyor...")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if products.isEmpty {
                Text("Planlar yüklenemedi")
                    .foregroundColor(.gray)
                    .padding(.vertical, 24)
            } else {
                ForEach(products, id: \.id) { product in
                    ProductCard(
                        product: product,
                        isSelected: selectedProductId == product.id,
                        onSelect: { selectedProductId = product.id }
                    )
                }
            }
        }
    }
}

// MARK: - Product Card

private struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var isYearly: Bool {
        product.id.contains("yearly")
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(isYearly ? "Yıllık" : "Aylık")
                            .font(.headline)
                            .foregroundColor(.semtioDarkText)
                        
                        if isYearly {
                            Text("En Popüler")
                                .font(.caption.weight(.bold))
                                .foregroundColor(AppColor.onPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.orange)
                                )
                        }
                    }
                    
                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.semtioPrimary)
                    
                    Text(isYearly ? "/yıl" : "/ay")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.semtioPrimary : AppColor.textSecondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.semtioPrimary.opacity(0.05) : Color.clear)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Action Buttons Section

private struct ActionButtonsSection: View {
    let isPremium: Bool
    let isLoading: Bool
    let selectedProduct: Product?
    let onPurchase: () -> Void
    let onRestore: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Primary button
            Button(action: onPurchase) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: isPremium ? "checkmark.circle.fill" : "crown.fill")
                        Text(isPremium ? "Premium Aktif" : "Premium Ol")
                    }
                }
                .font(.headline)
                .foregroundColor(AppColor.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isPremium ? Color.green : Color.semtioPrimary)
                )
            }
            .disabled(isPremium || isLoading || selectedProduct == nil)
            .opacity((isPremium || selectedProduct == nil) && !isLoading ? 0.6 : 1)
            
            // Restore button
            Button(action: onRestore) {
                Text("Satın Alımları Geri Yükle")
                    .font(.subheadline)
                    .foregroundColor(.semtioPrimary)
            }
            .disabled(isLoading)
        }
    }
}

// MARK: - Legal Links Section

private struct LegalLinksSection: View {
    var body: some View {
        HStack(spacing: 16) {
            Link("Kullanım Koşulları", destination: URL(string: "https://semtio.app/terms")!)
            
            Text("•")
                .foregroundColor(.gray)
            
            Link("Gizlilik Politikası", destination: URL(string: "https://semtio.app/privacy")!)
        }
        .font(.caption)
        .foregroundColor(.gray)
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
        .environmentObject(AppState(
            session: SessionManager(),
            theme: AppThemeManager(),
            location: LocationManager()
        ))
}
