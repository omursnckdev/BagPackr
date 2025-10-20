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
    
    init() {
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
            // Check StoreKit first
            let storeIsPremium = StoreManager.shared.isPremium
            
            // Also check Firestore
            let firestoreIsPremium = try await FirestoreService.shared.getUserPremiumStatus(userId: userId)
            
            isPremium = storeIsPremium || firestoreIsPremium
            
            print("✅ Premium status: \(isPremium)")
            
        } catch {
            print("❌ Error checking premium status: \(error)")
            isPremium = false
        }
    }
    
    func upgradeToPremium() async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        try await FirestoreService.shared.updateUserPremiumStatus(userId: userId, isPremium: true)
        isPremium = true
    }
    
    // MARK: - Active Plans Count (⭐ FIXED - Counts BOTH types!)
    
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
        // Refresh counts
        await checkPremiumStatus()
        await loadActivePlansCount()
        
        // Premium users = unlimited
        if isPremium {
            return (true, nil)
        }
        
        // Free users = check limit
        if activePlansCount >= FREE_TIER_LIMIT {
            return (false, "Free tier limit reached. Upgrade to Premium for unlimited plans!")
        }
        
        return (true, nil)
    }
    
    // Call this after successfully creating a plan
    func incrementPlanCount() async {
        await loadActivePlansCount()
        print("📊 Plan count after increment: \(activePlansCount)/\(FREE_TIER_LIMIT)")
    }
    
    // Call this after deleting a plan
    func decrementPlanCount() async {
        await loadActivePlansCount()
        print("📊 Plan count after decrement: \(activePlansCount)/\(FREE_TIER_LIMIT)")
    }
    
    // MARK: - Delete Plan (to free up slot)
    
    func deletePlan(planId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Try to delete from itineraries collection
        let itineraryRef = db.collection("itineraries").document(planId)
        let itineraryDoc = try? await itineraryRef.getDocument()
        
        if itineraryDoc?.exists == true {
            try await itineraryRef.delete()
            print("✅ Regular itinerary deleted: \(planId)")
        } else {
            // Try multi-city collection
            let multiCityRef = db.collection("multiCityItineraries").document(planId)
            let multiCityDoc = try? await multiCityRef.getDocument()
            
            if multiCityDoc?.exists == true {
                try await multiCityRef.delete()
                print("✅ Multi-city itinerary deleted: \(planId)")
            } else {
                print("⚠️ Plan not found: \(planId)")
            }
        }
        
        // Refresh count
        await loadActivePlansCount()
        
        print("✅ Plan deleted, remaining slots: \(remainingPlans)")
    }
}
