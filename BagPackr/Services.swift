//
//  Services.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 3.10.2025.
//

import Foundation
import SwiftUI
import FirebaseCore
import GoogleMaps
import GooglePlaces
import MapKit
import Combine
import GoogleMobileAds
import GoogleGenerativeAI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Gemini Service

class GeminiService {
    static let shared = GeminiService()
    private let model: GenerativeModel
    private let decoder = JSONDecoder()

    private init() {
        let config = GenerationConfig(
            temperature: 0.7,
            topP: 0.95,
            responseMimeType: "application/json"
        )

        model = GenerativeModel(
            name: "gemini-1.5-flash-latest",
            apiKey: "AIzaSyAoUnnvwIeBbxYo0RncGtteOJCaViLwJRI",
            safetySettings: Self.relaxedSafetySettings,
            generationConfig: config
        )
    }

    private static let relaxedSafetySettings: [SafetySetting] = [
        SafetySetting(harmCategory: .harassment, threshold: .blockNone),
        SafetySetting(harmCategory: .hateSpeech, threshold: .blockNone),
        SafetySetting(harmCategory: .dangerousContent, threshold: .blockNone)
    ]
    
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
        
        let geminiResponse = try await requestGeminiJSON(for: prompt, label: "Single City")
        let dailyPlans = mapDailyPlans(from: geminiResponse)
        
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
// =====================================
// ADD THIS EXTENSION TO YOUR Services.swift FILE
// Place it after your existing GeminiService class
// =====================================

extension GeminiService {
    
    func generateMultiCityItinerary(
        locations: [LocationData],
        durationsPerCity: [String: Int],
        interests: [String],
        budgetPerDay: Double
    ) async throws -> Itinerary {
        
        guard let userId = Auth.auth().currentUser?.uid else {
            let errorMsg = isTurkish ? "Kullanıcı doğrulanmadı" : "User not authenticated"
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        // Build city details with durations
        var cityDetails = ""
        var dayRanges: [(city: String, startDay: Int, endDay: Int)] = []
        var currentDay = 1
        
        for location in locations {
            let duration = durationsPerCity[location.id] ?? 2
            let endDay = currentDay + duration - 1
            
            cityDetails += "\n• \(location.name) (\(location.latitude), \(location.longitude)): Day \(currentDay) to Day \(endDay) (\(duration) days)"
            dayRanges.append((city: location.name, startDay: currentDay, endDay: endDay))
            currentDay = endDay + 1
        }
        
        let totalDuration = durationsPerCity.values.reduce(0, +)
        
        let prompt: String
        
        if isTurkish {
            prompt = """
            Çok şehirli bir gezi planı oluştur:
            \(cityDetails)
            
            Toplam süre: \(totalDuration) gün
            İlgi alanları: \(interests.joined(separator: ", "))
            Günlük bütçe: ₺\(Int(budgetPerDay))
            
            Kurallar:
            - Her şehir için o şehirdeki gerçek yerler kullan
            - Şehir değişimlerinde "Seyahat" aktivitesi ekle (örn: "İstanbul'dan Ankara'ya Uçuş" veya "Otobüs Yolculuğu")
            - Günde 4-5 çeşitli aktivite
            - Her aktivite için saat (örn: "09:00 - 11:00"), mesafe (km) ve maliyet (₺) bilgisi
            - Günlük toplam maliyet yaklaşık ₺\(Int(budgetPerDay)) olmalı
            - Şehir içi mesafeler mantıklı olmalı (0-20 km arası)
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
            Create a multi-city travel itinerary:
            \(cityDetails)
            
            Total duration: \(totalDuration) days
            Interests: \(interests.joined(separator: ", "))
            Daily budget: $\(Int(budgetPerDay))
            
            Rules:
            - Use real places in each specific city
            - Add "Travel" activity when changing cities (e.g., "Flight from Istanbul to Ankara" or "Bus Journey")
            - 4-5 varied activities per day
            - Include time (e.g., "09:00 - 11:00"), distance (km), and cost ($) for each activity
            - Daily costs should total ~$\(Int(budgetPerDay))
            - Keep distances within cities realistic (0-20 km range)
            - All descriptions in English
            
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
        
        let geminiResponse = try await requestGeminiJSON(for: prompt, label: "Multi City")
        let dailyPlans = mapDailyPlans(from: geminiResponse)
        
        // Create combined location name
        let locationName = locations.map { $0.name }.joined(separator: " → ")
        
        return Itinerary(
            userId: userId,
            location: locationName,
            duration: totalDuration,
            interests: interests,
            dailyPlans: dailyPlans,
            budgetPerDay: budgetPerDay
        )
    }
}

private extension GeminiService {
    func requestGeminiJSON(for prompt: String, label: String) async throws -> GeminiResponse {
        let response: GenerateContentResponse

        do {
            response = try await model.generateContent(prompt)
        } catch {
            let message = isTurkish
                ? "Gemini isteği başarısız: \(error.localizedDescription)"
                : "Gemini request failed: \(error.localizedDescription)"
            throw NSError(domain: "Gemini", code: 500, userInfo: [NSLocalizedDescriptionKey: message])
        }

        guard let text = response.text else {
            let errorMsg = isTurkish ? "Gemini'den yanıt alınamadı" : "No response from Gemini"
            throw NSError(domain: "Gemini", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        let cleanedText = extractJSON(from: text, label: label)

        guard let data = cleanedText.data(using: .utf8) else {
            let errorMsg = isTurkish ? "Yanıt çevrilemedi" : "Failed to convert response"
            throw NSError(domain: "Parsing", code: 400, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        do {
            return try decoder.decode(GeminiResponse.self, from: data)
        } catch {
            print("Decoding Error: \(error)")
            let errorMsg = isTurkish
                ? "JSON okunamadı: \(error.localizedDescription)"
                : "Failed to parse JSON: \(error.localizedDescription)"
            throw NSError(domain: "Parsing", code: 400, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
    }

    func extractJSON(from text: String, label: String) -> String {
        var cleanedText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let startIndex = cleanedText.firstIndex(of: "{"),
           let endIndex = cleanedText.lastIndex(of: "}") {
            cleanedText = String(cleanedText[startIndex...endIndex])
        }

        print("\(label) Cleaned JSON:")
        print(cleanedText)
        print("---")

        return cleanedText
    }

    func mapDailyPlans(from response: GeminiResponse) -> [DailyPlan] {
        response.dailyPlans.map { plan in
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

// MARK: - Plan Limit Service



