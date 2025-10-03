//
//  Services.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 3.10.2025.
//

import Foundation
// MARK: - Services
import SwiftUI
import FirebaseCore
import GoogleMaps
import GooglePlaces
import MapKit
import Combine
import GoogleMobileAds
import GoogleGenerativeAI
import FirebaseAuth

class GeminiService {
    static let shared = GeminiService()
    private let model: GenerativeModel
    
    private init() {
        model = GenerativeModel(name: "gemini-2.5-flash-lite", apiKey: "AIzaSyAoUnnvwIeBbxYo0RncGtteOJCaViLwJRI")
    }
    
    func generateItinerary(location: LocationData, duration: Int, interests: [String], budgetPerDay: Double) async throws -> Itinerary {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let prompt = """
        Create a \(duration)-day itinerary for \(location.name), \(location.latitude), \(location.longitude)
        
        Interests: \(interests.joined(separator: ", "))
        Daily budget: $\(Int(budgetPerDay))
        
        Rules:
        - 4-5 activities per day with variety
        - Real place names in \(location.name)
        - Include time (e.g., "09:00 AM - 11:00 AM"), distance (km), and cost ($)
        - Daily costs should total ~$\(Int(budgetPerDay))
        - Don't repeat similar activities
        
        Return ONLY this JSON (no markdown):
        {
          "dailyPlans": [
            {
              "day": 1,
              "activities": [
                {
                  "name": "Place Name",
                  "type": "Beach/Restaurant/Museum/etc",
                  "description": "Brief description",
                  "time": "09:00 AM - 11:00 AM",
                  "distance": 2.5,
                  "cost": 25.0
                }
              ]
            }
          ]
        }
        """
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw NSError(domain: "Gemini", code: 500, userInfo: [NSLocalizedDescriptionKey: "No response from Gemini"])
        }
        
        let cleanedText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedText.data(using: .utf8) else {
            throw NSError(domain: "Parsing", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response"])
        }
        
        let decoder = JSONDecoder()
        let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)
        
        let dailyPlans = geminiResponse.dailyPlans.map { plan in
            DailyPlan(
                day: plan.day,
                activities: plan.activities.map { activity in
                    Activity(
                        name: activity.name,
                        type: activity.type,
                        description: activity.description,
                        time: activity.time,
                        distance: activity.distance,
                        cost: activity.cost
                    )
                }
            )
        }
        
        return Itinerary(
            userId: userId,
            location: location.name,
            duration: duration,
            interests: interests,
            dailyPlans: dailyPlans,
            budgetPerDay: budgetPerDay
        )
    }
}

struct GeminiResponse: Codable {
    let dailyPlans: [GeminiDailyPlan]
}

struct GeminiDailyPlan: Codable {
    let day: Int
    let activities: [GeminiActivity]
}

struct GeminiActivity: Codable {
    let name: String
    let type: String
    let description: String
    let time: String
    let distance: Double
    let cost: Double
}
