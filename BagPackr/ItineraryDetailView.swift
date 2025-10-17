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
    
    @Environment(\.dismiss) var dismiss
    
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
                        headerCard(for: itinerary)
                        actionButtons
                        
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
                    ShareSheet(items: shareItems)
                }
                .sheet(isPresented: $showGroupShare) {
                    GroupShareView(itinerary: itinerary)
                }
                .sheet(isPresented: $showPremiumSheet) {
                    PremiumUpgradeView()
                }
                .alert("Premium Feature", isPresented: $showPremiumAlert) {
                    Button("Upgrade to Premium") {
                        showPremiumSheet = true
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("PDF export is available for premium members. Upgrade now to export your itineraries!")
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
