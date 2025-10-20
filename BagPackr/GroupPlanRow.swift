//
//  GroupPlanRow.swift
//  BagPackr
//

import SwiftUI

// MARK: - Group Plan Row Component
struct GroupPlanRow: View {
    let group: GroupPlan
    
    var body: some View {
        HStack(spacing: 15) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
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
                
                Text(group.itinerary.location)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label("\(group.members.count) members", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(group.itinerary.duration) days", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Interest chips
                if !group.itinerary.interests.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(group.itinerary.interests.prefix(3), id: \.self) { interest in
                                FlexibleChip(text: interest)
                            }
                            
                            if group.itinerary.interests.count > 3 {
                                Text("+\(group.itinerary.interests.count - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
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

// MARK: - Flexible Chip Component
struct FlexibleChip: View {
    let text: String
    var backgroundColor: Color = .blue.opacity(0.1)
    var textColor: Color = .blue
    
    var body: some View {
        Text(LocalizedStringKey(text))
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(backgroundColor)
            .cornerRadius(8)
            .lineLimit(1)
    }
}
