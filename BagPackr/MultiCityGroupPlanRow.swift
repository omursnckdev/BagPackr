//
//  MultiCityGroupPlanRow.swift
//  BagPackr
//

import SwiftUI

struct MultiCityGroupPlanRow: View {
    let group: MultiCityGroupPlan
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .cyan.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(group.multiCityItinerary.cityNames)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label("\(group.members.count) members", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(group.multiCityItinerary.citiesCount) cities", systemImage: "map")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(group.multiCityItinerary.totalDuration) days", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
