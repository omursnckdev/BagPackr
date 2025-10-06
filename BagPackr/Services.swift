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
    
    private var isTurkish: Bool {
        Locale.current.language.languageCode?.identifier == "tr"
    }
    
    private var currencySymbol: String {
        isTurkish ? "₺" : "$"
    }
    
    func generateItinerary(location: LocationData, duration: Int, interests: [String], budgetPerDay: Double) async throws -> Itinerary {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let prompt: String
        
        if isTurkish {
            prompt = """
            \(location.name) için \(duration) günlük bir gezi planı oluştur. Konum: \(location.latitude), \(location.longitude)
            
            İlgi alanları: \(interests.joined(separator: ", "))
            Günlük bütçe: ₺\(Int(budgetPerDay))
            
            Kurallar:
            - Günde 4-5 çeşitli aktivite
            - \(location.name) şehrindeki gerçek yer isimleri kullan
            - Her aktivite için saat (örn: "09:00 - 11:00"), mesafe (km) ve maliyet (₺) bilgisi ekle
            - Günlük toplam maliyet yaklaşık ₺\(Int(budgetPerDay)) olmalı
            - Benzer aktiviteleri tekrarlama
            - Tüm açıklamalar Türkçe olmalı
            
            SADECE aşağıdaki JSON formatında cevap ver, başka hiçbir şey yazma:
            {
              "dailyPlans": [
                {
                  "day": 1,
                  "activities": [
                    {
                      "name": "Yer İsmi",
                      "type": "Kategori",
                      "description": "Kısa açıklama",
                      "time": "09:00 - 11:00",
                      "distance": 2.5,
                      "cost": 250.0
                    }
                  ]
                }
              ]
            }
            """
        } else {
            prompt = """
            Create a \(duration)-day itinerary for \(location.name), \(location.latitude), \(location.longitude)
            
            Interests: \(interests.joined(separator: ", "))
            Daily budget: $\(Int(budgetPerDay))
            
            Rules:
            - 4-5 activities per day with variety
            - Use real place names in \(location.name)
            - Include time (e.g., "09:00 - 11:00"), distance (km), and cost ($)
            - Daily costs should total ~$\(Int(budgetPerDay))
            - Don't repeat similar activities
            
            Return ONLY the following JSON format, nothing else:
            {
              "dailyPlans": [
                {
                  "day": 1,
                  "activities": [
                    {
                      "name": "Place Name",
                      "type": "Category",
                      "description": "Brief description",
                      "time": "09:00 - 11:00",
                      "distance": 2.5,
                      "cost": 25.0
                    }
                  ]
                }
              ]
            }
            """
        }
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            let errorMsg = isTurkish ? "Gemini'den yanıt alınamadı" : "No response from Gemini"
            throw NSError(domain: "Gemini", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        

        
        // Clean the response more aggressively
        var cleanedText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find the first { and last } to extract just the JSON
        if let startIndex = cleanedText.firstIndex(of: "{"),
           let endIndex = cleanedText.lastIndex(of: "}") {
            cleanedText = String(cleanedText[startIndex...endIndex])
        }
        
        print("Cleaned JSON:")
        print(cleanedText)
        print("---")
        
        guard let data = cleanedText.data(using: .utf8) else {
            let errorMsg = isTurkish ? "Yanıt çevrilemedi" : "Failed to convert response"
            throw NSError(domain: "Parsing", code: 400, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        let decoder = JSONDecoder()
        let geminiResponse: GeminiResponse
        
        do {
            geminiResponse = try decoder.decode(GeminiResponse.self, from: data)
        } catch {
            print("Decoding Error: \(error)")
            let errorMsg = isTurkish ? "JSON okunamadı: \(error.localizedDescription)" : "Failed to parse JSON: \(error.localizedDescription)"
            throw NSError(domain: "Parsing", code: 400, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
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
