//
//  MapPickerView.swift - Fix gray area while keeping NavigationView
//  BagPackr
//

import SwiftUI
import GoogleMaps
import GooglePlaces

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
                // ✅ Map - CRITICAL: Place BEFORE VStack and extend to top
                GoogleMapView(
                    center: $mapCenter,
                    selectedCoordinate: $selectedCoordinate,
                    placeName: $placeName,
                    isLocationLocked: $isLocationLocked
                )
                .edgesIgnoringSafeArea(.all)  // ✅ Extends behind navigation bar
                
                // Search bar and results - Overlay on top
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
            // ✅ CRITICAL: This makes the content extend behind the nav bar
            .toolbarBackground(.hidden, for: .navigationBar)  // Makes navbar transparent
            .background(Color.clear)  // Ensure no gray background
            .onChange(of: searchText) { oldValue, newValue in
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
        filter.types = nil
        
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
