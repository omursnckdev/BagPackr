//
//  ItineraryListView.swift
//  BagPackr
//

import SwiftUI
import FirebaseAuth

struct ItineraryListView: View {
    @ObservedObject var viewModel: ItineraryListViewModel
    @StateObject private var planLimitService = PlanLimitService.shared
    @State private var showPaywall = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.itineraries.isEmpty && viewModel.multiCityItineraries.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
               
                        
                        List {
                      
                            // Multi-City Section
                            if !viewModel.multiCityItineraries.isEmpty {
                                Section {
                                    ForEach(viewModel.multiCityItineraries) { multiCity in
                                        NavigationLink(destination: MultiCityDetailView(multiCity: multiCity, viewModel: viewModel)) {
                                            MultiCityItineraryCard(multiCity: multiCity)
                                        }
                                    }
                                    .onDelete(perform: deleteMultiCityItineraries)
                                } header: {
                                    HStack {
                                        Image(systemName: "map.fill")
                                        Text("Multi-City Trips")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                            
                            // Single City Section
                            if !viewModel.itineraries.isEmpty {
                                Section {
                                    ForEach(viewModel.itineraries) { itinerary in
                                        NavigationLink(destination: ItineraryDetailView(itineraryId: itinerary.id, viewModel: viewModel)) {
                                            EnhancedItineraryListRow(itinerary: itinerary)
                                        }
                                    }
                                    .onDelete(perform: deleteItineraries)
                                } header: {
                                    HStack {
                                        Image(systemName: "airplane.departure")
                                        Text("Single City Trips")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .background(Color(.systemGroupedBackground))
                        
                        if !planLimitService.isPremium && planLimitService.activePlansCount > 0 {
                            planLimitBanner
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
            }
            .navigationTitle("My Itineraries")
            .onAppear {
                Task {
                    await viewModel.loadItineraries()
                    await planLimitService.checkPremiumStatus()
                    await planLimitService.loadActivePlansCount()
                }
            }
            .refreshable {
                await viewModel.loadItineraries()
                await planLimitService.loadActivePlansCount()
            }
            .sheet(isPresented: $showPaywall) {
                PremiumPaywallView()
            }
        }
    }
    
    // MARK: - Plan Limit Banner
    private var planLimitBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: planLimitService.remainingPlans == 0 ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.title3)
                .foregroundColor(planLimitService.remainingPlans == 0 ? .orange : .blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Free Plan")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                Text("\(planLimitService.activePlansCount)/1 plan used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if planLimitService.remainingPlans == 0 {
                Button {
                    showPaywall = true
                } label: {
                    Text("Upgrade")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(planLimitService.remainingPlans == 0 ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    planLimitService.remainingPlans == 0 ? Color.orange.opacity(0.3) : Color.blue.opacity(0.3),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }
            
            Text("No itineraries yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first travel plan and start exploring!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Delete Functions
    private func deleteItineraries(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let itinerary = viewModel.itineraries[index]
                await viewModel.deleteItinerary(itinerary)  // ⭐ Use ViewModel method
            }
            
            await planLimitService.loadActivePlansCount()
            print("✅ Itinerary deleted, remaining slots: \(planLimitService.remainingPlans)")
        }
    }
    
    private func deleteMultiCityItineraries(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let multiCity = viewModel.multiCityItineraries[index]
                await viewModel.deleteMultiCityItinerary(multiCity)  // ⭐ Use ViewModel method
            }
            
            await planLimitService.loadActivePlansCount()
            print("✅ Multi-city itinerary deleted, remaining slots: \(planLimitService.remainingPlans)")
        }
    }
}
