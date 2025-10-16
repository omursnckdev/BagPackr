//
//  EditItineraryView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI
// MARK: - Edit Itinerary View

struct EditItineraryView: View {
    @Environment(\.dismiss) var dismiss
    let itinerary: Itinerary
    let viewModel: ItineraryListViewModel
    
    @StateObject private var adManager = AdManager.shared // ✅ Eklendi
    
    @State private var editedDuration: Int
    @State private var editedBudget: Double
    @State private var editedInterests: Set<String>
    @State private var customInterestInput = ""
    @State private var customInterests: [String]
    @State private var isRegenerating = false
    @State private var isWaitingForAd = false // ✅ Eklendi
    @State private var showError = false
    @State private var errorMessage = ""
    
    @State private var budgetText: String = ""
    @State private var isEditingBudget = false
    
    private var minBudget: Double {
        Locale.current.language.languageCode?.identifier == "tr" ? 1000 : 50
    }
    
    private var maxBudget: Double {
        Locale.current.language.languageCode?.identifier == "tr" ? 30000 : 1000
    }
    
    private var currencySymbol: String {
        Locale.current.language.languageCode?.identifier == "tr" ? "₺" : "$"
    }
    
    private var minBudgetText: String {
        Locale.current.language.languageCode?.identifier == "tr" ? "₺1000" : "$50"
    }
    
    private var maxBudgetText: String {
        Locale.current.language.languageCode?.identifier == "tr" ? "₺30000" : "$1000"
    }
    
    // ✅ Güncellenmiş gradient colors
    private var buttonGradientColors: [Color] {
        if isRegenerating || isWaitingForAd {
            return [.gray, .gray]
        } else {
            return [.blue, .purple]
        }
    }
    
    // ✅ Güncellenmiş shadow color
    private var buttonShadowColor: Color {
        (isRegenerating || isWaitingForAd) ? .clear : .blue.opacity(0.4)
    }
    
