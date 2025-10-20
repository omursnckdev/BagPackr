//
//  StoreManager.swift
//  BagPackr
//

import StoreKit
import SwiftUI
import Combine

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    
    private var updateListenerTask: Task<Void, Error>?
    
    // Product IDs - match these with App Store Connect
    private let productIDs = [
        "com.bagpackr.premium.monthly",
        "com.bagpackr.premium.yearly"
    ]
    
    init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        isLoading = true
        print("🛒 Starting to load products...")
        
        do {
            let productIdentifiers = [
                "com.yourapp.premium.monthly",
                "com.yourapp.premium.yearly"
            ]
            
            print("🛒 Product IDs: \(productIdentifiers)")
            
            let loadedProducts = try await Product.products(for: productIdentifiers)
            
            print("🛒 Loaded \(loadedProducts.count) products")
            for product in loadedProducts {
                print("🛒 Product: \(product.id) - \(product.displayName) - \(product.displayPrice)")
            }
            
            await MainActor.run {
                self.products = loadedProducts
                self.isLoading = false
            }
        } catch {
            print("❌ Failed to load products: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        print("🛒 Starting purchase for: \(product.displayName)")
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            print("✅ Purchase successful")
            
            // Verify the transaction
            let transaction = try checkVerified(verification)
            
            // Update purchased products
            await updatePurchasedProducts()
            
            // Mark as premium in Firestore
            await updateUserPremiumStatus(isPremium: true)
            
            // Finish the transaction
            await transaction.finish()
            
            return true
            
        case .userCancelled:
            print("⚠️ User cancelled purchase")
            return false
            
        case .pending:
            print("⏳ Purchase pending")
            return false
            
        @unknown default:
            print("❌ Unknown purchase result")
            return false
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        
        print("🔄 Restoring purchases...")
        
        try await AppStore.sync()
        
        await updatePurchasedProducts()
        
        if purchasedProductIDs.isEmpty {
            throw StoreError.noPurchasesToRestore
        }
    }
    
    // MARK: - Check Subscription Status
    
    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.revocationDate == nil {
                purchasedIDs.insert(transaction.productID)
            }
        }
        
        purchasedProductIDs = purchasedIDs
        
        // Update premium status
        let isPremium = !purchasedIDs.isEmpty
        await updateUserPremiumStatus(isPremium: isPremium)
        
        print("✅ User premium status: \(isPremium)")
    }
    
    var isPremium: Bool {
        !purchasedProductIDs.isEmpty
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else {
                    continue
                }
                
                await self.updatePurchasedProducts()
                await transaction.finish()
            }
        }
    }
    
    // MARK: - Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Firestore Integration
    
    private func updateUserPremiumStatus(isPremium: Bool) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await FirestoreService.shared.updateUserPremiumStatus(
                userId: userId,
                isPremium: isPremium
            )
            
            // Update PlanLimitService
            await PlanLimitService.shared.checkPremiumStatus()
            
        } catch {
            print("❌ Error updating premium status: \(error)")
        }
    }
}

// MARK: - Store Errors

enum StoreError: LocalizedError {
    case failedVerification
    case noPurchasesToRestore
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Failed to verify purchase"
        case .noPurchasesToRestore:
            return "No purchases found to restore"
        }
    }
}

// MARK: - Import Firebase
import FirebaseAuth
