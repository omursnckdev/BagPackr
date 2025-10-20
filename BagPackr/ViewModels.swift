//
//  ViewModels.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 3.10.2025.
//

import Foundation
// MARK: - View Models
import FirebaseAuth
import FirebaseFirestore
import GoogleGenerativeAI
import SwiftUI
import FirebaseCore
import GoogleMaps
import GooglePlaces
import MapKit
import Combine
import GoogleMobileAds
import FirebaseMessaging

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: FirebaseAuth.User?  // ⭐ Firebase Auth User
    @Published var userProfile: BagPackr.User?      // ⭐ Custom User with subscription
    
    private let db = Firestore.firestore()
    
    init() {
        checkAuth()
    }
    
    func checkAuth() {
        if let user = Auth.auth().currentUser {
            self.currentUser = user
            self.isAuthenticated = true
            
            // ⭐ Load user profile
            Task {
                await loadUserProfile()
            }
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        self.currentUser = result.user
        self.isAuthenticated = true
        
        // ⭐ Load user profile and save token
        await loadUserProfile()
        await saveDeviceToken()
    }
    
    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        self.currentUser = result.user
        self.isAuthenticated = true
        
        // ⭐ Create user document, load profile, and save token
        await createUserDocument()
        await loadUserProfile()
        await saveDeviceToken()
    }
    
    func signOut() {
        try? Auth.auth().signOut()
        self.currentUser = nil
        self.userProfile = nil  // ⭐ Clear user profile too
        self.isAuthenticated = false
    }
    
    // ⭐ NEW: Create user document on signup
    private func createUserDocument() async {
        guard let firebaseUser = currentUser else { return }
        
        let newUser = BagPackr.User(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            displayName: firebaseUser.displayName,
            photoURL: firebaseUser.photoURL?.absoluteString,
            subscription: UserSubscription(tier: .free),
            createdAt: Date()
        )
        
        do {
            try db.collection("users").document(firebaseUser.uid).setData(from: newUser)
            self.userProfile = newUser
            print("✅ User document created: \(firebaseUser.email ?? "")")
        } catch {
            print("❌ Error creating user document: \(error)")
        }
    }
    
    // ⭐ NEW: Load user profile from Firestore
    private func loadUserProfile() async {
        guard let userId = currentUser?.uid else { return }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists {
                // Document exists, decode it
                self.userProfile = try document.data(as: BagPackr.User.self)
                print("✅ User profile loaded: \(userProfile?.email ?? ""), Premium: \(userProfile?.isPremium ?? false)")
            } else {
                // Document doesn't exist (old user), create it
                print("⚠️ User document doesn't exist, creating...")
                await createUserDocument()
            }
        } catch {
            print("❌ Error loading user profile: \(error)")
        }
    }
    
    private func saveDeviceToken() async {
        guard let token = Messaging.messaging().fcmToken,
              let userId = currentUser?.uid else { return }
        
        try? await db.collection("users")
            .document(userId)
            .setData([
                "fcmToken": token,
                "email": currentUser?.email ?? ""
            ], merge: true)
        
        print("✅ FCM token saved")
    }
    
    /// Permanently deletes the user account and Firestore data
    func deleteAccount(email: String, password: String, completion: @escaping (Error?) -> Void) {
        guard let user = currentUser else {
            completion(nil)
            return
        }

        let userId = user.uid
        let userEmail = user.email ?? email
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        // Re-authenticate first
        user.reauthenticate(with: credential) { _, error in
            if let error = error {
                completion(error)
                return
            }

            Task {
                do {
                    // 1. Delete all user's itineraries (including subcollections)
                    let itinerariesSnapshot = try await self.db.collection("itineraries")
                        .whereField("userId", isEqualTo: userId)
                        .getDocuments()
                    
                    for doc in itinerariesSnapshot.documents {
                        // Delete progress subcollection
                        let progressDocs = try await doc.reference.collection("progress").getDocuments()
                        for progressDoc in progressDocs.documents {
                            try await progressDoc.reference.delete()
                        }
                        // Delete itinerary
                        try await doc.reference.delete()
                    }
                    
                    // 2. Delete multi-city itineraries
                    let multiCitySnapshot = try await self.db.collection("multiCityItineraries")
                        .whereField("userId", isEqualTo: userId)
                        .getDocuments()
                    
                    for doc in multiCitySnapshot.documents {
                        try await doc.reference.delete()
                    }
                    
                    // 3. Remove user from all group plans
                    let groupsSnapshot = try await self.db.collection("groupPlans")
                        .whereField("memberEmails", arrayContains: userEmail)
                        .getDocuments()
                    
                    for doc in groupsSnapshot.documents {
                        let groupData = doc.data()
                        
                        // Check if user is the owner
                        if let members = groupData["members"] as? [[String: Any]] {
                            let isOwner = members.contains { member in
                                (member["email"] as? String) == userEmail && (member["isOwner"] as? Bool) == true
                            }
                            
                            if isOwner {
                                // Delete entire group if user is owner
                                // Delete expenses subcollection
                                let expensesDocs = try await doc.reference.collection("expenses").getDocuments()
                                for expenseDoc in expensesDocs.documents {
                                    try await expenseDoc.reference.delete()
                                }
                                
                                // Delete settlements subcollection
                                let settlementsDocs = try await doc.reference.collection("settlements").getDocuments()
                                for settlementDoc in settlementsDocs.documents {
                                    try await settlementDoc.reference.delete()
                                }
                                
                                // Delete group
                                try await doc.reference.delete()
                            } else {
                                // Just remove user from group
                                try await doc.reference.updateData([
                                    "members": FieldValue.arrayRemove([["email": userEmail, "isOwner": false]]),
                                    "memberEmails": FieldValue.arrayRemove([userEmail])
                                ])
                            }
                        }
                    }
                    
                    // 4. Delete multi-city group plans
                    let multiCityGroupsSnapshot = try await self.db.collection("multiCityGroupPlans")
                        .whereField("memberEmails", arrayContains: userEmail)
                        .getDocuments()
                    
                    for doc in multiCityGroupsSnapshot.documents {
                        let groupData = doc.data()
                        
                        if let ownerId = groupData["ownerId"] as? String, ownerId == userEmail {
                            // Delete if owner
                            try await doc.reference.delete()
                        } else {
                            // Remove from members
                            try await doc.reference.updateData([
                                "members": FieldValue.arrayRemove([["email": userEmail, "isOwner": false]]),
                                "memberEmails": FieldValue.arrayRemove([userEmail])
                            ])
                        }
                    }
                    
                    // 5. Delete user document
                    try await self.db.collection("users")
                        .document(userId)
                        .delete()
                    
                    // 6. Delete Firebase Auth account
                    try await user.delete()
                    
                    // 7. Update local state
                    await MainActor.run {
                        self.currentUser = nil
                        self.userProfile = nil  // ⭐ Clear user profile
                        self.isAuthenticated = false
                    }
                    
                    print("✅ Account deleted successfully")
                    completion(nil)
                    
                } catch {
                    print("❌ Error deleting account: \(error)")
                    completion(error)
                }
            }
        }
    }
}

