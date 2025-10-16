//
//  MultiCityItineraryCard.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

// MARK: - Multi-City Itinerary Card
struct MultiCityItineraryCard: View {
    let multiCity: MultiCityItinerary
    
    var body: some View {
        HStack(spacing: 15) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.6), .blue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(multiCity.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(multiCity.cityNames)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(
                        "\(multiCity.citiesCount) cities",
                        systemImage: "mappin.and.ellipse"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Label(
                        "\(multiCity.totalDuration) days",
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Label(
                        "$\(Int(multiCity.totalBudget))",
                        systemImage: "dollarsign.circle"
                    )
                    .font(.caption)
                    .foregroundColor(.green)
                }
                
                // Interests chips
                FlexibleChipLayout(spacing: 6) {
                    ForEach(multiCity.interests.prefix(3), id: \.self) { interest in
                        Text(NSLocalizedString(interest, comment: "Interest category"))
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                    
                    if multiCity.interests.count > 3 {
                        Text("+\(multiCity.interests.count - 3)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
