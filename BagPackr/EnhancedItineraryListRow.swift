//
//  EnhancedItineraryListRow.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

// MARK: - Enhanced Itinerary List Row
struct EnhancedItineraryListRow: View {
    let itinerary: Itinerary
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "airplane.departure")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(itinerary.location)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(
                        "\(itinerary.duration) \(String(localized: "Days"))",
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Label(
                        String(
                            localized: "$\(Int(itinerary.budgetPerDay * Double(itinerary.duration)))"
                        ),
                        systemImage: "dollarsign.circle"
                    )
                    .font(.caption)
                    .foregroundColor(.green)
                }
                
                // Interests Section
                FlexibleChipLayout(spacing: 6) {
                    ForEach(itinerary.interests.prefix(3), id: \.self) { interest in
                        Text(NSLocalizedString(interest, comment: "Interest category"))
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                    
                    if itinerary.interests.count > 3 {
                        Text("+\(itinerary.interests.count - 3)")
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
            
            if itinerary.isShared {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                    .font(.caption)
            }
            
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