    static let builtInInterests = [
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
    
    init(itinerary: Itinerary, viewModel: ItineraryListViewModel) {
        self.itinerary = itinerary
        self.viewModel = viewModel
        _editedDuration = State(initialValue: itinerary.duration)
        _editedBudget = State(initialValue: itinerary.budgetPerDay)
        _editedInterests = State(initialValue: Set(itinerary.interests))
        _customInterests = State(initialValue: itinerary.interests.filter { !Self.builtInInterests.contains($0) })
        _budgetText = State(initialValue: String(Int(itinerary.budgetPerDay)))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 📍 LOCATION CARD
                    ModernCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(String(localized: "Location"), systemImage: "mappin.circle.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Text(itinerary.location)
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text(String(localized: "Location cannot be changed"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                    }
                    
                    // 📅 DURATION CARD
                    ModernCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(String(localized: "Duration"), systemImage: "calendar")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            HStack {
                                Text("\(editedDuration)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.blue)
                                
                                Text(String(localized: "days"))
                                    .font(.title3)
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                VStack(spacing: 8) {
                                    Button(action: { editedDuration = min(14, editedDuration + 1) }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Button(action: { editedDuration = max(1, editedDuration - 1) }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                    }
                    
                    // 💰 BUDGET CARD
                    ModernCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(String(localized: "Budget per Day"), systemImage: "dollarsign.circle.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            HStack {
                                HStack(spacing: 4) {
                                    Text(currencySymbol)
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.green)
                                    
                                    TextField("", text: $budgetText)
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.green)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.leading)
                                        .frame(width: 170)
                                        .onTapGesture {
                                            if !isEditingBudget {
                                                isEditingBudget = true
                                                budgetText = String(Int(editedBudget))
                                            }
                                        }
                                        .onChange(of: budgetText) { oldValue, newValue in
                                            let filtered = newValue.filter { $0.isNumber }
                                            if filtered != newValue {
                                                budgetText = filtered
                                            }
                                            
                                            if let value = Double(filtered), value >= minBudget {
                                                editedBudget = value
                                            }
                                        }
                                        .onSubmit {
                                            finalizeBudgetEdit()
                                        }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.green.opacity(0.1))
                                )
                                
                                Spacer()
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { min(editedBudget, maxBudget) },
                                    set: { editedBudget = $0 }
                                ),
                                in: minBudget...maxBudget,
                                step: 10
                            )
                            .accentColor(.green)
                            .onChange(of: editedBudget) { oldValue, newValue in
                                if !isEditingBudget {
                                    budgetText = String(Int(newValue))
                                }
                            }
                            
                            HStack {
                                Text(minBudgetText)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(editedBudget > maxBudget ? "Custom" : "Tap number to type")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(maxBudgetText)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                    }
                    
                    // 🌟 INTERESTS CARD
                    ModernCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Label(String(localized: "Edit Interests"), systemImage: "star.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            FlowLayout(spacing: 10) {
                                ForEach(Self.builtInInterests, id: \.self) { interest in
                                    EnhancedInterestChip(
                                        title: interest,
                                        isSelected: editedInterests.contains(interest),
                                        action: { toggleInterest(interest) }
                                    )
                                }
                            }
                            
                            if !customInterests.isEmpty {
                                Divider()
                                
                                FlowLayout(spacing: 10) {
                                    ForEach(customInterests, id: \.self) { interest in
                                        EnhancedInterestChip(
                                            title: interest,
                                            isSelected: editedInterests.contains(interest),
                                            isCustom: true,
                                            action: { toggleInterest(interest) },
                                            onRemove: { removeCustomInterest(interest) }
                                        )
                                    }
                                }
                            }
                            
                            HStack {
                                TextField(String(localized: "Add custom interest"), text: $customInterestInput)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                    .submitLabel(.done)
                                
                                Button(action: addCustomInterest) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                    }
                    
                    // 🔁 REGENERATE BUTTON (✅ Güncellenmiş)
                    Button(action: handleRegenerateButtonTap) {
                        HStack {
                            if isRegenerating || isWaitingForAd {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                                
                                if isWaitingForAd {
                                    Text(String(localized: "Loading ad..."))
                                        .fontWeight(.semibold)
                                } else {
                                    Text(String(localized: "Regenerating..."))
                                        .fontWeight(.semibold)
                                }
                            } else {
                                Image(systemName: "arrow.clockwise")
                                Text(String(localized: "Regenerate Itinerary"))
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: buttonGradientColors, // ✅ Dinamik renkler
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(color: buttonShadowColor, radius: 10, x: 0, y: 5) // ✅ Dinamik shadow
                    }
                    .disabled(isRegenerating || isWaitingForAd || editedInterests.isEmpty) // ✅ isWaitingForAd eklendi
                    .padding(.horizontal)
                }
                .padding()
            }
            .onTapGesture {
                hideKeyboard()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "Edit Itinerary"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
            .alert(String(localized: "Error"), isPresented: $showError) {
                Button(String(localized: "OK"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func finalizeBudgetEdit() {
        isEditingBudget = false
        
        if let value = Double(budgetText) {
            let clamped = max(value, minBudget)
            editedBudget = clamped
            budgetText = String(Int(clamped))
        } else {
            budgetText = String(Int(editedBudget))
        }
    }
    
    private func toggleInterest(_ interest: String) {
        if editedInterests.contains(interest) {
            editedInterests.remove(interest)
        } else {
            editedInterests.insert(interest)
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
    
    private func addCustomInterest() {
        let trimmed = customInterestInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        customInterests.append(trimmed)
        editedInterests.insert(trimmed)
        customInterestInput = ""
    }
    
    private func removeCustomInterest(_ interest: String) {
        customInterests.removeAll { $0 == interest }
        editedInterests.remove(interest)
    }
    
    // ✅ Düzeltilmiş fonksiyon
    private func handleRegenerateButtonTap() {
        Task {
            dismiss()
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 saniye
            
            // 1. Reklamı bekle ve göster
            await waitForAdAndShow()
            
            // 2. Regenerate işlemini başlat
            await regenerateItinerary()
        }
    }
    
    // ✅ Yeni fonksiyon: Reklamı bekle ve göster
    
    private func waitForAdAndShow() async {
        let maxWaitTime: TimeInterval = 4.0
        let checkInterval: TimeInterval = 0.2
        var elapsed: TimeInterval = 0.0
        
        if adManager.isAdReady {
            print("✅ Ad already ready, showing immediately")
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                AdManager.shared.showAd()
            }
            return
        }
        
        print("⏳ Waiting for ad to load...")
        
        while !adManager.isAdReady && elapsed < maxWaitTime {
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            elapsed += checkInterval
        }
        
        await MainActor.run {
            if adManager.isAdReady {
                print("✅ Ad loaded! Showing now...")
                AdManager.shared.showAd()
            } else {
                print("⏱️ Timeout")
            }
        }
    }
    
    private func regenerateItinerary() async {
        do {
            let location = LocationData(
                name: itinerary.location,
                latitude: 0,
                longitude: 0
            )
            
            let newItinerary = try await GeminiService.shared.generateItinerary(
                location: location,
                duration: editedDuration,
                interests: Array(editedInterests),
                budgetPerDay: editedBudget
            )
            
            let updatedItinerary = Itinerary(
                id: itinerary.id,
                userId: itinerary.userId,
                location: itinerary.location,
                duration: editedDuration,
                interests: Array(editedInterests),
                dailyPlans: newItinerary.dailyPlans,
                budgetPerDay: editedBudget,
                createdAt: itinerary.createdAt
            )
            
            try await FirestoreService.shared.updateItinerary(updatedItinerary)
            await viewModel.loadItineraries()
            
        } catch {
            print("❌ Regeneration error: \(error.localizedDescription)")
        }
    }
    
    
}
