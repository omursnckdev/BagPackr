//
//  ItineraryListView.swift
//  BagPackr
//

import SwiftUI
import FirebaseAuth

struct ItineraryListView: View {
    @ObservedObject var viewModel: ItineraryListViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.itineraries.isEmpty && viewModel.multiCityItineraries.isEmpty {
                    emptyStateView
                } else {
                    List {
                        // ✅ Multi-City Section - NavigationLink ile
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
                }
            }
            .navigationTitle("My Itineraries")
            .onAppear {
                Task {
                    await viewModel.loadItineraries()
                }
            }
            .refreshable {
                await viewModel.loadItineraries()
            }
        }
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
                try? await FirestoreService.shared.deleteItinerary(itinerary.id)
            }
            await viewModel.loadItineraries()
        }
    }
    
    private func deleteMultiCityItineraries(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let multiCity = viewModel.multiCityItineraries[index]
                try? await FirestoreService.shared.deleteMultiCityItinerary(multiCity.id)
            }
            await viewModel.loadItineraries()
        }
    }
}
