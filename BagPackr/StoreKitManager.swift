//
//  StoreKitManager.swift
//  BagPackr
//
//  Native StoreKit 2 Implementation - RevenueCat Replacement
//

import Foundation
import StoreKit
import Combine

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var isPremium = false
    @Published var subscriptionInfo: SubscriptionDetails?
    
    // MARK: - Product IDs (App Store Connect'teki Product ID'ler)
    private let productIDs = [
        "bagpckr_premium_monthly",
        "bagpckr_premium_yearly"
    ]
    
    // Transaction listener
    private var updateListenerTask: Task<Void, Never>?
    
    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            self.products = storeProducts.sorted { $0.price < $1.price }
            
            print("✅ Loaded \(products.count) products:")
            for product in products {
                print("  - \(product.displayName): \(product.displayPrice)")
            }
        } catch {
            print("❌ Failed to load products: \(error)")
        }
    }
    
    // MARK: - Check Subscription Status
    func checkSubscriptionStatus() async {
        var isActive = false
        var details: SubscriptionDetails?
        
        // Check all current entitlements
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            // Check if this is one of our premium products
            if productIDs.contains(transaction.productID) {
                isActive = true
                
                // Get subscription details
                if let expirationDate = transaction.expirationDate {
                    details = SubscriptionDetails(
                        productId: transaction.productID,
                        purchaseDate: transaction.purchaseDate,
                        expirationDate: expirationDate,
                        willAutoRenew: transaction.revocationDate == nil
                    )
                }
                
                print("✅ Active subscription: \(transaction.productID)")
                break
            }
        }
        
        self.isPremium = isActive
        self.subscriptionInfo = details
        
        print("📊 Premium Status: \(isActive ? "Premium ✨" : "Free")")
        
        // Update AdManager if you're using it
        // AdManager.shared.shouldShowAds = !isActive
        
        // Update Firestore if you're using Firebase
        // await updateFirestore(isPremium: isActive)
    }
    
    // MARK: - Purchase Product
    func purchase(_ product: Product) async throws {
        print("🛒 Attempting purchase: \(product.displayName)")
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Verify the transaction
            switch verification {
            case .verified(let transaction):
                // Successful purchase
                await transaction.finish()
                await checkSubscriptionStatus()
                
                print("✅ Purchase successful!")
                
                // Notify views
                NotificationCenter.default.post(
                    name: NSNotification.Name("PremiumPurchased"),
                    object: nil
                )
                
                return
                
            case .unverified(_, let error):
                // Failed verification
                throw StoreError.failedVerification(error)
            }
            
        case .userCancelled:
            print("⚠️ User cancelled purchase")
            throw StoreError.cancelled
            
        case .pending:
            print("⚠️ Purchase pending")
            throw StoreError.pending
            
        @unknown default:
            throw StoreError.unknown
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async throws {
        print("🔄 Restoring purchases...")
        
        try await AppStore.sync()
        await checkSubscriptionStatus()
        
        if isPremium {
            print("✅ Purchases restored!")
            
            // Notify views
            NotificationCenter.default.post(
                name: NSNotification.Name("PremiumRestored"),
                object: nil
            )
        } else {
            print("⚠️ No active subscriptions found")
            throw StoreError.nothingToRestore
        }
    }
    
    // MARK: - Listen for Transactions
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            // Listen for transaction updates
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else {
                    continue
                }
                
                // Finish the transaction
                await transaction.finish()
                
                // Update subscription status
                await self.checkSubscriptionStatus()
                
                print("🔔 Transaction updated: \(transaction.productID)")
            }
        }
    }
    
    // MARK: - Get Product by ID
    func getProduct(id: String) -> Product? {
        return products.first { $0.id == id }
    }
    
    // MARK: - Get Subscription Details String
    func getSubscriptionDetailsString() -> String? {
        guard let info = subscriptionInfo else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if info.willAutoRenew {
            return "Renews on \(formatter.string(from: info.expirationDate))"
        } else {
            return "Expires on \(formatter.string(from: info.expirationDate))"
        }
    }
    
    // MARK: - Get Monthly Product
    var monthlyProduct: Product? {
        return products.first { $0.id == "bagpckr_premium_monthly" }
    }
    
    // MARK: - Get Yearly Product
    var yearlyProduct: Product? {
        return products.first { $0.id == "bagpckr_premium_yearly" }
    }
}

// MARK: - Supporting Types

struct SubscriptionDetails {
    let productId: String
    let purchaseDate: Date
    let expirationDate: Date
    let willAutoRenew: Bool
    
    var isActive: Bool {
        return expirationDate > Date()
    }
}

enum StoreError: LocalizedError {
    case cancelled
    case pending
    case nothingToRestore
    case failedVerification(Error)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Purchase was cancelled"
        case .pending:
            return "Payment is pending"
        case .nothingToRestore:
            return "No purchases to restore"
        case .failedVerification(let error):
            return "Failed to verify purchase: \(error.localizedDescription)"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
