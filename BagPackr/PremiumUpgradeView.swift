//
//  PremiumUpgradeView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

// Views/PremiumUpgradeView.swift
import SwiftUI

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var limitService = PlanLimitService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow.opacity(0.3), radius: 10)
                        
                        Text("Upgrade to Premium")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Unlock unlimited travel planning")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 30)
                    
                    // Features
                    VStack(spacing: 20) {
                        FeatureRow(
                            icon: "infinity",
                            title: "Unlimited Plans",
                            description: "Create as many itineraries as you want"
                        )
                        
                        FeatureRow(
                            icon: "xmark.circle",
                            title: "Ad-Free",
                            description: "Enjoy uninterrupted planning"
                        )
                        
                        FeatureRow(
                            icon: "map.fill",
                            title: "Multi-City Planner",
                            description: "Plan trips across multiple cities"
                        )
                        
                        FeatureRow(
                            icon: "doc.text",
                            title: "PDF Export",
                            description: "Download and share your trips"
                        )
                        
                        FeatureRow(
                            icon: "bolt.fill",
                            title: "Priority Support",
                            description: "Get help when you need it"
                        )
                        
                        FeatureRow(
                            icon: "sparkles",
                            title: "Early Access",
                            description: "Try new features first"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Pricing
                    VStack(spacing: 16) {
                        PricingCard(
                            title: "Monthly",
                            price: "$4.99",
                            period: "/month",
                            isPopular: false
                        )
                        
                        PricingCard(
                            title: "Yearly",
                            price: "$29.99",
                            period: "/year",
                            savings: "Save 50%",
                            isPopular: true
                        )
                    }
                    .padding(.horizontal)
                    
                    // Subscribe button
                    Button(action: handleSubscribe) {
                        Text("Start 7-Day Free Trial")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .shadow(color: .orange.opacity(0.3), radius: 10)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        Text("7 days free, then $4.99/month")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("Cancel anytime")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    // Restore purchases button
                    Button(action: handleRestore) {
                        Text("Restore Purchases")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func handleSubscribe() {
        // TODO: Implement StoreKit subscription
        // For now, just upgrade locally for testing
        Task {
            do {
                try await limitService.upgradeToPremium()
                dismiss()
            } catch {
                print("❌ Error upgrading: \(error)")
            }
        }
    }
    
    private func handleRestore() {
        // TODO: Implement StoreKit restore
        print("Restore purchases tapped")
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

// MARK: - Pricing Card
struct PricingCard: View {
    let title: String
    let price: String
    let period: String
    var savings: String?
    let isPopular: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if isPopular {
                Text("MOST POPULAR")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15, corners: [.topLeft, .topRight])
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(price)
                            .font(.title)
                            .fontWeight(.bold)
                        Text(period)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                if let savings = savings {
                    Text(savings)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
        }
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(isPopular ? Color.orange : Color.gray.opacity(0.2), lineWidth: 2)
        )
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
