//
//  PlanLimitService.swift
//  BagPackr
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class PlanLimitService: ObservableObject {
    static let shared = PlanLimitService()
    
    @Published var isPremium: Bool = false
    @Published var activePlansCount: Int = 0
    
    private let FREE_TIER_LIMIT = 1  // 1 aktif plan (toplam)
    private let db = Firestore.firestore()
    
    var remainingPlans: Int {
        isPremium ? 999 : max(0, FREE_TIER_LIMIT - activePlansCount)
    }
    
    var canCreatePlan: Bool {
        isPremium || activePlansCount < FREE_TIER_LIMIT
    }
    
    private init() {
        Task {
            await checkPremiumStatus()
            await loadActivePlansCount()
        }
    }
    
    // MARK: - Premium Status
    
    func checkPremiumStatus() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            isPremium = false
            return
        }
        
        do {
            // ⭐ FIXED: Check RevenueCat instead of StoreManager
            await RevenueCatManager.shared.checkSubscriptionStatus()
            let revenueCatIsPremium = RevenueCatManager.shared.isSubscribed
            
            // Also check Firestore (backup/sync)
            let firestoreIsPremium = try await FirestoreService.shared.getUserPremiumStatus(userId: userId)
            
            // User is premium if EITHER RevenueCat OR Firestore says so
            isPremium = revenueCatIsPremium || firestoreIsPremium
            
            // ⭐ Sync: If RevenueCat says premium but Firestore doesn't, update Firestore
            if revenueCatIsPremium && !firestoreIsPremium {
                try await FirestoreService.shared.updateUserPremiumStatus(userId: userId, isPremium: true)
                print("✅ Synced premium status to Firestore")
            }
            
            // ⭐ Sync: If Firestore says premium but RevenueCat doesn't, trust RevenueCat
            if !revenueCatIsPremium && firestoreIsPremium {
                try await FirestoreService.shared.updateUserPremiumStatus(userId: userId, isPremium: false)
                print("⚠️ Subscription expired, updated Firestore")
            }
            
            print("📊 Premium status: \(isPremium) (RevenueCat: \(revenueCatIsPremium), Firestore: \(firestoreIsPremium))")
            
        } catch {
            print("❌ Error checking premium status: \(error)")
            isPremium = false
        }
    }
    
    func upgradeToPremium() async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        try await FirestoreService.shared.updateUserPremiumStatus(userId: userId, isPremium: true)
        isPremium = true
        
        print("✅ Upgraded to premium")
    }
    
    // MARK: - Active Plans Count (Counts BOTH types!)
    
    func loadActivePlansCount() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // ⭐ Count regular itineraries
            let itinerariesSnapshot = try await db.collection("itineraries")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let regularCount = itinerariesSnapshot.documents.count
            
            // ⭐ Count multi-city itineraries
            let multiCitySnapshot = try await db.collection("multiCityItineraries")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let multiCityCount = multiCitySnapshot.documents.count
            
            // ⭐ Total = regular + multi-city
            activePlansCount = regularCount + multiCityCount
            
            print("✅ Active plans count: \(activePlansCount) (Regular: \(regularCount), Multi-city: \(multiCityCount))")
            
        } catch {
            print("❌ Error loading active plans count: \(error)")
            activePlansCount = 0
        }
    }
    
    // MARK: - Plan Creation Check
    
    func canGeneratePlan() async -> (canCreate: Bool, reason: String?) {
        // ⭐ Refresh premium status from RevenueCat
        await checkPremiumStatus()
        
        // Refresh plan counts
        await loadActivePlansCount()
        
        // Premium users = unlimited
        if isPremium {
            print("✅ Premium user - unlimited plans")
            return (true, nil)
        }
        
        // Free users = check limit
        if activePlansCount >= FREE_TIER_LIMIT {
            let message = "You've reached the free plan limit (\(FREE_TIER_LIMIT) plan). Upgrade to Premium for unlimited plans!"
            print("⚠️ \(message)")
            return (false, message)
        }
        
        print("✅ Free user can create plan (\(activePlansCount)/\(FREE_TIER_LIMIT))")
        return (true, nil)
    }
    
    // Call this after successfully creating a plan
    func incrementPlanCount() async {
        await loadActivePlansCount()
        print("📊 Plan count after increment: \(activePlansCount)/\(FREE_TIER_LIMIT) (Remaining: \(remainingPlans))")
    }
    
    // Call this after deleting a plan
    func decrementPlanCount() async {
        await loadActivePlansCount()
        print("📊 Plan count after decrement: \(activePlansCount)/\(FREE_TIER_LIMIT) (Remaining: \(remainingPlans))")
    }
    
    // MARK: - Delete Plan (to free up slot)
    
    func deletePlan(planId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "PlanLimit", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Try to delete from itineraries collection
        let itineraryRef = db.collection("itineraries").document(planId)
        let itineraryDoc = try? await itineraryRef.getDocument()
        
        if itineraryDoc?.exists == true {
            // Verify ownership
            if let data = itineraryDoc?.data(),
               let ownerId = data["userId"] as? String,
               ownerId == userId {
                try await itineraryRef.delete()
                print("✅ Regular itinerary deleted: \(planId)")
            } else {
                throw NSError(domain: "PlanLimit", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to delete this plan"])
            }
        } else {
            // Try multi-city collection
            let multiCityRef = db.collection("multiCityItineraries").document(planId)
            let multiCityDoc = try? await multiCityRef.getDocument()
            
            if multiCityDoc?.exists == true {
                // Verify ownership
                if let data = multiCityDoc?.data(),
                   let ownerId = data["userId"] as? String,
                   ownerId == userId {
                    try await multiCityRef.delete()
                    print("✅ Multi-city itinerary deleted: \(planId)")
                } else {
                    throw NSError(domain: "PlanLimit", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to delete this plan"])
                }
            } else {
                throw NSError(domain: "PlanLimit", code: 404, userInfo: [NSLocalizedDescriptionKey: "Plan not found"])
            }
        }
        
        // Refresh count
        await loadActivePlansCount()
        
        print("✅ Plan deleted, remaining slots: \(remainingPlans)")
    }
    
    // MARK: - Helper: Get Plan Status Summary
    
    func getPlanStatusSummary() -> String {
        if isPremium {
            return "Premium - Unlimited Plans"
        } else {
            return "\(activePlansCount)/\(FREE_TIER_LIMIT) plans used"
        }
    }
}
