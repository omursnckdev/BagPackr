//
//  ItineraryDetailView.swift
//  BagPackr
//

import SwiftUI

struct ItineraryDetailView: View {
    let itineraryId: String
    @ObservedObject var viewModel: ItineraryListViewModel
    @StateObject private var limitService = PlanLimitService.shared
    
    @State private var showEditSheet = false
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var showGroupShare = false
    @State private var showPremiumAlert = false
    @State private var showPremiumSheet = false
    @State private var shareItems: [Any] = []
    @State private var isGeneratingPDF = false
    
    // NEW: Interest filtering
    @State private var selectedInterestsFilter: Set<String> = []
    
    @Environment(\.dismiss) var dismiss
    
    private var itinerary: Itinerary? {
        viewModel.itineraries.first(where: { $0.id == itineraryId })
    }
    
    private func totalSpent(for itinerary: Itinerary) -> Double {
        itinerary.dailyPlans.reduce(0) { total, plan in
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
    
    
    var body: some View {
        Group {
            if let itinerary = itinerary {
                ScrollView {
                    VStack(spacing: 20) {
                        headerCard(for: itinerary)
                        
                        // Filter indicator
                        if !selectedInterestsFilter.isEmpty {
                            filterIndicator
                        }
                        
                        actionButtons
                        
                        let plansToShow = filteredDailyPlans(for: itinerary)
                        
                        if plansToShow.isEmpty {
                            emptyFilterState
                        } else {
                            ForEach(Array(plansToShow.enumerated()), id: \.element.id) { index, plan in
                                EnhancedDayPlanCard(
                                    dayNumber: itinerary.dailyPlans.firstIndex(where: { $0.id == plan.id })! + 1,
                                    plan: plan,
                                    location: itinerary.location,
                                    itinerary: itinerary
                                )
                            }
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
                    ShareSheet(items: shareItems)
                }
                .sheet(isPresented: $showGroupShare) {
                    GroupShareView(itinerary: itinerary)
                }
                .sheet(isPresented: $showPremiumSheet) {
                    PremiumPaywallView()
                }
                .alert("Premium Feature", isPresented: $showPremiumAlert) {
                    Button("Upgrade to Premium") {
                        showPremiumSheet = true
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("PDF export is available for premium members. Upgrade now to export your itineraries!")
                }
                .alert("Delete Itinerary", isPresented: $showDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        deleteItinerary()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to delete this itinerary? This action cannot be undone.")
                }
              
            } else {
                ProgressView()
                    .onAppear {
                        Task { await viewModel.loadItineraries() }
                    }
            }
        }
    }
    
    // MARK: - Header Card
    
    private func headerCard(for itinerary: Itinerary) -> some View {
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
                
                // Tappable interests for filtering
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(itinerary.interests, id: \.self) { interest in
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
            
            Text("Filtering by \(selectedInterestsFilter.count) interest\(selectedInterestsFilter.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    selectedInterestsFilter.removeAll()
                }
            }) {
                Text("Clear")
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
            
            Text("No activities match your filter")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try selecting different interests or clear the filter")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    selectedInterestsFilter.removeAll()
                }
            }) {
                Text("Clear Filter")
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
            ActionButton(icon: "pencil", title: "Edit", color: .blue) {
                showEditSheet = true
            }
            .frame(maxWidth: .infinity)
            
            ActionButton(
                icon: "doc.text.fill",
                title: limitService.isPremium ? "Export PDF" : "PDF 👑",
                color: .green
            ) {
                handlePDFExport()
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
    
    private func handlePDFExport() {
        guard let itinerary = itinerary else { return }
        
        // Check premium status
        if !limitService.isPremium {
            showPremiumAlert = true
            return
        }
        
        isGeneratingPDF = true
        
        Task {
            if let pdfURL = PDFGenerator.shared.generatePDF(for: itinerary) {
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
    
    private func deleteItinerary() {
        Task {
            try? await FirestoreService.shared.deleteItinerary(itineraryId)
            await viewModel.loadItineraries()
            dismiss()
        }
    }
}


