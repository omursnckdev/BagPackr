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
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack {
                    Label(activity.time, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Label(String(format: "%.1f km", activity.distance), systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if activity.cost > 0 {
                        Label("$\(Int(activity.cost))", systemImage: "dollarsign.circle")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    // Navigate Button
                    Button(action: onNavigate) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            Text("Navigate")
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
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
