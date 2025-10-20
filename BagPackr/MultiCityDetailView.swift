//
//  MultiCityDetailView.swift
//  BagPackr
//

import SwiftUI

struct MultiCityDetailView: View {
    let multiCity: MultiCityItinerary
    @ObservedObject var viewModel: ItineraryListViewModel
    @StateObject private var limitService = PlanLimitService.shared
    
    @State private var selectedCityIndex = 0
    @State private var showDeleteAlert = false
    @State private var showShareSheet = false
    @State private var showPremiumAlert = false
    @State private var showPremiumSheet = false
    @State private var shareItems: [Any] = []
    @State private var isGeneratingPDF = false
    
    // NEW: Interest filtering
    @State private var selectedInterestsFilter: Set<String> = []
    
    @Environment(\.dismiss) var dismiss

    private var selectedCity: CityStop? {
        multiCity.cityStops[safe: selectedCityIndex]
    }

    private var selectedItinerary: Itinerary? {
        guard let city = selectedCity else { return nil }
        return multiCity.itineraries[city.id]
    }

    private func totalSpent(for itinerary: Itinerary?) -> Double {
        guard let itinerary else { return 0 }
        return itinerary.dailyPlans.reduce(0) { total, plan in
            total + plan.activities.reduce(0) { $0 + $1.cost }
        }
    }
    
    // NEW: Filter daily plans based on selected interests
    private func filteredDailyPlans(for itinerary: Itinerary) -> [DailyPlan] {
        guard !selectedInterestsFilter.isEmpty else {
            return itinerary.dailyPlans
        }
        
        return itinerary.dailyPlans.compactMap { plan -> DailyPlan? in
            let filteredActivities = plan.activities.filter { activity in
                // Check if the activity type matches any selected interest
                return selectedInterestsFilter.contains { interest in
                    activity.type.localizedCaseInsensitiveContains(interest) ||
                    interest.localizedCaseInsensitiveContains(activity.type)
                }
            }
            
            // Only return the plan if it has matching activities
            guard !filteredActivities.isEmpty else { return nil }
            
            // Create a new DailyPlan with filtered activities
            return DailyPlan(
                id: plan.id,
                day: plan.day,
                activities: filteredActivities
            )
        }
    }

    private var isTR: Bool {
        Locale.current.language.languageCode?.identifier == "tr"
    }

    private var currencySymbol: String {
        isTR ? "₺" : "$"
    }