@MainActor
class CreateItineraryViewModel: ObservableObject {
    @Published var selectedLocation: LocationData?
    @Published var duration = 3
    @Published var budgetPerDay: Double = 1000
    @Published var selectedInterests: Set<String> = []
    @Published var customInterestInput = ""
    @Published var customInterests: [String] = []
    @Published var isGenerating = false
    @Published var generatedItinerary: Itinerary?
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSaveSuccess = false
    
    // ⭐ NEW: Premium alert
    @Published var showPremiumAlert = false
    @Published var premiumAlertMessage = ""
    
    // ⭐ NEW: Plan limit service
    private let planLimitService = PlanLimitService.shared
    
    let builtInInterests = [
        "Beaches", "Nightlife", "Restaurants", "Museums",
        "Shopping", "Parks", "Adventure Sports", "Historical Sites",
        "Art Galleries", "Local Markets", "Street Food", "Temples",
        "Architecture", "Photography", "Hiking", "Water Sports",
        "Cafes", "Live Music", "Theater", "Festivals"
    ]
    
    var canGenerate: Bool {
        selectedLocation != nil && !selectedInterests.isEmpty
    }
    
    func toggleInterest(_ interest: String) {
        if selectedInterests.contains(interest) {
            selectedInterests.remove(interest)
        } else {
            selectedInterests.insert(interest)
        }
    }
    
