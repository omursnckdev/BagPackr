//
//  ItineraryDetailView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

// MARK: - Itinerary Detail View
struct ItineraryDetailView: View {
    let itineraryId: String
    @ObservedObject var viewModel: ItineraryListViewModel
    @State private var showEditSheet = false
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var showGroupShare = false
    @State private var shareText = ""
    @Environment(\.dismiss) var dismiss
    
    // Get the latest itinerary from viewModel
    private var itinerary: Itinerary? {
        viewModel.itineraries.first(where: { $0.id == itineraryId })
    }
    
    private func totalSpent(for itinerary: Itinerary) -> Double {
        itinerary.dailyPlans.reduce(0) { total, plan in
            total + plan.activities.reduce(0) { $0 + $1.cost }
        }
    }
    
    var body: some View {
        Group {
            if let itinerary = itinerary {
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
                                    
                                    if itinerary.isShared {
                                        Image(systemName: "person.2.fill")
                                            .font(.title3)
                                    }
                                }
                                
                                HStack {
                                    let daysText = Locale.current.language.languageCode?.identifier == "tr" ? "Gün" : "Days"
                                    Label("\(itinerary.duration) \(daysText)", systemImage: "calendar")
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Budget: $\(Int(itinerary.budgetPerDay * Double(itinerary.duration)))")
                                        Text("Spent: $\(Int(totalSpent(for: itinerary)))")
                                            .font(.caption)
                                    }
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
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            ActionButton(icon: "pencil", title: "Edit", color: .blue) {
                                showEditSheet = true
                            }
                            .frame(maxWidth: .infinity)
                            
                            ActionButton(icon: "person.2.fill", title: "Group", color: .purple) {
                                showGroupShare = true
                            }
                            .frame(maxWidth: .infinity)
                            
                            ActionButton(icon: "trash", title: "Delete", color: .red) {
                                showDeleteAlert = true
                            }
                            .frame(maxWidth: .infinity)
                        }
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
                .navigationTitle("Itinerary Details")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showEditSheet) {
                    EditItineraryView(itinerary: itinerary, viewModel: viewModel)
                }
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(items: [shareText])
                }
                .sheet(isPresented: $showGroupShare) {
                    GroupShareView(itinerary: itinerary)
                }
              
            } else {
                ProgressView()
                    .onAppear {
                        Task { await viewModel.loadItineraries() }
                    }
            }
        }
    }
    
    private func shareItinerary(itinerary: Itinerary) {
        shareText = generateShareText(for: itinerary)
        showShareSheet = true
    }
    
    private func generateShareText(for itinerary: Itinerary) -> String {
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
    
    private func deleteItinerary() {
        Task {
            try? await FirestoreService.shared.deleteItinerary(itineraryId)
            await viewModel.loadItineraries()
            dismiss()
        }
    }
}
