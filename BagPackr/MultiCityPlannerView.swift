//
//  MultiCityPlannerView.swift - FIXED
//  BagPackr
//

import SwiftUI

struct MultiCityPlannerView: View {
    @StateObject private var viewModel = MultiCityPlannerViewModel()
    @StateObject private var limitService = PlanLimitService.shared
    @StateObject private var adManager = AdManager.shared
    @ObservedObject var itineraryListViewModel: ItineraryListViewModel
    
    @State private var showAddCity = false
    @State private var showLimitWarning = false
    @State private var showPremiumSheet = false
    @State private var budgetText = ""
    @State private var isEditingBudget = false
    @State private var isWaitingForAd = false
    
    // Locale detection
    private var isTurkish: Bool {
        Locale.current.language.languageCode?.identifier == "tr"
    }
    
    var currencySymbol: String {
        isTurkish ? "₺" : "$"
    }
    
    // Budget constraints - adapt based on currency
    private var minBudget: Double {
        isTurkish ? 1000 : 50
    }
    
    private var maxBudget: Double {
        isTurkish ? 30000 : 1000
    }
    
    private var budgetStep: Double {
        isTurkish ? 100 : 10
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        planLimitCard
                        titleCard
                        citiesCard
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
                .onAppear {
                    initializeBudgetText()
                    Task {
                        await limitService.checkPremiumStatus()
                        await limitService.loadActivePlansCount()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .premiumStatusChanged)) { _ in
                    print("🔔 Premium status changed notification received in MultiCityPlannerView")
                    Task {
                        await limitService.checkPremiumStatus()
                        await limitService.loadActivePlansCount()
                    }
                }
            }
            .navigationTitle("Multi-City Trip")
            .sheet(isPresented: $showAddCity) {
                AddCityStopView(onAdd: viewModel.addCity)
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumPaywallView()
            }
            .sheet(item: $viewModel.generatedMultiCity) { multiCity in
                MultiCityResultView(
                    multiCity: multiCity,
                    onDismiss: {
                        viewModel.resetForm()
                    }
                )
            }
            // ⭐ FIXED: Updated alert message
            .alert("Plan Limit Reached", isPresented: $showLimitWarning) {
                Button("Upgrade to Premium") {
                    showPremiumSheet = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You've reached your free plan limit (1 active plan). Upgrade to Premium for unlimited plans!")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .overlay {
                if viewModel.showSaveSuccess {
                    VStack {
                        SaveSuccessNotification()
                            .padding(.top, 50)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showSaveSuccess)
                }
            }
        }
    }
    
    // MARK: - Background Gradient
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Plan Limit Card (⭐ FIXED)
    
    private var planLimitCard: some View {
        ModernCard {
            HStack(spacing: 12) {
                Image(systemName: limitService.isPremium ? "crown.fill" : "info.circle.fill")
                    .font(.title2)
                    .foregroundColor(limitService.isPremium ? .yellow : .blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    if limitService.isPremium {
                        Text("Premium Member")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Unlimited plans")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("Free Plan")
                            .font(.headline)
                            .foregroundColor(.primary)
                        // ⭐ FIXED: Show active plans count instead of reset time
                        Text("\(limitService.activePlansCount)/1 plan used")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                if !limitService.isPremium {
                    Button(action: { showPremiumSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                            Text("Upgrade")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Title Card
    
    private var titleCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Trip Title", systemImage: "text.quote")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                TextField("e.g., Europe Adventure", text: $viewModel.tripTitle)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .submitLabel(.done)
            }
        }
    }
    
    // MARK: - Cities Card
    
    private var citiesCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Label("Cities (\(viewModel.cityStops.count))", systemImage: "mappin.and.ellipse")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button(action: { showAddCity = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add City")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    }
                }
                
                if viewModel.cityStops.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.3))
                        
                        Text("Add at least 2 cities to create a multi-city trip")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    ForEach(Array(viewModel.cityStops.enumerated()), id: \.element.id) { index, stop in
                        CityStopRow(
                            stop: stop,
                            index: index,
                            onRemove: { viewModel.removeCity(stop) }
                        )
                    }
                }
                
                if !viewModel.cityStops.isEmpty {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.gray)
                        Text("Total: \(viewModel.totalDuration) days")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Image(systemName: "dollarsign.circle")
                            .foregroundColor(.gray)
                        Text("\(currencySymbol)\(Int(viewModel.totalBudget))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Budget Card
    
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
                    
                    // Right side - Total
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total Trip:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 4) {
                            Text(currencySymbol)
                                .font(.headline)
                            Text("\(Int(viewModel.totalBudget))")
                                .font(.headline)
                        }
                        .foregroundColor(.primary)
                        .frame(width: 80, alignment: .trailing)
                    }
                }
                
                // Slider
                Slider(
                    value: Binding(
                        get: {
                            min(max(viewModel.budgetPerDay, minBudget), maxBudget)
                        },
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
    }
    
    // MARK: - Interests Card
    
    private var interestsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 15) {
                Label("Select Interests", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                FlowLayout(spacing: 10) {
                    ForEach(viewModel.availableInterests, id: \.self) { interest in
                        EnhancedInterestChip(
                            title: interest,
                            isSelected: viewModel.selectedInterests.contains(interest),
                            action: {
                                withAnimation(.spring()) {
                                    viewModel.toggleInterest(interest)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Custom Interests Card
    
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
                        .cornerRadius(10)
                        .submitLabel(.done)
                        .onSubmit {
                            withAnimation(.spring()) {
                                viewModel.addCustomInterest()
                            }
                        }
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            viewModel.addCustomInterest()
                        }
                    }) {
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
                                action: {
                                    withAnimation(.spring()) {
                                        viewModel.toggleInterest(interest)
                                    }
                                },
                                onRemove: {
                                    withAnimation(.spring()) {
                                        viewModel.removeCustomInterest(interest)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Generate Button
    
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
                Text("Generate Multi-City Trip")
                    .fontWeight(.semibold)
            }
        }
    }
    
    private var buttonGradientColors: [Color] {
        if viewModel.canGenerate && !viewModel.isGenerating && !isWaitingForAd {
            return [.blue, .purple]
        } else {
            return [.gray, .gray]
        }
    }
    
    private var buttonShadowColor: Color {
        (viewModel.canGenerate && !viewModel.isGenerating && !isWaitingForAd) ? .blue.opacity(0.4) : .clear
    }
    
    // MARK: - Helper Functions
    
    private func initializeBudgetText() {
        if viewModel.budgetPerDay > 0 {
            budgetText = String(Int(viewModel.budgetPerDay))
        } else {
            viewModel.budgetPerDay = minBudget
            budgetText = String(Int(minBudget))
        }
    }
    
    private func finalizeBudgetEdit() {
        if budgetText.isEmpty {
            viewModel.budgetPerDay = minBudget
            budgetText = String(Int(minBudget))
        } else if let value = Double(budgetText), value < minBudget {
            viewModel.budgetPerDay = minBudget
            budgetText = String(Int(minBudget))
        } else if let value = Double(budgetText), value > maxBudget {
            viewModel.budgetPerDay = maxBudget
            budgetText = String(Int(maxBudget))
        }
        isEditingBudget = false
        dismissKeyboard()
    }
    
    // MARK: - Actions (⭐ FIXED)
    
    // MARK: - Actions (⭐ IMPROVED)

    private func handleGenerateButtonTap() {
        // Check plan limit first
        if !limitService.canCreatePlan {
            showLimitWarning = true
            return
        }
        
        Task {
            // Generate multi-city trip
            await viewModel.generateMultiCityTrip()
            
            // ⭐ IMPROVED: Only increment if generation was successful
            if viewModel.generatedMultiCity != nil {
                await limitService.incrementPlanCount()
                print("✅ Multi-city plan created, count incremented")
            } else if !viewModel.showError {
                // If no error shown but also no result, still increment
                // (edge case handling)
                await limitService.incrementPlanCount()
            }
            
            // Show ad
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
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - Supporting Components

struct CityStopRow: View {
    let stop: CityStop
    let index: Int
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Text("\(index + 1)")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(stop.location.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Label("\(stop.duration) days", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SaveSuccessNotification: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
            
            Text("Trip saved successfully!")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
}