    func addCustomInterest() {
        let trimmed = customInterestInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        customInterests.append(trimmed)
        selectedInterests.insert(trimmed)
        customInterestInput = ""
    }
    
    func removeCustomInterest(_ interest: String) {
        customInterests.removeAll { $0 == interest }
        selectedInterests.remove(interest)
    }
    
    // ⭐ UPDATED: Add plan limit check
    func generateItinerary(itineraryListViewModel: ItineraryListViewModel) {
        guard let location = selectedLocation else { return }
        
        isGenerating = true
        
        Task {
            // ⭐ STEP 1: Check plan limit BEFORE generating
            let (canCreate, reason) = await planLimitService.canGeneratePlan()
            
            if !canCreate {
                // Show premium alert
                premiumAlertMessage = reason ?? "Upgrade to Premium for unlimited plans!"
                showPremiumAlert = true
                isGenerating = false
                
                print("⚠️ Plan limit reached. Premium required.")
                return
            }
            
            // ⭐ STEP 2: Proceed with generation
            do {
                let itinerary = try await GeminiService.shared.generateItinerary(
                    location: location,
                    duration: duration,
                    interests: Array(selectedInterests),
                    budgetPerDay: budgetPerDay
                )
                
                try await FirestoreService.shared.saveItinerary(itinerary)
                
                // ⭐ STEP 3: Increment plan count (for free users)
                await planLimitService.incrementPlanCount()
                
                // Reload the list after saving
                await itineraryListViewModel.loadItineraries()
                showSaveSuccess = true
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                showSaveSuccess = false
                
                generatedItinerary = itinerary
                isGenerating = false
                
                print("✅ Itinerary created successfully!")
                
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isGenerating = false
                
                print("❌ Error creating itinerary: \(error)")
            }
        }
    }
}
// ViewModels/GroupPlansViewModel.swift
import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class GroupPlansViewModel: ObservableObject {
    @Published var groupPlans: [GroupPlan] = []
    @Published var isLoading = false
    @Published var multiCityGroupPlans: [MultiCityGroupPlan] = []
    private var multiCityListener: ListenerRegistration?
    private var listener: ListenerRegistration?
    
    func startListening() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        // Regular groups (mevcut kod)
        listener = Firestore.firestore()
            .collection("groupPlans")
            .whereField("memberEmails", arrayContains: userEmail)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let decoder = Firestore.Decoder()
                Task { @MainActor in
                    let groups = documents.compactMap { doc -> GroupPlan? in
                        try? decoder.decode(GroupPlan.self, from: doc.data())
                    }
                    self?.groupPlans = groups.sorted { $0.createdAt > $1.createdAt }
                }
            }
        
        // Multi-city groups
        multiCityListener = Firestore.firestore()
            .collection("multiCityGroupPlans")
            .whereField("memberEmails", arrayContains: userEmail)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let decoder = Firestore.Decoder()
                Task { @MainActor in
                    let groups = documents.compactMap { doc -> MultiCityGroupPlan? in
                        try? decoder.decode(MultiCityGroupPlan.self, from: doc.data())
                    }
                    self?.multiCityGroupPlans = groups.sorted { $0.createdAt > $1.createdAt }
                }
            }
    }

    // stopListening() metodunu güncelleyin:
    func stopListening() {
        listener?.remove()
        multiCityListener?.remove()
        listener = nil
        multiCityListener = nil
    }

    // loadGroupPlans() metodunu güncelleyin:
    func loadGroupPlans() async {
        isLoading = true
        
        do {
            let plans = try await FirestoreService.shared.fetchGroupPlans()
            let multiCityPlans = try await FirestoreService.shared.fetchMultiCityGroupPlans()
            
            self.groupPlans = plans.sorted { $0.createdAt > $1.createdAt }
            self.multiCityGroupPlans = multiCityPlans.sorted { $0.createdAt > $1.createdAt }
            
            print("✅ Loaded \(plans.count) regular and \(multiCityPlans.count) multi-city group plans")
        } catch {
            print("❌ Error loading group plans: \(error)")
        }
        
        isLoading = false
    }
}
// ViewModels/ItineraryListViewModel.swift



