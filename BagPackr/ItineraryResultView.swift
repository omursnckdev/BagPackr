//
//  ItineraryResultView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

// MARK: - Itinerary Result View
struct ItineraryResultView: View {
    @Environment(\.dismiss) var dismiss
    let itinerary: Itinerary
    @ObservedObject var itineraryListViewModel: ItineraryListViewModel
    @State private var showShareSheet = false
    @State private var shareText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                Text(itinerary.location)
                                    .font(.title)
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                let daysText = Locale.current.language.languageCode?.identifier == "tr" ? "Gün" : "Days"
                                Label("\(itinerary.duration) \(daysText)", systemImage: "calendar")
                                Spacer()
                                let currencySymbol = Locale.current.language.languageCode?.identifier == "tr" ? "₺" : "$"
                                Label("\(currencySymbol)\(Int(itinerary.budgetPerDay * Double(itinerary.duration)))", systemImage: "dollarsign.circle.fill")
                            }
                            .font(.subheadline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(itinerary.interests, id: \.self) { interest in
                                        Text(LocalizedStringKey(interest))
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.white.opacity(0.3))
                                            .cornerRadius(15)
                                    }
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .padding()
                    }
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    ForEach(Array(itinerary.dailyPlans.enumerated()), id: \.element.id) { index, plan in
                        EnhancedDayPlanCard(
                            dayNumber: index + 1,
                            plan: plan,
                            location: itinerary.location,
                            itinerary: itinerary
                        )
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Your Itinerary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // FIX #3: Refresh list when dismissing
                        Task {
                            await itineraryListViewModel.loadItineraries()
                        }
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareItinerary) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [shareText])
            }
        }
    }
    
    private func shareItinerary() {
        shareText = generateShareText()
        showShareSheet = true
    }
    
    private func generateShareText() -> String {
        var text = "🌍 \(itinerary.location) - \(itinerary.duration) Day Itinerary\n\n"
        text += "📍 Interests: \(itinerary.interests.joined(separator: ", "))\n"
        text += "💰 Budget: $\(Int(itinerary.budgetPerDay * Double(itinerary.duration)))\n\n"
        
        for (index, plan) in itinerary.dailyPlans.enumerated() {
            text += "📅 Day \(index + 1):\n"
            for activity in plan.activities {
                text += "  • \(activity.time) - \(activity.name)\n"
                text += "    \(activity.description)\n"
                if activity.cost > 0 {
                    text += "    💵 $\(Int(activity.cost))\n"
                }
            }
            text += "\n"
        }
        
        text += "\nCreated with BagPckr ✈️"
        return text
    }
}
