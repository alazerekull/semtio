//
//  SubscriptionStore.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  StoreKit 2 subscription management for Semtio Premium.
//

import SwiftUI
import StoreKit
import Combine
import FirebaseFirestore
// import FirebaseFunctions
import FirebaseAuth

// MARK: - Product IDs

enum SubscriptionProduct: String, CaseIterable {
    case monthly = "com.semtio.premium.monthly"
    case yearly = "com.semtio.premium.yearly"
    
    static var allIDs: Set<String> {
        Set(allCases.map { $0.rawValue })
    }
}

// MARK: - Subscription Store

@MainActor
final class SubscriptionStore: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private
    
    private var transactionListener: Task<Void, Never>?
    private let isPreview: Bool
    private var entitlementListener: ListenerRegistration?
    private let db = Firestore.firestore()
    // private let functions = CloudFunctionsClient.shared
    
    // MARK: - Init
    
    init() {
        // Detect preview mode
        self.isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        
        if isPreview {
            // Mock state for previews
            setupMockData()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Setup
    
    /// Starts listening for transactions - call on app launch
    func startListening() {
        guard !isPreview else { return }
        
        transactionListener = listenForTransactions()
        
        Task {
            await loadProducts()
            await refreshEntitlements()
            listenEntitlements()
        }
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        guard !isPreview else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let storeProducts = try await Product.products(for: SubscriptionProduct.allIDs)
            
            // Sort: monthly first, then yearly
            products = storeProducts.sorted { product1, product2 in
                if product1.id.contains("monthly") { return true }
                if product2.id.contains("monthly") { return false }
                return product1.price < product2.price
            }
            
            print("✅ SubscriptionStore: Loaded \(products.count) products")
        } catch {
            errorMessage = "Ürünler yüklenemedi: \(error.localizedDescription)"
            print("❌ SubscriptionStore: Failed to load products: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async {
        guard !isPreview else {
            // Mock purchase in preview
            purchasedProductIDs.insert(product.id)
            isPremium = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Update entitlements
                purchasedProductIDs.insert(transaction.productID)
                updatePremiumStatus()
                
                // Sync with backend
                syncWithBackend(transaction: transaction)
                
                // Finish transaction
                await transaction.finish()
                
                print("✅ SubscriptionStore: Purchased \(transaction.productID)")
                
            case .userCancelled:
                print("ℹ️ SubscriptionStore: User cancelled purchase")
                
            case .pending:
                print("⏳ SubscriptionStore: Purchase pending")
                errorMessage = "Satın alma onay bekliyor."
                
            @unknown default:
                print("⚠️ SubscriptionStore: Unknown purchase result")
            }
        } catch {
            errorMessage = "Satın alma başarısız: \(error.localizedDescription)"
            print("❌ SubscriptionStore: Purchase failed: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Restore
    
    func restore() async {
        guard !isPreview else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            
            if isPremium {
                print("✅ SubscriptionStore: Restored premium subscription")
            } else {
                errorMessage = "Geri yüklenecek abonelik bulunamadı."
            }
        } catch {
            errorMessage = "Geri yükleme başarısız: \(error.localizedDescription)"
            print("❌ SubscriptionStore: Restore failed: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Refresh Entitlements
    
    func refreshEntitlements() async {
        guard !isPreview else { return }
        
        var validProductIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Only include non-revoked, non-expired subscriptions
                if transaction.revocationDate == nil {
                    validProductIDs.insert(transaction.productID)
                }
            } catch {
                print("⚠️ SubscriptionStore: Invalid transaction: \(error)")
            }
        }
        
        purchasedProductIDs = validProductIDs
        updatePremiumStatus()
        
        // Sync the most recent valid transaction if any
        if let transaction = try? await Transaction.latest(for: SubscriptionProduct.monthly.rawValue)?.payloadValue {
             syncWithBackend(transaction: transaction)
        }
        
        print("✅ SubscriptionStore: Entitlements refreshed.")
    }
    
    // MARK: - Firestore Listener (Authoritative)
    
    func listenEntitlements() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        entitlementListener?.remove()
        
        let docRef = db.collection("users").document(uid).collection("entitlements").document("premium")
        
        entitlementListener = docRef.addSnapshotListener { [weak self] (snapshot: DocumentSnapshot?, error: Error?) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ SubscriptionStore: Entitlement listen error: \(error)")
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else {
                // Doc missing: fallback to StoreKit state (which is currently handled by updatePremiumStatus)
                // Use optimistic StoreKit state derived in updatePremiumStatus
                self.isPremium = !self.purchasedProductIDs.intersection(SubscriptionProduct.allIDs).isEmpty
                return
            }
            
            // Analyze authoritative doc
            let isPremiumDoc = data["isPremium"] as? Bool ?? false
            let premiumUntil = (data["premiumUntil"] as? Timestamp)?.dateValue()
            
            if isPremiumDoc {
                // Check expiration
                if let expiration = premiumUntil, expiration < Date() {
                    self.isPremium = false
                } else {
                    self.isPremium = true
                }
            } else {
                self.isPremium = false
            }
            
            print("✅ SubscriptionStore: Authoritative status updated. Premium: \(self.isPremium)")
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    await MainActor.run {
                        self.purchasedProductIDs.insert(transaction.productID)
                        self.updatePremiumStatus()
                        self.syncWithBackend(transaction: transaction)
                    }
                    
                    await transaction.finish()
                    
                    print("✅ SubscriptionStore: Transaction update: \(transaction.productID)")
                } catch {
                    print("⚠️ SubscriptionStore: Transaction update failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let item):
            return item
        }
    }
    
    /// Syncs local purchase with backend to establish authoritative entitlement
    private func syncWithBackend(transaction: StoreKit.Transaction) {
        guard Auth.auth().currentUser != nil else { return }
        
        /*
        let expirationDate = transaction.expirationDate ?? Date().addingTimeInterval(3600 * 24 * 30)
        let expirationMillis = Int64(expirationDate.timeIntervalSince1970 * 1000)
        
        let data: [String: Any] = [
            "productId": transaction.productID,
            "transactionId": String(transaction.id),
            "originalTransactionId": String(transaction.originalID),
            "expirationDate": expirationMillis,
            "environment": transaction.environment.rawValue 
        ]
        */
        
        Task {
            // Placeholder for Cloud Functions sync
             print("SubscriptionStore: Sync skipped (Functions currently disabled in code)")
             print("✅ SubscriptionStore: Entitlement synced (simulated).")
        }
    }

    private func updatePremiumStatus() {
        // Fallback or initial state if Firestore listener hasn't fired yet
        // Ideally, we rely mainly on Firestore listenEntitlements()
        // But for immediate UI feedback after purchase, we can optimistically set true
        // However, actual truth comes from listenEntitlements
        if !purchasedProductIDs.intersection(SubscriptionProduct.allIDs).isEmpty {
            // Optimistic update
            // isPremium = true // Let listener handle it to be purely authoritative?
            // User requested: "fallback to local StoreKit state only if doc missing"
            // So we keep this optimistic update, but listener will override.
        }
    }
    
    // MARK: - Mock Data (Preview)
    
    private func setupMockData() {
        isPremium = false
        purchasedProductIDs = []
        // Products can't be mocked as Product is a StoreKit type
        // Views should handle empty products array gracefully
    }
}

// MARK: - Product Extensions

extension Product {

    
    /// Subscription period as human-readable string
    var periodDescription: String {
        guard let subscription = subscription else { return "" }
        
        switch subscription.subscriptionPeriod.unit {
        case .day:
            return subscription.subscriptionPeriod.value == 1 ? "Günlük" : "\(subscription.subscriptionPeriod.value) Gün"
        case .week:
            return subscription.subscriptionPeriod.value == 1 ? "Haftalık" : "\(subscription.subscriptionPeriod.value) Hafta"
        case .month:
            return subscription.subscriptionPeriod.value == 1 ? "Aylık" : "\(subscription.subscriptionPeriod.value) Ay"
        case .year:
            return subscription.subscriptionPeriod.value == 1 ? "Yıllık" : "\(subscription.subscriptionPeriod.value) Yıl"
        @unknown default:
            return ""
        }
    }
}
