//
//  GoogleMapView.swift
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

struct GoogleMapView: UIViewRepresentable {
    @Binding var center: CLLocationCoordinate2D
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var placeName: String
    @Binding var isLocationLocked: Bool
    
    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: center.latitude, longitude: center.longitude, zoom: 2.0)
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.parent = self
        
        // Add/update marker for selected location
        if let coordinate = selectedCoordinate {
            mapView.clear()
            let marker = GMSMarker(position: coordinate)
            marker.icon = GMSMarker.markerImage(with: .systemBlue)
            marker.map = mapView
            
            // Animate to the selected location with appropriate zoom
            let camera = GMSCameraPosition.camera(withLatitude: coordinate.latitude, longitude: coordinate.longitude, zoom: 12.0)
            mapView.animate(to: camera)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        var marker: GMSMarker?
        
        init(_ parent: GoogleMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            // Don't allow map taps to override search selections
            guard !parent.isLocationLocked else { return }
            
            marker?.map = nil
            
            let newMarker = GMSMarker(position: coordinate)
            newMarker.icon = GMSMarker.markerImage(with: .systemBlue)
            newMarker.map = mapView
            marker = newMarker
            
            parent.selectedCoordinate = coordinate
            
            let geocoder = GMSGeocoder()
            geocoder.reverseGeocodeCoordinate(coordinate) { response, error in
                if let address = response?.firstResult() {
                    self.parent.placeName = address.locality ?? address.administrativeArea ?? "Selected Location"
                }
            }
        }
    }
}
