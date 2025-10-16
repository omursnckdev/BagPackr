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
    @Published var currentUser: User?
    
    private let db = Firestore.firestore()
    
    init() {
        checkAuth()
    }
    
    func checkAuth() {
        if let user = Auth.auth().currentUser {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        self.currentUser = result.user
        self.isAuthenticated = true
        await saveDeviceToken()

    }
    
    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        self.currentUser = result.user
        self.isAuthenticated = true
    }
    
    func signOut() {
        try? Auth.auth().signOut()
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    private func saveDeviceToken() async {
        guard let token = Messaging.messaging().fcmToken,
              let userId = currentUser?.uid else { return }
        
        try? await Firestore.firestore()
            .collection("users")
            .document(userId)
            .setData([
                "fcmToken": token,
                "email": currentUser?.email ?? ""
            ], merge: true)
    }
    
    /// Permanently deletes the user account and Firestore data
    func deleteAccount(email: String, password: String, completion: @escaping (Error?) -> Void) {
    guard let user = Auth.auth().currentUser else {
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
                
                // 2. Remove user from all group plans
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
                
                // 3. Delete user's FCM token document
                let userDocs = try await self.db.collection("users")
                    .whereField("email", isEqualTo: userEmail)
                    .getDocuments()
                
                for doc in userDocs.documents {
                    try await doc.reference.delete()
                }
                
                // 4. Delete Firebase Auth account
                try await user.delete()
                
                // 5. Update local state
                await MainActor.run {
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
                
                completion(nil)
                
            } catch {
                completion(error)
            }
        }
    }
}

}

// ViewModels/MultiCityPlannerViewModel.swift
import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class MultiCityPlannerViewModel: ObservableObject {
    @Published var tripTitle = ""
    @Published var cityStops: [CityStop] = []
    @Published var budgetPerDay: Double = 100
    @Published var selectedInterests: Set<String> = []
    @Published var isGenerating = false
    @Published var generatedMultiCity: MultiCityItinerary? // ✅ Eklendi
    @Published var showError = false
    @Published var errorMessage = ""
    
    let availableInterests = [
        "Beaches",
        "Nightlife",
        "Restaurants",
        "Museums",
        "Shopping",
        "Parks",
        "Adventure Sports",
        "Historical Sites",
        "Art Galleries",
        "Local Markets",
        "Street Food",
        "Temples",
        "Architecture",
        "Hiking",
        "Water Sports",
        "Cafes",
        "Live Music",
        "Theater",
        "Festivals"
    ]
    
    var totalDuration: Int {
        cityStops.reduce(0) { $0 + $1.duration }
    }
    
    var totalBudget: Double {
        budgetPerDay * Double(totalDuration)
    }
    
    var canGenerate: Bool {
        !tripTitle.isEmpty && cityStops.count >= 2 && !selectedInterests.isEmpty
    }
    
    func addCity(_ cityStop: CityStop) {
        cityStops.append(cityStop)
    }
    
    func removeCity(_ cityStop: CityStop) {
        cityStops.removeAll { $0.id == cityStop.id }
    }
    
    func toggleInterest(_ interest: String) {
        if selectedInterests.contains(interest) {
            selectedInterests.remove(interest)
        } else {
            selectedInterests.insert(interest)
        }
    }
    
    func generateMultiCityTrip() async {
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            guard let userId = Auth.auth().currentUser?.uid else {
                throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }
            
            var multiCity = MultiCityItinerary(
                userId: userId,
                title: tripTitle,
                cityStops: cityStops,
                interests: Array(selectedInterests),
                budgetPerDay: budgetPerDay
            )
            
            // Generate itinerary for each city
            for cityStop in cityStops {
                print("🔄 Generating itinerary for \(cityStop.location.name)...")
                let itinerary = try await GeminiService.shared.generateItinerary(
                    location: cityStop.location,
                    duration: cityStop.duration,
                    interests: Array(selectedInterests),
                    budgetPerDay: budgetPerDay
                )
                multiCity.itineraries[cityStop.id] = itinerary
            }
            
            // Save to Firestore
            try await FirestoreService.shared.saveMultiCityItinerary(multiCity)
            
            print("✅ Multi-city trip generated successfully")
            
            // ✅ Set generated itinerary to show result
            generatedMultiCity = multiCity
            
        } catch {
            print("❌ Error generating multi-city trip: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func resetForm() {
        tripTitle = ""
        cityStops = []
        selectedInterests = []
        budgetPerDay = 100
        generatedMultiCity = nil
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
    
    // FIX #3: Pass itineraryListViewModel to refresh the list
    func generateItinerary(itineraryListViewModel: ItineraryListViewModel) {
        guard let location = selectedLocation else { return }
        
        isGenerating = true
        
        Task {
            do {
                let itinerary = try await GeminiService.shared.generateItinerary(
                    location: location,
                    duration: duration,
                    interests: Array(selectedInterests),
                    budgetPerDay: budgetPerDay
                )
                
                try await FirestoreService.shared.saveItinerary(itinerary)
                
                // FIX #3: Reload the list after saving
                await itineraryListViewModel.loadItineraries()
                
                generatedItinerary = itinerary
                isGenerating = false
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isGenerating = false
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
    @Published var multiCityGroupPlans: [MultiCityGroupPlan] = [] // ✅ Eklendi
    @Published var isLoading = false
    private var listener: ListenerRegistration?
    private var multiCityListener: ListenerRegistration?
    
    func startListening() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        // Regular groups
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
        
        // ✅ Multi-city groups
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
    
    func stopListening() {
        listener?.remove()
        multiCityListener?.remove()
        listener = nil
        multiCityListener = nil
    }
    
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
    
    func loadItineraries() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No user ID")
            return
        }
        
        print("🔍 Loading itineraries for user: \(userId)")
        
        // ✅ Load regular itineraries (ayrı try-catch)
        do {
            let loadedItineraries = try await FirestoreService.shared.loadItineraries(userId: userId)
            self.itineraries = loadedItineraries
            print("✅ Loaded \(loadedItineraries.count) regular itineraries")
        } catch {
            print("❌ Error loading regular itineraries: \(error)")
            // Regular itineraries yüklenemedi ama devam et
        }
        
        // ✅ Load multi-city itineraries (ayrı try-catch)
        do {
            let loadedMultiCity = try await FirestoreService.shared.loadMultiCityItineraries(userId: userId)
            self.multiCityItineraries = loadedMultiCity
            print("✅ Loaded \(loadedMultiCity.count) multi-city itineraries")
        } catch {
            print("❌ Error loading multi-city itineraries: \(error)")
            // Multi-city yüklenemedi ama regular itineraries zaten yüklendi
        }
        
        print("📊 Final count: \(self.itineraries.count) regular, \(self.multiCityItineraries.count) multi-city")
    }
}
