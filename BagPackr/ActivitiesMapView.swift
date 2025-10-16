//
//  ActivitiesMapView.swift
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

// Fixed ActivitiesMapView with proper marker display
struct ActivitiesMapView: UIViewRepresentable {
    let activities: [Activity]
    let location: String
    
    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: 0, longitude: 0, zoom: 12.0)
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        context.coordinator.mapView = mapView
        context.coordinator.geocodeAndPlaceMarkers()
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Update coordinator references
        context.coordinator.activities = activities
        context.coordinator.location = location
        context.coordinator.mapView = mapView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(activities: activities, location: location)
    }
    
    class Coordinator: NSObject {
        var activities: [Activity]
        var location: String
        var mapView: GMSMapView?
        
        init(activities: [Activity], location: String) {
            self.activities = activities
            self.location = location
        }
        
        func geocodeAndPlaceMarkers() {
            guard let mapView = mapView else { return }
            
            let placesClient = GMSPlacesClient.shared()
            var bounds = GMSCoordinateBounds()
            var markersPlaced = 0
            
            // First, get the city location to center the map
            placesClient.findAutocompletePredictions(fromQuery: location, filter: nil, sessionToken: nil) { predictions, error in
                if let cityPrediction = predictions?.first {
                    placesClient.fetchPlace(fromPlaceID: cityPrediction.placeID, placeFields: .coordinate, sessionToken: nil) { cityPlace, _ in
                        if let cityCoordinate = cityPlace?.coordinate {
                            // Now geocode each activity
                            for (index, activity) in self.activities.enumerated() {
                                let searchQuery = "\(activity.name), \(self.location)"
                                
                                placesClient.findAutocompletePredictions(fromQuery: searchQuery, filter: nil, sessionToken: nil) { predictions, error in
                                    if let prediction = predictions?.first {
                                        placesClient.fetchPlace(fromPlaceID: prediction.placeID, placeFields: .coordinate, sessionToken: nil) { place, error in
                                            if let coordinate = place?.coordinate {
                                                DispatchQueue.main.async {
                                                    self.addMarker(
                                                        at: coordinate,
                                                        for: activity,
                                                        number: index + 1,
                                                        to: mapView,
                                                        bounds: &bounds
                                                    )
                                                    markersPlaced += 1
                                                    
                                                    if markersPlaced == self.activities.count {
                                                        self.updateCamera(mapView: mapView, bounds: bounds)
                                                    }
                                                }
                                            } else {
                                                // Fallback: place marker near city center with offset
                                                DispatchQueue.main.async {
                                                    let offset = Double(index) * 0.01
                                                    let fallbackCoordinate = CLLocationCoordinate2D(
                                                        latitude: cityCoordinate.latitude + offset,
                                                        longitude: cityCoordinate.longitude + offset
                                                    )
                                                    self.addMarker(
                                                        at: fallbackCoordinate,
                                                        for: activity,
                                                        number: index + 1,
                                                        to: mapView,
                                                        bounds: &bounds
                                                    )
                                                    markersPlaced += 1
                                                    
                                                    if markersPlaced == self.activities.count {
                                                        self.updateCamera(mapView: mapView, bounds: bounds)
                                                    }
                                                }
                                            }
                                        }
                                    } else {
                                        // Fallback if no predictions
                                        DispatchQueue.main.async {
                                            let offset = Double(index) * 0.01
                                            let fallbackCoordinate = CLLocationCoordinate2D(
                                                latitude: cityCoordinate.latitude + offset,
                                                longitude: cityCoordinate.longitude + offset
                                            )
                                            self.addMarker(
                                                at: fallbackCoordinate,
                                                for: activity,
                                                number: index + 1,
                                                to: mapView,
                                                bounds: &bounds
                                            )
                                            markersPlaced += 1
                                            
                                            if markersPlaced == self.activities.count {
                                                self.updateCamera(mapView: mapView, bounds: bounds)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        private func addMarker(at coordinate: CLLocationCoordinate2D, for activity: Activity, number: Int, to mapView: GMSMapView, bounds: inout GMSCoordinateBounds) {
            let marker = GMSMarker()
            marker.position = coordinate
            marker.title = activity.name
            marker.snippet = "\(activity.time) • $\(Int(activity.cost))"
            marker.icon = markerIcon(for: number, type: activity.type)
            marker.map = mapView
            bounds = bounds.includingCoordinate(coordinate)
        }
        
        private func updateCamera(mapView: GMSMapView, bounds: GMSCoordinateBounds) {
            let update = GMSCameraUpdate.fit(bounds, withPadding: 50)
            mapView.animate(with: update)
        }
        
        private func markerIcon(for number: Int, type: String) -> UIImage {
            let size = CGSize(width: 40, height: 40)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                let color = colorForActivityType(type)
                color.setFill()
                
                let circle = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
                circle.fill()
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 18),
                    .foregroundColor: UIColor.white
                ]
                
                let text = "\(number)"
                let textSize = text.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                
                text.draw(in: textRect, withAttributes: attributes)
            }
        }
        
        private func colorForActivityType(_ type: String) -> UIColor {
            switch type.lowercased() {
            case "beach", "beaches": return .systemCyan
            case "nightlife": return .systemPurple
            case "restaurant", "restaurants": return .systemOrange
            case "museum", "museums": return .systemBrown
            default: return .systemBlue
            }
        }
    }
}
