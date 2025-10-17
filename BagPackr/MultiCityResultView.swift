//
//  MultiCityResultView.swift
//  BagPackr
//

import SwiftUI

struct MultiCityResultView: View {
    @Environment(\.dismiss) var dismiss
    let multiCity: MultiCityItinerary
    let onDismiss: () -> Void

    @State private var selectedCityIndex = 0
    @State private var showDeleteAlert = false
    @State private var showShareSheet = false
    @State private var shareText = ""

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
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    mainHeaderCard
                    cityTabsSection
                    
                    if let city = selectedCity {
                        cityHeaderCard(for: city)
                    }
                    
                    actionButtons
                    
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
            .navigationTitle(isTR ? "Çok Şehirli Gezi" : "Multi-City Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onDismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareTrip) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .alert(isTR ? "Geziyi Sil" : "Delete Trip", isPresented: $showDeleteAlert) {
                Button(isTR ? "Vazgeç" : "Cancel", role: .cancel) { }
                Button(isTR ? "Sil" : "Delete", role: .destructive) {
                    deleteTrip()
                }
            } message: {
                Text(isTR
                     ? "Bu çok şehirli geziyi silmek istediğine emin misin?"
                     : "Are you sure you want to delete this multi-city trip?")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [shareText])
            }
        }
    }
    
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

                    if !multiCity.interests.isEmpty {
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
            }
            .foregroundColor(.white)
            .padding()
        }
        .cornerRadius(20)
        .padding(.horizontal)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            ActionButton(icon: "square.and.arrow.up",
                         title: isTR ? "Paylaş" : "Share",
                         color: .blue) {
                shareTrip()
            }
            .frame(maxWidth: .infinity)

            ActionButton(icon: "trash",
                         title: isTR ? "Sil" : "Delete",
                         color: .red) {
                showDeleteAlert = true
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }
    
    private func shareTrip() {
        shareText = generateShareText()
        showShareSheet = true
    }

    private func deleteTrip() {
        Task {
            try? await FirestoreService.shared.deleteMultiCityItinerary(multiCity.id)
            onDismiss()
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

// MARK: - City Tab Component
struct CityTab: View {
    let city: CityStop
    let index: Int
    let isSelected: Bool
    let daysLabel: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 24, height: 24)

                    Text("\(index)")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(isSelected ? .blue : .white)
                }

                Text(city.location.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
            }

            Text("\(city.duration) \(daysLabel)")
                .font(.caption2)
                .opacity(0.85)
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

// MARK: - Safe Array Access
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
