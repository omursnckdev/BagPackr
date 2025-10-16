//
//  MultiCityResultView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//
// Views/MultiCityResultView.swift
import SwiftUI

struct MultiCityResultView: View {
    @Environment(\.dismiss) var dismiss
    let multiCity: MultiCityItinerary
    let onDismiss: () -> Void
    
    @State private var selectedCityIndex = 0
    @State private var showDeleteAlert = false
    
    private var selectedCity: CityStop? {
        multiCity.cityStops[safe: selectedCityIndex]
    }
    
    private var selectedItinerary: Itinerary? {
        guard let city = selectedCity else { return nil }
        return multiCity.itineraries[city.id]
    }
    
    private func totalSpent(for itinerary: Itinerary?) -> Double {
        guard let itinerary = itinerary else { return 0 }
        return itinerary.dailyPlans.reduce(0) { total, plan in
            total + plan.activities.reduce(0) { $0 + $1.cost }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Main header card
                    mainHeaderCard
                    
                    // City tabs
                    cityTabsSection
                    
                    // Selected city header
                    if let city = selectedCity {
                        cityHeaderCard(for: city)
                    }
                    
                    // Action buttons
                    actionButtons
                    
                    // Daily plans
                    if let itinerary = selectedItinerary {
                        ForEach(Array(itinerary.dailyPlans.enumerated()), id: \.element.id) { index, plan in
                            EnhancedDayPlanCard(
                                dayNumber: index + 1,
                                plan: plan,
                                location: selectedCity?.location.name ?? "",
                                itinerary: itinerary
                            )
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Multi-City Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
            .alert("Delete Trip", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteTrip()
                }
            } message: {
                Text("Are you sure you want to delete this multi-city trip? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Main Header Card
    private var mainHeaderCard: some View {
        ZStack {
            LinearGradient(
                colors: [.purple, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "map.fill")
                        .font(.title)
                    Text(multiCity.title)
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                HStack {
                    Label("\(multiCity.citiesCount) cities", systemImage: "mappin.and.ellipse")
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Budget: $\(Int(multiCity.totalBudget))")
                        Text("\(multiCity.totalDuration) days total")
                            .font(.caption)
                    }
                }
                .font(.subheadline)
                
                // Cities list
                Text(multiCity.cityNames)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(15)
            }
            .foregroundColor(.white)
            .padding()
        }
        .cornerRadius(20)
        .padding(.horizontal)
    }
    
    // MARK: - City Tabs Section
    private var cityTabsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(multiCity.cityStops.enumerated()), id: \.element.id) { index, city in
                    CityTab(
                        city: city,
                        index: index + 1,
                        isSelected: selectedCityIndex == index
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedCityIndex = index
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - City Header Card
    private func cityHeaderCard(for city: CityStop) -> some View {
        ZStack {
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                    Text(city.location.name)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                if let itinerary = selectedItinerary {
                    HStack {
                        let daysText = Locale.current.language.languageCode?.identifier == "tr" ? "Gün" : "Days"
                        Label("\(city.duration) \(daysText)", systemImage: "calendar")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Budget: $\(Int(Double(city.duration) * multiCity.budgetPerDay))")
                            Text("Spent: $\(Int(totalSpent(for: itinerary)))")
                                .font(.caption)
                        }
                    }
                    .font(.subheadline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(multiCity.interests, id: \.self) { interest in
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
            }
            .foregroundColor(.white)
            .padding()
        }
        .cornerRadius(20)
        .padding(.horizontal)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            ActionButton(icon: "square.and.arrow.up", title: "Share", color: .blue) {
                shareTrip()
            }
            .frame(maxWidth: .infinity)
            
            ActionButton(icon: "star.fill", title: "Favorite", color: .yellow) {
                // TODO: Implement favorite
            }
            .frame(maxWidth: .infinity)
            
            ActionButton(icon: "trash", title: "Delete", color: .red) {
                showDeleteAlert = true
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Actions
    private func shareTrip() {
        // TODO: Implement share functionality
        print("Share trip tapped")
    }
    
    private func deleteTrip() {
        Task {
            try? await FirestoreService.shared.deleteMultiCityItinerary(multiCity.id)
            onDismiss()
            dismiss()
        }
    }
}

// MARK: - City Tab Component
struct CityTab: View {
    let city: CityStop
    let index: Int
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 24, height: 24)
                    
                    Text("\(index)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .blue : .white)
                }
                
                Text(city.location.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
            }
            
            Text("\(city.duration) days")
                .font(.caption2)
                .opacity(0.8)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(isSelected ? Color.blue : Color.gray.opacity(0.3))
        )
    }
}

// Safe array access extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
