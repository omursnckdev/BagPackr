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
    @Published var plansCreatedToday: Int = 0
    @Published var nextResetTime: Date?
    
    private let maxFreePlans = 3
    private let db = Firestore.firestore()
    
    var remainingPlans: Int {
        isPremium ? 999 : max(0, maxFreePlans - plansCreatedToday)
    }
    
    init() {
        Task {
            await checkPremiumStatus()
            await loadPlanCount()
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
            
            // Also check Firestore (in case user is on different device)
            let firestoreIsPremium = try await FirestoreService.shared.getUserPremiumStatus(userId: userId)
            
            isPremium = storeIsPremium || firestoreIsPremium
            
            print("✅ Premium status: \(isPremium) (Store: \(storeIsPremium), Firestore: \(firestoreIsPremium))")
            
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
    
    // MARK: - Plan Counting
    
    func loadPlanCount() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("planLimits")
                .document("current")
                .getDocument()
            
            if let data = snapshot.data(),
               let count = data["count"] as? Int,
               let timestamp = data["date"] as? Timestamp {
                
                let savedDate = Calendar.current.startOfDay(for: timestamp.dateValue())
                
                if savedDate == today {
                    plansCreatedToday = count
                    nextResetTime = Calendar.current.date(byAdding: .day, value: 1, to: today)
                } else {
                    // New day, reset count
                    plansCreatedToday = 0
                    nextResetTime = Calendar.current.date(byAdding: .day, value: 1, to: today)
                    try await resetDailyCount()
                }
            } else {
                plansCreatedToday = 0
                nextResetTime = Calendar.current.date(byAdding: .day, value: 1, to: today)
            }
        } catch {
            print("❌ Error loading plan count: \(error)")
        }
    }
    
    func canGeneratePlan() -> Bool {
        return isPremium || plansCreatedToday < maxFreePlans
    }
    
    func incrementPlanCount() async throws {
        guard !isPremium else { return }
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        plansCreatedToday += 1
        
        try await db.collection("users")
            .document(userId)
            .collection("planLimits")
            .document("current")
            .setData([
                "count": plansCreatedToday,
                "date": Timestamp(date: Date())
            ])
    }
    
    private func resetDailyCount() async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        try await db.collection("users")
            .document(userId)
            .collection("planLimits")
            .document("current")
            .setData([
                "count": 0,
                "date": Timestamp(date: Date())
            ])
    }
    
    func getTimeUntilReset() -> String {
        guard let resetTime = nextResetTime else { return "Unknown" }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.hour, .minute], from: now, to: resetTime)
        
        if let hours = components.hour, let minutes = components.minute {
            return "\(hours)h \(minutes)m"
        }
        
        return "Unknown"
    }
}
