//
//  EnhancedDayPlanCard.swift
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

// MARK: - Enhanced Day Plan Card with Checklist & Navigation
struct EnhancedDayPlanCard: View {
    let dayNumber: Int
    let plan: DailyPlan
    let location: String
    let itinerary: Itinerary
    @State private var showMap = false
    @State private var completedActivities: Set<String> = []
    
    var dailyBudget: Double {
        plan.activities.reduce(0) { $0 + $1.cost }
    }
    
    var completionPercentage: Double {
        guard !plan.activities.isEmpty else { return 0 }
        return Double(completedActivities.count) / Double(plan.activities.count) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Day \(dayNumber)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("$\(Int(dailyBudget))")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text("\(completedActivities.count)/\(plan.activities.count) done")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Button(action: { showMap.toggle() }) {
                    Label(showMap ? "Hide" : "Map", systemImage: showMap ? "map.fill" : "map")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(15)
                }
            }
            .padding()
            .background(
                ZStack {
                    Color.blue.opacity(0.1)
                    
                    // Progress bar
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: geometry.size.width * (completionPercentage / 100))
                    }
                }
            )
            
            // Map View - FIX #2: Improved to show activity locations
            if showMap {
                ActivitiesMapView(
                    activities: plan.activities,
                    location: location,
                    
                )
                .frame(height: 250)
                .transition(.opacity)
            }
            
            // Activities with Checklist
            VStack(spacing: 0) {
                ForEach(Array(plan.activities.enumerated()), id: \.element.id) { index, activity in
                    EnhancedActivityRow(
                        activity: activity,
                        number: index + 1,
                        isCompleted: completedActivities.contains(activity.id),
                        onToggleComplete: {
                            withAnimation {
                                if completedActivities.contains(activity.id) {
                                    completedActivities.remove(activity.id)
                                } else {
                                    completedActivities.insert(activity.id)
                                }
                                // Save to Firestore
                                saveProgress()
                            }
                        },
                        onNavigate: {
                            openInMaps(activity: activity, location: location)
                        }
                    )
                    
                    if index < plan.activities.count - 1 {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
        .animation(.spring(), value: showMap)
        .onAppear {
            loadProgress()
        }
    }
    
    private func saveProgress() {
        Task {
            try? await FirestoreService.shared.updateItineraryProgress(
                itineraryId: itinerary.id,
                dayId: plan.id,
                completedActivities: Array(completedActivities)
            )
        }
    }
    
    private func loadProgress() {
        Task {
            if let progress = try? await FirestoreService.shared.getItineraryProgress(
                itineraryId: itinerary.id,
                dayId: plan.id
            ) {
                completedActivities = Set(progress)
            }
        }
    }
    
    private func openInMaps(activity: Activity, location: String) {
        let query = "\(activity.name), \(location)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Try Google Maps first
        if let url = URL(string: "comgooglemaps://?q=\(query)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "http://maps.google.com/?q=\(query)") {
            UIApplication.shared.open(url)
        } else {
            // Fallback to Apple Maps
            let coordinate = CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
            let placemark = MKPlacemark(coordinate: coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = activity.name
            mapItem.openInMaps(launchOptions: nil)
        }
    }
}
