//
//  PremiumPaywallView.swift
//  BagPackr
//

import SwiftUI
import StoreKit

struct PremiumPaywallView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var planLimitService = PlanLimitService.shared
    @StateObject private var storeManager = StoreManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange.opacity(0.2), .pink.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        Text("Upgrade to Premium")
                            .font(.system(size: 32, weight: .bold))
                        
                        Text("Unlimited plans and features")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 20) {
                        FeatureRow(
                            icon: "infinity",
                            title: "Unlimited Plans",
                            description: "Create as many itineraries as you want",
                            color: .blue
                        )
                        
                        FeatureRow(
                            icon: "wand.and.stars",
                            title: "Unlimited AI",
                            description: "Generate perfect plans without limits",
                            color: .purple
                        )
                        
                        FeatureRow(
                            icon: "rectangle.slash",
                            title: "Ad-Free",
                            description: "Enjoy a clean, distraction-free experience",
                            color: .green
                        )
                        
                        FeatureRow(
                            icon: "sparkles",
                            title: "Premium Features",
                            description: "Access all future premium features",
                            color: .orange
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // Pricing
                    VStack(spacing: 16) {
                        if storeManager.products.isEmpty {
                            ProgressView()
                                .padding()
                        } else {
                            ForEach(storeManager.products) { product in
                                PricingCard(product: product) {
                                    Task {
                                        await purchasePremium(product)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Social proof
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            ForEach(0..<5) { _ in
                                Image(systemName: "star.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        }
                        
                        Text("Loved by 1000+ travelers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Fine print
                    VStack(spacing: 4) {
                        Text("7-day free trial, then auto-renews")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("Cancel anytime from App Store settings")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
        .task {
            await storeManager.loadProducts()
        }
    }
    
    func purchasePremium(_ product: Product) async {
        do {
            try await storeManager.purchase(product)
            
            // Upgrade user
            try await planLimitService.upgradeToPremium()
            
            // Dismiss paywall
            dismiss()
            
            print("✅ Premium purchase successful!")
            
        } catch {
            print("❌ Purchase failed: \(error)")
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Pricing Card

struct PricingCard: View {
    let product: Product
    let action: () -> Void
    
    var isYearly: Bool {
        product.subscription?.subscriptionPeriod.unit == .year
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Badge
                if isYearly {
                    HStack {
                        Spacer()
                        Text("BEST VALUE 🔥")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                }
                
                // Content
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(product.displayName)
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                        
                        if isYearly {
                            Text("Save 44%")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(product.displayPrice)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        
                        if isYearly {
                            Text("₺83/month")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(
                color: isYearly ? Color.orange.opacity(0.3) : Color.black.opacity(0.1),
                radius: isYearly ? 12 : 8,
                x: 0,
                y: 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isYearly ? LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: isYearly ? 2 : 0
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PremiumPaywallView()
}
