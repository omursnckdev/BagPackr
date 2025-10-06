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
    ///
    func deleteAccount(email: String, password: String, completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(nil)
            return
        }

        let userId = user.uid
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        // 🔑 Re-authenticate first
        user.reauthenticate(with: credential) { _, error in
            if let error = error {
                completion(error)
                return
            }

            // 1. Delete Firestore data
            self.db.collection("itineraries").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
                if let error = error {
                    completion(error)
                    return
                }

                let batch = self.db.batch()
                snapshot?.documents.forEach { batch.deleteDocument($0.reference) }

                batch.commit { error in
                    if let error = error {
                        completion(error)
                        return
                    }

                    // 2. Delete Firebase Auth account
                    user.delete { error in
                        if let error = error {
                            completion(error)
                        } else {
                            Task { @MainActor in
                                self.currentUser = nil
                                self.isAuthenticated = false
                            }
                            completion(nil)
                        }
                    }
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

@MainActor
class ItineraryListViewModel: ObservableObject {
    @Published var itineraries: [Itinerary] = []
    
    func loadItineraries() async {
        do {
            itineraries = try await FirestoreService.shared.fetchItineraries()
        } catch {
            print("Error loading itineraries: \(error)")
        }
    }
}
@MainActor
class GroupPlansViewModel: ObservableObject {
    @Published var groupPlans: [GroupPlan] = []
    private var listener: ListenerRegistration?
    
    func startListening() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
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
                    // Sort by creation date (newest first)
                    self?.groupPlans = groups.sorted { $0.createdAt > $1.createdAt }
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
