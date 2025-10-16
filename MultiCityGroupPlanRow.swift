//
//  MultiCityGroupPlanRow.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

struct MultiCityGroupPlanRow: View {
    let group: MultiCityGroupPlan
    
    var body: some View {
        HStack(spacing: 15) {
            // Icon
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
                
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(group.multiCityItinerary.cityNames)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Label(
                        "\(group.members.count) \(group.members.count == 1 ? "member" : "members")",
                        systemImage: "person.2"
                    )
                    .font(.caption)
                    .foregroundColor(.purple)
                    .padding(.trailing, 4)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Label(
                        "\(group.multiCityItinerary.citiesCount) cities",
                        systemImage: "mappin.and.ellipse"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Label(
                        "\(group.multiCityItinerary.totalDuration) days",
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
