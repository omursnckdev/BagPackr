//
//  AddCityStopView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

struct AddCityStopView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedLocation: LocationData?
    @State private var duration: Int = 3
    @State private var showMapPicker = false
    
    let onAdd: (CityStop) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Location picker
                    ModernCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("City", systemImage: "mappin.circle.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Button(action: { showMapPicker = true }) {
                                HStack {
                                    Text(selectedLocation?.name ?? "Select City")
                                        .foregroundColor(selectedLocation == nil ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.blue)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                    
                    // Duration picker
                    ModernCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Duration", systemImage: "calendar")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            HStack {
                                Text("\(duration)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.blue)
                                
                                Text("days")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                VStack(spacing: 8) {
                                    Button(action: { duration = min(14, duration + 1) }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Button(action: { duration = max(1, duration - 1) }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Add button
                    Button(action: handleAdd) {
                        Text("Add City")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: selectedLocation != nil ? [.blue, .purple] : [.gray, .gray],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                    .disabled(selectedLocation == nil)
                }
                .padding()
            }
            .navigationTitle("Add City Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showMapPicker) {
                MapPickerView(selectedLocation: $selectedLocation)
            }
        }
    }
    
    private func handleAdd() {
        guard let location = selectedLocation else { return }
        
        let cityStop = CityStop(location: location, duration: duration)
        onAdd(cityStop)
        dismiss()
    }
}
