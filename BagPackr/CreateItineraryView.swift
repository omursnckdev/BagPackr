//
//  CreateItineraryView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

struct CreateItineraryView: View {
    
    @StateObject private var viewModel = CreateItineraryViewModel()
    @ObservedObject var itineraryListViewModel: ItineraryListViewModel
    @StateObject private var adManager = AdManager.shared
    @State private var showPaywall = false
    @State private var showMapPicker = false
    @State private var isWaitingForAd = false
    @State private var showPremiumAlert = false  
    @StateObject private var planLimitService = PlanLimitService.shared
    // Locale-based values
    private var minBudget: Double {
        Locale.current.language.languageCode?.identifier == "tr" ? 1000 : 50
    }
    
    private var maxBudget: Double {
        Locale.current.language.languageCode?.identifier == "tr" ? 30000 : 1000
    }
    
    private var budgetStep: Double {
        Locale.current.language.languageCode?.identifier == "tr" ? 100 : 10
    }
    
    private var minBudgetText: String {
        Locale.current.language.languageCode?.identifier == "tr" ? "₺1000" : "$50"
    }
    
    private var maxBudgetText: String {
        Locale.current.language.languageCode?.identifier == "tr" ? "₺30000" : "$1000"
    }
    
    private var currencySymbol: String {
        Locale.current.language.languageCode?.identifier == "tr" ? "₺" : "$"
    }
    
    private var buttonGradientColors: [Color] {
        if isWaitingForAd || viewModel.isGenerating {
            return [Color.gray, Color.gray]
        } else if viewModel.canGenerate {
            return [Color.blue, Color.purple]
        } else {
            return [Color.gray, Color.gray]
        }
    }
    
