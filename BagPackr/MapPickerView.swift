//
//  MapPickerView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI
import FirebaseCore
import GoogleMaps
import GooglePlaces
import MapKit
import Combine
import GoogleMobileAds
import FirebaseMessaging
import UserNotifications

// MARK: - Map Picker View
struct MapPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLocation: LocationData?
    @State private var searchText = ""
    @State private var mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 20.0, longitude: 0.0)
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var placeName: String = ""
    @State private var isLocationLocked = false
    @State private var searchResults: [GMSAutocompletePrediction] = []
    @State private var showResults = false
    @State private var searchTask: DispatchWorkItem?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map - Background
                GoogleMapView(
                    center: $mapCenter,
                    selectedCoordinate: $selectedCoordinate,
                    placeName: $placeName,
                    isLocationLocked: $isLocationLocked
                )
                .ignoresSafeArea()
                
                // Search bar and results - Always on top
                VStack {
                    VStack(spacing: 0) {
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search location", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .autocorrectionDisabled()
                                .foregroundColor(.primary)
                                .onSubmit {
                                    // Trigger search when user presses Enter/Return
                                    performSearch()
                                }
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    searchResults = []
                                    showResults = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        )
                        .padding()
                        
                        // Search Results
                        if showResults && !searchResults.isEmpty {
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(searchResults, id: \.placeID) { result in
                                        Button(action: { selectSearchResult(result) }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(result.attributedPrimaryText.string)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                
                                                if let secondary = result.attributedSecondaryText?.string {
                                                    Text(secondary)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding()
                                        }
                                        
                                        if result.placeID != searchResults.last?.placeID {
                                            Divider()
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
                
                // Confirm Button - Always at bottom when coordinate selected
                if selectedCoordinate != nil {
                    VStack {
                        Spacer()
                        
                        Button(action: confirmSelection) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Confirm: \(placeName)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                // Debounce the search - wait 0.3 seconds after user stops typing
                searchTask?.cancel()
                
                guard !newValue.isEmpty else {
                    searchResults = []
                    showResults = false
                    return
                }
                
                let task = DispatchWorkItem { [newValue] in
                    performSearch(query: newValue)
                }
                searchTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
            }
        }
    }
    
    private func performSearch(query: String? = nil) {
        let searchQuery = query ?? searchText
        
        guard !searchQuery.isEmpty else {
            searchResults = []
            showResults = false
            return
        }
        
        print("Searching for: \(searchQuery)")
        
        let placesClient = GMSPlacesClient.shared()
        let filter = GMSAutocompleteFilter()
        // Remove restrictive types or use nil for all types
        filter.types = nil  // This allows all place types including cities
        // Or you can try: filter.types = ["geocode"] for addresses and cities
        
        placesClient.findAutocompletePredictions(fromQuery: searchQuery, filter: filter, sessionToken: nil) { results, error in
            if let error = error {
                print("Search error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.searchResults = []
                    self.showResults = false
                }
                return
            }
            
            print("Found \(results?.count ?? 0) results")
            
            guard let results = results else {
                DispatchQueue.main.async {
                    self.searchResults = []
                    self.showResults = false
                }
                return
            }
            
            DispatchQueue.main.async {
                self.searchResults = results
                self.showResults = true
                print("Results updated, showing: \(results.count) items")
            }
        }
    }
    
    private func selectSearchResult(_ result: GMSAutocompletePrediction) {
        let placesClient = GMSPlacesClient.shared()
        
        print("Selecting place: \(result.attributedPrimaryText.string)")
        
        placesClient.fetchPlace(fromPlaceID: result.placeID, placeFields: .all, sessionToken: nil) { place, error in
            if let error = error {
                print("Fetch place error: \(error.localizedDescription)")
                return
            }
            
            guard let place = place else {
                print("No place returned")
                return
            }
            
            print("Place found: \(place.name ?? "Unknown") at \(place.coordinate.latitude), \(place.coordinate.longitude)")
            
            DispatchQueue.main.async {
                self.mapCenter = place.coordinate
                self.selectedCoordinate = place.coordinate
                self.placeName = place.name ?? result.attributedPrimaryText.string
                self.searchText = self.placeName
                self.searchResults = []
                self.showResults = false
                self.isLocationLocked = true
            }
        }
    }
    
    private func confirmSelection() {
        if let coordinate = selectedCoordinate {
            selectedLocation = LocationData(
                name: placeName,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            dismiss()
        }
    }
}
