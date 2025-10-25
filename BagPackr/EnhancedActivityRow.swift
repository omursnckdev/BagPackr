//
//  EnhancedActivityRow.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

// MARK: - Enhanced Activity Row with Checklist & Navigation
struct EnhancedActivityRow: View {
    let activity: Activity
    let number: Int
    let isCompleted: Bool
    let onToggleComplete: () -> Void
    let onNavigate: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: onToggleComplete) {
                ZStack {
                    Circle()
                        .strokeBorder(isCompleted ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Number Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                colorForType(activity.type).opacity(isCompleted ? 0.4 : 0.8),
                                colorForType(activity.type).opacity(isCompleted ? 0.3 : 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Text("\(number)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(activity.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .strikethrough(isCompleted)
                    .foregroundColor(isCompleted ? .gray : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Image(systemName: iconForType(activity.type))
                        .foregroundColor(colorForType(activity.type))
                        .font(.caption)
                    
                    Text(activity.type)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                
                Text(activity.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Info badges with proper spacing
                HStack(spacing: 8) {
                    InfoBadge(
                        icon: "clock",
                        text: activity.time,
                        color: .blue
                    )
                    
                    InfoBadge(
                        icon: "location",
                        text: String(format: "%.1f km", activity.distance),
                        color: .gray
                    )
                    
                    if activity.cost > 0 {
                        InfoBadge(
                            icon: "dollarsign.circle",
                            text: "$\(Int(activity.cost))",
                            color: .green
                        )
                    }
                }
                
                // Navigate Button - separate row with flexible text
                Button(action: onNavigate) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.caption)
                        Text(NSLocalizedString("Navigate", comment: "Navigate button"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minWidth: 110)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .opacity(isCompleted ? 0.6 : 1.0)
    }
    
    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "beach", "beaches": return "beach.umbrella.fill"
        case "nightlife": return "moon.stars.fill"
        case "restaurant", "restaurants": return "fork.knife"
        case "museum", "museums": return "building.columns.fill"
        case "temple": return "building.fill"
        default: return "mappin.circle.fill"
        }
    }
    
    private func colorForType(_ type: String) -> Color {
        switch type.lowercased() {
        case "beach", "beaches": return .cyan
        case "nightlife": return .purple
        case "restaurant", "restaurants": return .orange
        case "museum", "museums": return .brown
        default: return .blue
        }
    }
}

// MARK: - Info Badge Component

struct InfoBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .cornerRadius(8)
    }
}