    private var daysLabel: String {
        isTR ? "Gün" : "Days"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                mainHeaderCard
                cityTabsSection
                
                if let city = selectedCity {
                    cityHeaderCard(for: city)
                }
                
                // Filter indicator
                if !selectedInterestsFilter.isEmpty {
                    filterIndicator
                }
                
                actionButtons
                
                if let itinerary = selectedItinerary {
                    let plansToShow = filteredDailyPlans(for: itinerary)
                    
                    if plansToShow.isEmpty {
                        emptyFilterState
                    } else {
                        ForEach(Array(plansToShow.enumerated()), id: \.element.id) { index, plan in
                            EnhancedDayPlanCard(
                                dayNumber: itinerary.dailyPlans.firstIndex(where: { $0.id == plan.id })! + 1,
                                plan: plan,
                                location: selectedCity?.location.name ?? "",
                                itinerary: itinerary
                            )
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(multiCity.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Multi-City Trip", isPresented: $showDeleteAlert) {
            Button(isTR ? "Sil" : "Delete", role: .destructive) {
                deleteTrip()
            }
            Button(isTR ? "İptal" : "Cancel", role: .cancel) { }
        } message: {
            Text(isTR ? "Bu gezinizi silmek istediğinizden emin misiniz?" : "Are you sure you want to delete this multi-city trip?")
        }
        .alert("Premium Feature", isPresented: $showPremiumAlert) {
            Button("Upgrade to Premium") {
                showPremiumSheet = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("PDF export is available for premium members. Upgrade now to export your trips!")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showPremiumSheet) {
            PremiumUpgradeView()
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
                    Image(systemName: "map.fill").font(.title)
                    Text(multiCity.title)
                        .font(.title).fontWeight(.bold)
                        .lineLimit(1)
                }

                HStack {
                    Label("\(multiCity.citiesCount) " + (isTR ? "şehir" : "cities"),
                          systemImage: "mappin.and.ellipse")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(currencySymbol)\(Int(multiCity.totalBudget))")
                        Text("\(multiCity.totalDuration) " + daysLabel)
                            .font(.caption)
                            .opacity(0.9)
                    }
                }
                .font(.subheadline)

                if !multiCity.cityNames.isEmpty {
                    Text(multiCity.cityNames)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(15)
                }
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
                        isSelected: selectedCityIndex == index,
                        daysLabel: daysLabel
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

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "mappin.circle.fill").font(.title2)
                    Text(city.location.name)
                        .font(.title2).fontWeight(.bold)
                        .lineLimit(1)
                }

                if let itinerary = selectedItinerary {
                    HStack {
                        Label("\(city.duration) \(daysLabel)", systemImage: "calendar")
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(currencySymbol)\(Int(Double(city.duration) * multiCity.budgetPerDay))")
                            Text((isTR ? "Harcanan: " : "Spent: ") +
                                 "\(currencySymbol)\(Int(totalSpent(for: itinerary)))")
                                .font(.caption)
                                .opacity(0.9)
                        }
                    }
                    .font(.subheadline)

                    // Tappable interests for filtering
                    if !multiCity.interests.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(multiCity.interests, id: \.self) { interest in
                                    InterestFilterChip(
                                        interest: interest,
                                        isSelected: selectedInterestsFilter.contains(interest),
                                        action: {
                                            withAnimation(.spring(response: 0.3)) {
                                                if selectedInterestsFilter.contains(interest) {
                                                    selectedInterestsFilter.remove(interest)
                                                } else {
                                                    selectedInterestsFilter.insert(interest)
                                                }
                                            }
                                        }
                                    )
                                }
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
    
    // MARK: - Filter Indicator
    
    private var filterIndicator: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(.blue)
            
            Text(isTR ? "\(selectedInterestsFilter.count) ilgiye göre filtreleniyor" : "Filtering by \(selectedInterestsFilter.count) interest\(selectedInterestsFilter.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    selectedInterestsFilter.removeAll()
                }
            }) {
                Text(isTR ? "Temizle" : "Clear")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // MARK: - Empty Filter State
    
    private var emptyFilterState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(isTR ? "Filtrenize uygun aktivite bulunamadı" : "No activities match your filter")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(isTR ? "Farklı ilgi alanları seçin veya filtreyi temizleyin" : "Try selecting different interests or clear the filter")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    selectedInterestsFilter.removeAll()
                }
            }) {
                Text(isTR ? "Filtreyi Temizle" : "Clear Filter")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            ActionButton(
                icon: isGeneratingPDF ? "hourglass" : "doc.text.fill",
                title: isGeneratingPDF ? "..." : (limitService.isPremium ? "PDF" : "PDF 👑"),
                color: .green
            ) {
                handlePDFExport()
            }
            .frame(maxWidth: .infinity)
            .disabled(isGeneratingPDF)
            
            ActionButton(icon: "trash",
                         title: isTR ? "Sil" : "Delete",
                         color: .red) {
                showDeleteAlert = true
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Actions
    
    private func handlePDFExport() {
        // Check premium status
        if !limitService.isPremium {
            showPremiumAlert = true
            return
        }
        
        isGeneratingPDF = true
        
        Task {
            if let pdfURL = PDFGenerator.shared.generatePDF(for: multiCity) {
                await MainActor.run {
                    shareItems = [pdfURL]
                    showShareSheet = true
                    isGeneratingPDF = false
                }
            } else {
                await MainActor.run {
                    isGeneratingPDF = false
                }
            }
        }
    }
    
    private func shareTrip() {
        shareItems = [generateShareText()]
        showShareSheet = true
    }

    private func deleteTrip() {
        Task {
            try? await FirestoreService.shared.deleteMultiCityItinerary(multiCity.id)
            await viewModel.loadItineraries()
            dismiss()
        }
    }

    private func generateShareText() -> String {
        var text = "🗺️ \(multiCity.title)\n"
        text += "🏙️ \(multiCity.cityNames)\n"
        text += "📆 \(multiCity.totalDuration) \(daysLabel)\n"
        text += "💰 \(currencySymbol)\(Int(multiCity.totalBudget))\n\n"

        for city in multiCity.cityStops {
            guard let itin = multiCity.itineraries[city.id] else { continue }
            text += "🏁 \(city.location.name) — \(city.duration) \(daysLabel)\n"
            
            for (index, plan) in itin.dailyPlans.enumerated() {
                text += "   📅 Day \(index + 1):\n"
                for activity in plan.activities {
                    text += "     • \(activity.time) - \(activity.name)\n"
                }
            }
            text += "\n"
        }

        text += "Created with BagPckr ✈️"
        return text
    }
}

// MARK: - Safe Array Access Extension
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Interest Filter Chip Component

struct InterestFilterChip: View {
    let interest: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                }
                
                Text(LocalizedStringKey(interest))
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? Color.white.opacity(0.9)
                    : Color.white.opacity(0.3)
            )
            .foregroundColor(isSelected ? .blue : .white)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
    }
}

