//
//  MultiCityPlannerViewModel.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 17.10.2025.
//

import Foundation
import Combine
import FirebaseAuth
// MARK: - Multi-City Planner ViewModel
// Update MultiCityPlannerViewModel in ViewModels.swift (or MultiCityPlannerViewModel.swift)

@MainActor
class MultiCityPlannerViewModel: ObservableObject {
    @Published var tripTitle = ""
    @Published var cityStops: [CityStop] = []
    @Published var budgetPerDay: Double = 1000
    @Published var selectedInterests: Set<String> = []
    @Published var isGenerating = false
    @Published var generatedMultiCity: MultiCityItinerary?
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSaveSuccess = false
    
    // ✅ NEW: Add custom interests support
    @Published var customInterestInput = ""
    @Published var customInterests: [String] = []
    
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
        AnalyticsService.shared.logCityAdded(
              cityName: cityStop.location.name,
              duration: cityStop.duration
          )
    }
    
    func removeCity(_ cityStop: CityStop) {
        cityStops.removeAll { $0.id == cityStop.id }
        AnalyticsService.shared.logCityRemoved(cityName: cityStop.location.name)

    }
    
    func toggleInterest(_ interest: String) {
        if selectedInterests.contains(interest) {
            selectedInterests.remove(interest)
        } else {
            selectedInterests.insert(interest)
            AnalyticsService.shared.logInterestSelected(
                   interest: interest,
                   isCustom: false
               )
        }
    }
    
    // ✅ NEW: Add custom interest
    func addCustomInterest() {
        let trimmed = customInterestInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        customInterests.append(trimmed)
        selectedInterests.insert(trimmed)
        AnalyticsService.shared.logCustomInterestAdded(interest: trimmed)

        customInterestInput = ""
    }
    
    // ✅ NEW: Remove custom interest
    func removeCustomInterest(_ interest: String) {
        customInterests.removeAll { $0 == interest }
        selectedInterests.remove(interest)
    }
    
    func generateMultiCityTrip() async {
        isGenerating = true
        defer { isGenerating = false }
        
        let startTime = Date()
        AnalyticsService.shared.logAIGenerationStarted(type: "multi_city")

        
        
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
            
            // ⭐ Analytics - Success
               let duration = Date().timeIntervalSince(startTime)
               AnalyticsService.shared.logAIGenerationCompleted(
                   type: "multi_city",
                   duration: duration
               )
               
               AnalyticsService.shared.logMultiCityCreated(
                   cityCount: cityStops.count,
                   totalDuration: totalDuration,
                   totalBudget: totalBudget
               )
            
            showSaveSuccess = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showSaveSuccess = false
            
            print("✅ Multi-city trip generated successfully")
            generatedMultiCity = multiCity
            
        } catch {
            print("❌ Error generating multi-city trip: \(error)")
            errorMessage = error.localizedDescription
            showError = true
            // ⭐ Analytics - Failure
                 AnalyticsService.shared.logAIGenerationFailed(
                     type: "multi_city",
                     error: error.localizedDescription
                 )
        }
    }
    
    func resetForm() {
        tripTitle = ""
        cityStops = []
        selectedInterests = []
        customInterests = []
        customInterestInput = ""
        budgetPerDay = 100
        generatedMultiCity = nil
    }
}
