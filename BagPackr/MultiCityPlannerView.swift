//
//  MultiCityPlannerView.swift
//  BagPackr
//

import SwiftUI

struct MultiCityPlannerView: View {
    @StateObject private var viewModel = MultiCityPlannerViewModel()
    @StateObject private var limitService = PlanLimitService.shared
    @ObservedObject var itineraryListViewModel: ItineraryListViewModel
    
    @State private var showAddCity = false
    @State private var showLimitWarning = false
    @State private var showPremiumSheet = false
    
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
                        generateButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Multi-City Trip")
            .sheet(isPresented: $showAddCity) {
                AddCityStopView(onAdd: viewModel.addCity)
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumUpgradeView()
            }
            .sheet(item: $viewModel.generatedMultiCity) { multiCity in
                MultiCityResultView(
                    multiCity: multiCity,
                    onDismiss: {
                        viewModel.resetForm()
                    }
                )
            }
            .alert("Plan Limit Reached", isPresented: $showLimitWarning) {
                Button("Upgrade to Premium") {
                    showPremiumSheet = true
                }
                Button("Wait", role: .cancel) { }
            } message: {
                Text("You've reached your free plan limit. Next reset in \(limitService.getTimeUntilReset())")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var planLimitCard: some View {
        ModernCard {
            HStack(spacing: 12) {
                Image(systemName: limitService.isPremium ? "crown.fill" : "clock.fill")
                    .font(.title2)
                    .foregroundColor(limitService.isPremium ? .yellow : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    if limitService.isPremium {
                        Text("Premium Member")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Unlimited plans")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("\(limitService.remainingPlans) plans left")
                            .font(.headline)
                            .foregroundColor(.primary)
                        if let _ = limitService.nextResetTime {
                            Text("Resets in \(limitService.getTimeUntilReset())")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
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
            }
        }
    }
    
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
                        Text("$\(Int(viewModel.totalBudget))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private var budgetCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Budget per Day", systemImage: "dollarsign.circle.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                HStack {
                    Text("$\(Int(viewModel.budgetPerDay))")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Total Trip:")
                            .font(.caption)
                        Text("$\(Int(viewModel.totalBudget))")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
                
                Slider(value: $viewModel.budgetPerDay, in: 1000...30000, step: 10)
                    .accentColor(.green)
            }
        }
    }
    
    private var interestsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 15) {
                Label("Interests", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                FlowLayout(spacing: 10) {
                    ForEach(viewModel.availableInterests, id: \.self) { interest in
                        EnhancedInterestChip(
                            title: interest,
                            isSelected: viewModel.selectedInterests.contains(interest),
                            action: { viewModel.toggleInterest(interest) }
                        )
                    }
                }
            }
        }
    }
    
    private var generateButton: some View {
        Button(action: handleGenerate) {
            HStack {
                if viewModel.isGenerating {
                    ProgressView()
                        .tint(.white)
                    Text("Generating...")
                } else {
                    Image(systemName: "sparkles")
                    Text("Generate Multi-City Trip")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: viewModel.canGenerate ? [.blue, .purple] : [.gray, .gray],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(15)
            .shadow(color: viewModel.canGenerate ? .blue.opacity(0.4) : .clear, radius: 10)
        }
        .disabled(!viewModel.canGenerate || viewModel.isGenerating)
    }
    
    private func handleGenerate() {
        if !limitService.canGeneratePlan() {
            showLimitWarning = true
            return
        }
        
        Task {
            await viewModel.generateMultiCityTrip()
            try? await limitService.incrementPlanCount()
        }
    }
}

// MARK: - City Stop Row Component
struct CityStopRow: View {
    let stop: CityStop
    let index: Int
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text("\(index + 1)")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(stop.location.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(stop.duration) days")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "trash.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}