@MainActor
class ItineraryListViewModel: ObservableObject {
    @Published var itineraries: [Itinerary] = []
    @Published var multiCityItineraries: [MultiCityItinerary] = []
    
    @Published var activePlansCount: Int = 0
    @Published var isPremium: Bool = false
    @Published var remainingPlans: Int = 0
    
    private let planLimitService = PlanLimitService.shared
    
    func loadItineraries() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No user ID")
            return
        }
        
        print("🔍 Loading itineraries for user: \(userId)")
        
        // Load regular itineraries
        do {
            let loadedItineraries = try await FirestoreService.shared.loadItineraries(userId: userId)
            self.itineraries = loadedItineraries
            print("✅ Loaded \(loadedItineraries.count) regular itineraries")
        } catch {
            print("❌ Error loading regular itineraries: \(error)")
        }
        
        // Load multi-city itineraries
        do {
            let loadedMultiCity = try await FirestoreService.shared.loadMultiCityItineraries(userId: userId)
            self.multiCityItineraries = loadedMultiCity
            print("✅ Loaded \(loadedMultiCity.count) multi-city itineraries")
        } catch {
            print("❌ Error loading multi-city itineraries: \(error)")
        }
        
        print("📊 Final count: \(self.itineraries.count) regular, \(self.multiCityItineraries.count) multi-city")
        
        await updatePlanLimitInfo()
    }
    
    private func updatePlanLimitInfo() async {
        await planLimitService.checkPremiumStatus()
        await planLimitService.loadActivePlansCount()
        
        self.isPremium = planLimitService.isPremium
        self.activePlansCount = planLimitService.activePlansCount
        self.remainingPlans = planLimitService.remainingPlans
        
        print("📊 Plan limits - Active: \(activePlansCount), Remaining: \(remainingPlans), Premium: \(isPremium)")
    }
    
    // ⭐ FIXED: Delete regular itinerary
    func deleteItinerary(_ itinerary: Itinerary) async {
        do {
            try await FirestoreService.shared.deleteItinerary(itinerary.id)
            //                                                 ^^^ No label!
            
            // Remove from local array
            self.itineraries.removeAll { $0.id == itinerary.id }
            
            // Update plan count
            await planLimitService.decrementPlanCount()
            
            print("✅ Itinerary deleted, remaining slots: \(planLimitService.remainingPlans)")
            
        } catch {
            print("❌ Error deleting itinerary: \(error)")
        }
    }
    
    // ⭐ FIXED: Delete multi-city itinerary
    func deleteMultiCityItinerary(_ itinerary: MultiCityItinerary) async {
        do {
            try await FirestoreService.shared.deleteMultiCityItinerary(itinerary.id)
            //                                                          ^^^ No label!
            
            // Remove from local array
            self.multiCityItineraries.removeAll { $0.id == itinerary.id }
            
            // Update plan count
            await planLimitService.decrementPlanCount()
            
            print("✅ Multi-city itinerary deleted")
            
        } catch {
            print("❌ Error deleting multi-city itinerary: \(error)")
        }
    }
}
