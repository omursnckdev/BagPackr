//
//  RevenueCatManager.swift
//  BagPackr
//
//  Created by Ömür Şenocak
//

import Foundation
import RevenueCat
import RevenueCatUI
import FirebaseAuth
import Combine

class RevenueCatManager: ObservableObject {
    static let shared = RevenueCatManager()
    
    @Published var isSubscribed = false
    @Published var currentOffering: Offering?
    @Published var subscriptionInfo: SubscriptionInfo?
    
    // ⭐ RevenueCat API Key
    private let apiKey = "appl_BovfdDFYJtAVgbMvsKENjnYZdxq"
    
    private init() {
        configure()
    }
    
    // MARK: - Configuration
    func configure() {
        Purchases.logLevel = .info // Production'da .info yapın
        Purchases.configure(withAPIKey: apiKey)
        
        print("✅ RevenueCat configured")
    }
    
    // MARK: - Set User ID
    func identifyUser(_ userId: String) {
        Purchases.shared.logIn(userId) { customerInfo, created, error in
            if let error = error {
                print("❌ Error identifying user: \(error)")
                return
            }
            
            if created {
                print("✅ New RevenueCat customer created")
            }
            
            self.checkSubscriptionStatus(customerInfo: customerInfo)
        }
    }
    
    // MARK: - Fetch Offerings
    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            
            await MainActor.run {
                self.currentOffering = offerings.current
                print("✅ Offerings fetched: \(offerings.current?.availablePackages.count ?? 0) packages")
            }
        } catch {
            print("❌ Error fetching offerings: \(error)")
        }
    }


    func getTrialInfo(for package: Package) -> (hasTrial: Bool, duration: String?) {
        guard let introDiscount = package.storeProduct.introductoryDiscount,
              introDiscount.price == 0 else { // Free trial check
            return (false, nil)
        }
        
        let period = introDiscount.subscriptionPeriod
        let value = period.value
        let unit: String = {
            switch period.unit {
            case .day: return value == 1 ? "day" : "days"
            case .week: return value == 1 ? "week" : "weeks"
            case .month: return value == 1 ? "month" : "months"
            case .year: return value == 1 ? "year" : "years"
            @unknown default: return "days"
            }
        }()
        
        return (true, "\(value) \(unit)")
    }
    
    // MARK: - Check Subscription Status
    func checkSubscriptionStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            await MainActor.run {
                self.checkSubscriptionStatus(customerInfo: customerInfo)
            }
        } catch {
            print("❌ Error checking subscription: \(error)")
        }
    }
    
    private func checkSubscriptionStatus(customerInfo: CustomerInfo?) {
        guard let customerInfo = customerInfo else {
            self.isSubscribed = false
            
            // ⭐ Update AdManager when no subscription
            AdManager.shared.shouldShowAds = true
            return
        }
        
        // Check if user has active entitlement
        let isPremium = customerInfo.entitlements.all["premium"]?.isActive == true
        self.isSubscribed = isPremium
        
        // ⭐ CRITICAL: Update AdManager immediately
        AdManager.shared.shouldShowAds = !isPremium
        
        // Extract subscription info
        if let entitlement = customerInfo.entitlements.all["premium"],
           entitlement.isActive {
            self.subscriptionInfo = SubscriptionInfo(
                productIdentifier: entitlement.productIdentifier,
                purchaseDate: entitlement.originalPurchaseDate,
                expirationDate: entitlement.expirationDate,
                willRenew: entitlement.willRenew,
                periodType: entitlement.periodType
            )
        }
        
        print("📊 Subscription: \(isPremium ? "Premium ✨" : "Free"), Ads: \(AdManager.shared.shouldShowAds)")
        
        // ⭐ Update Firestore
        Task {
            if let userId = Auth.auth().currentUser?.uid {
                try? await FirestoreService.shared.updateUserPremiumStatus(
                    userId: userId,
                    isPremium: isPremium
                )
            }
        }
        
        // ⭐ Analytics
        AnalyticsService.shared.setUserProperty(isPremium: isPremium)
    }
    
    // MARK: - Purchase Package
    func purchase(package: Package) async throws {
        // ⭐ Analytics
        AnalyticsService.shared.logPremiumPurchaseStarted()
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            await MainActor.run {
                self.checkSubscriptionStatus(customerInfo: result.customerInfo)
                
                // ⭐ CRITICAL: Immediately hide ads after successful purchase
                if self.isSubscribed {
                    AdManager.shared.shouldShowAds = false
                    print("🎉 Premium activated! Ads removed immediately.")
                    
                    // ⭐ Notify all views to refresh
                    NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
                }
            }
            
            // ⭐ Analytics
            let priceDecimal = package.storeProduct.price
            let priceDouble = NSDecimalNumber(decimal: priceDecimal).doubleValue
            AnalyticsService.shared.logPremiumPurchaseCompleted(price: priceDouble)
            
            print("✅ Purchase successful!")
            
        } catch let error as ErrorCode {
            switch error {
            case .purchaseCancelledError:
                print("⚠️ Purchase cancelled by user")
                throw PurchaseError.cancelled
            case .paymentPendingError:
                print("⚠️ Payment pending")
                throw PurchaseError.pending
            case .productAlreadyPurchasedError:
                print("⚠️ Already purchased")
                throw PurchaseError.failed("You already own this subscription")
            case .networkError:
                print("⚠️ Network error")
                throw PurchaseError.failed("Network error. Please check your connection.")
            default:
                print("❌ Purchase error: \(error.localizedDescription)")
                throw PurchaseError.failed(error.localizedDescription)
            }
        } catch {
            print("❌ Unexpected error: \(error)")
            throw PurchaseError.failed(error.localizedDescription)
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async throws {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            
            await MainActor.run {
                self.checkSubscriptionStatus(customerInfo: customerInfo)
                
                // ⭐ CRITICAL: Immediately hide ads after successful restore
                if self.isSubscribed {
                    AdManager.shared.shouldShowAds = false
                    print("🎉 Premium restored! Ads removed immediately.")
                    
                    // ⭐ Notify all views to refresh
                    NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
                }
            }
            
            if customerInfo.entitlements.all["premium"]?.isActive == true {
                // ⭐ Analytics
                AnalyticsService.shared.logPremiumRestored()
                print("✅ Purchases restored!")
            } else {
                throw PurchaseError.nothingToRestore
            }
            
        } catch {
            print("❌ Restore error: \(error)")
            
            if let errorCode = error as? ErrorCode {
                switch errorCode {
                case .receiptAlreadyInUseError:
                    throw PurchaseError.failed("This receipt is already in use")
                default:
                    throw PurchaseError.failed(errorCode.localizedDescription)
                }
            }
            
            throw PurchaseError.failed(error.localizedDescription)
        }
    }
    
    // MARK: - Get Subscription Details
    func getSubscriptionDetails() -> String? {
        guard let info = subscriptionInfo else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if info.willRenew {
            return "Renews on \(formatter.string(from: info.expirationDate ?? Date()))"
        } else {
            return "Expires on \(formatter.string(from: info.expirationDate ?? Date()))"
        }
    }
}

// MARK: - Supporting Types

struct SubscriptionInfo {
    let productIdentifier: String
    let purchaseDate: Date?
    let expirationDate: Date?
    let willRenew: Bool
    let periodType: PeriodType
}

enum PurchaseError: LocalizedError {
    case cancelled
    case pending
    case nothingToRestore
    case failed(String)
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Purchase was cancelled"
        case .pending:
            return "Payment is pending"
        case .nothingToRestore:
            return "No purchases to restore"
        case .failed(let message):
            return message
        }
    }
}