    private var buttonShadowColor: Color {
        (viewModel.canGenerate && !viewModel.isGenerating && !isWaitingForAd)
        ? Color.blue.opacity(0.4)
        : Color.clear
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        locationCard
                        durationCard
                        budgetCard
                        interestsCard
                        customInterestsCard
                        generateButton
                    }
                    .padding()
                }
                .onTapGesture {
                    dismissKeyboard()
                }
            }
            .navigationTitle("Create Itinerary")
            .fullScreenCover(isPresented: $showMapPicker) {
                MapPickerView(selectedLocation: $viewModel.selectedLocation)
            }
            .sheet(item: $viewModel.generatedItinerary) { itinerary in
                ItineraryResultView(itinerary: itinerary, itineraryListViewModel: itineraryListViewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .overlay(alignment: .top) {
                         if viewModel.showSaveSuccess {
                             SaveSuccessNotification()
                                 .padding(.top, 50)  // Below navigation bar
                                 .transition(.move(edge: .top).combined(with: .opacity))
                                 .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showSaveSuccess)
                         }
                     }
        }
    }
    // ✅✅✅ ADD THIS ENTIRE STRUCT AT THE BOTTOM OF FILE ✅✅✅
    struct SaveSuccessNotification: View {
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Itinerary Saved!")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Your trip has been saved successfully")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .green.opacity(0.3), radius: 10, y: 5)
            )
            .padding(.horizontal)
        }
    }
    // ✅✅✅ END ✅✅✅
    
    // MARK: - View Components
    
    private var locationCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Location", systemImage: "mappin.circle.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Button(action: { showMapPicker = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.selectedLocation?.name ?? String(localized: "Select Location"))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            if viewModel.selectedLocation != nil {
                                Text("Tap to change")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var isTurkish: Bool {
        Locale.current.language.languageCode?.identifier == "tr"
    }
    
    private var durationCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Duration", systemImage: "calendar")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                HStack {
                    Text("\(viewModel.duration)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text("days")
                        .font(.title3)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Button(action: { viewModel.duration = min(14, viewModel.duration + 1) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: { viewModel.duration = max(1, viewModel.duration - 1) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }
    
    @State private var budgetText: String = ""
    @State private var isEditingBudget = false
    
    // Replace the budgetCard in CreateItineraryView.swift

    private var budgetCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Budget per Day", systemImage: "dollarsign.circle.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                HStack(alignment: .top, spacing: 0) {
                    // Left side - Budget input
                    HStack(spacing: 0) {
                        Text(currencySymbol)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.green)
                            .frame(width: 30, alignment: .leading)
                        
                        TextField("", text: $budgetText)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.green)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.leading)
                            .frame(width: 170)
                            .onChange(of: budgetText) { oldValue, newValue in
                                // ⭐ STEP 1: Filter to numbers only
                                let filtered = newValue.filter { $0.isNumber }
                                
                                // ⭐ STEP 2: Limit input length (max 6 digits = 100,000)
                                let maxDigits = isTurkish ? 6 : 5  // 100000₺ or 10000$
                                let limited = String(filtered.prefix(maxDigits))
                                
                                // ⭐ STEP 3: Update text field
                                if limited != newValue {
                                    budgetText = limited
                                    return
                                }
                                
                                // ⭐ STEP 4: Validate and update budget
                                if !limited.isEmpty, let value = Double(limited) {
                                    // Clamp between min and max
                                    let clampedValue = min(max(value, minBudget), maxBudget)
                                    viewModel.budgetPerDay = clampedValue
                                    isEditingBudget = true
                                    
                                    // If value exceeds max, update text to show max
                                    if value > maxBudget {
                                        budgetText = String(Int(maxBudget))
                                    }
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
                    
                    // Right side - Total (Fixed width)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 4) {
                            Text(currencySymbol)
                                .font(.headline)
                            Text("\(Int(viewModel.budgetPerDay * Double(viewModel.duration)))")
                                .font(.headline)
                        }
                        .foregroundColor(.primary)
                        .frame(width: 80, alignment: .trailing) // ✅ Fixed width
                    }
                }
                
                // Slider only (no labels)
                Slider(
                    value: Binding(
                        get: { min(viewModel.budgetPerDay, maxBudget) },
                        set: {
                            viewModel.budgetPerDay = $0
                            budgetText = String(Int($0))
                            isEditingBudget = false
                        }
                    ),
                    in: minBudget...maxBudget,
                    step: budgetStep
                )
                .accentColor(.green)
                .padding(.top, 8)
            }
        }
        .onAppear {
            if viewModel.budgetPerDay > 0 {
                budgetText = String(Int(viewModel.budgetPerDay))
            } else {
                budgetText = ""
            }
        }
    }
    
    private func finalizeBudgetEdit() {
        isEditingBudget = false
        if let value = Double(budgetText), value >= minBudget {
            viewModel.budgetPerDay = value
            budgetText = String(Int(value))
        } else {
            budgetText = String(Int(viewModel.budgetPerDay))
        }
    }
    
    private var interestsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 15) {
                Label("Select Interests", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                FlowLayout(spacing: 10) {
                    ForEach(viewModel.builtInInterests, id: \.self) { interest in
                        EnhancedInterestChip(
                            title: interest,
                            isSelected: viewModel.selectedInterests.contains(interest),
                            action: { withAnimation(.spring()) { viewModel.toggleInterest(interest) } }
                        )
                    }
                }
            }
        }
    }
    
    private var customInterestsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 15) {
                Label("Custom Interests", systemImage: "plus.square.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                HStack {
                    TextField("e.g., Temple, Sushi, Kebab", text: $viewModel.customInterestInput)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .submitLabel(.done)
                        .cornerRadius(10)
                        .onSubmit {
                            withAnimation(.spring()) {
                                viewModel.addCustomInterest()
                            }
                        }
                    
                    Button(action: { withAnimation(.spring()) { viewModel.addCustomInterest() } }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                
                if !viewModel.customInterests.isEmpty {
                    FlowLayout(spacing: 10) {
                        ForEach(viewModel.customInterests, id: \.self) { interest in
                            EnhancedInterestChip(
                                title: interest,
                                isSelected: viewModel.selectedInterests.contains(interest),
                                isCustom: true,
                                action: { withAnimation(.spring()) { viewModel.toggleInterest(interest) } },
                                onRemove: { withAnimation(.spring()) { viewModel.removeCustomInterest(interest) } }
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var generateButton: some View {
        Button(action: handleGenerateButtonTap) {
            buttonContent
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: buttonGradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(15)
                .shadow(color: buttonShadowColor, radius: 10, x: 0, y: 5)
        }
        .disabled(!viewModel.canGenerate || viewModel.isGenerating || isWaitingForAd)
        .alert("Premium Required 💎", isPresented: $viewModel.showPremiumAlert) {
                  Button("Upgrade to Premium") {
                      showPaywall = true
                  }
                  Button("Cancel", role: .cancel) {}
              } message: {
                  Text(viewModel.premiumAlertMessage)
              }
              
              // ⭐ NEW: Paywall sheet
              .sheet(isPresented: $showPaywall) {
                  PremiumPaywallView()
              }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var buttonContent: some View {
        HStack {
            if viewModel.isGenerating || isWaitingForAd {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.9)
                
                if isWaitingForAd {
                    Text("Loading ad...")
                        .fontWeight(.semibold)
                } else {
                    Text("Creating your journey...")
                        .fontWeight(.semibold)
                }
            } else {
                Image(systemName: "sparkles")
                Text("Generate Itinerary")
                    .fontWeight(.semibold)
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleGenerateButtonTap() {
        // ⭐ STEP 1: Check plan limit first
        if !planLimitService.canCreatePlan {
            showPremiumAlert = true
            print("⚠️ Plan limit reached: \(planLimitService.activePlansCount)/1")
            return
        }
        
        Task {
            // ⭐ STEP 2: Generate itinerary
            print("🚀 Starting itinerary generation...")
            await viewModel.generateItinerary(itineraryListViewModel: itineraryListViewModel)
            
            // ⭐ STEP 3: Increment count ONLY if successful
            if viewModel.generatedItinerary != nil {
                await planLimitService.incrementPlanCount()
                print("✅ Itinerary created successfully!")
                print("📊 New plan count: \(planLimitService.activePlansCount)/1")
            } else {
                print("❌ Itinerary generation failed, plan count not incremented")
            }
            
            // ⭐ STEP 4: Show ad
            await waitForAdAndShow()
        }
    }

    
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
        
        await MainActor.run {
            isWaitingForAd = true
        }
        print("⏳ Waiting for ad to load...")
        
        while !adManager.isAdReady && elapsed < maxWaitTime {
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            elapsed += checkInterval
        }
        
        await MainActor.run {
            isWaitingForAd = false
        }
        
        await MainActor.run {
            if adManager.isAdReady {
                print("✅ Ad loaded! Showing now...")
                AdManager.shared.showAd()
            } else {
                print("⏱️ Timeout: Ad couldn't load in \(maxWaitTime) seconds")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
