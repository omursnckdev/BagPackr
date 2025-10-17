//
//  PremiumUpgradeView.swift
//  BagPackr
//

import SwiftUI
import StoreKit

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeManager = StoreManager.shared
    @State private var selectedProduct: Product?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    headerSection
                    
                    // Features
                    featuresSection
                    
                    // Pricing
                    if storeManager.isLoading {
                        ProgressView()
                            .padding()
                    } else if storeManager.products.isEmpty {
                        Text("Loading products...")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        pricingSection
                    }
                    
                    // Subscribe button
                    subscribeButton
                    
                    // Restore purchases button
                    Button(action: handleRestore) {
                        Text("Restore Purchases")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .disabled(storeManager.isLoading)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("Start Planning!") {
                    dismiss()
                }
            } message: {
                Text("You're now a premium member! 🎉")
            }
        }
        .onAppear {
            Task {
                await storeManager.loadProducts()
                if !storeManager.products.isEmpty {
                    selectedProduct = storeManager.products.first
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
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
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
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
    }
    
    // MARK: - Pricing Section
    
    private var pricingSection: some View {
        VStack(spacing: 16) {
            ForEach(storeManager.products, id: \.id) { product in
                ProductCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    onSelect: { selectedProduct = product }
                )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Subscribe Button
    
    private var subscribeButton: some View {
        VStack(spacing: 16) {
            Button(action: handleSubscribe) {
                HStack {
                    if storeManager.isLoading {
                        ProgressView()
                            .tint(.white)
                        Text("Processing...")
                    } else {
                        Text("Start 7-Day Free Trial")
                    }
                }
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
            .disabled(storeManager.isLoading || selectedProduct == nil)
            .padding(.horizontal)
            
            if let product = selectedProduct {
                VStack(spacing: 8) {
                    Text("7 days free, then \(product.displayPrice)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("Cancel anytime")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleSubscribe() {
        guard let product = selectedProduct else { return }
        
        Task {
            do {
                let success = try await storeManager.purchase(product)
                
                if success {
                    showSuccess = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func handleRestore() {
        Task {
            do {
                try await storeManager.restorePurchases()
                showSuccess = true
            } catch StoreError.noPurchasesToRestore {
                errorMessage = "No previous purchases found"
                showError = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Product Card
struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var isYearly: Bool {
        product.subscription?.subscriptionPeriod.unit == .year
    }
    
    private var savings: String? {
        guard isYearly else { return nil }
        return "Save 50%"
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                if isYearly {
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
                        Text(product.displayName.replacingOccurrences(of: "BagPackr Premium ", with: ""))
                            .font(.headline)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(product.displayPrice)
                                .font(.title)
                                .fontWeight(.bold)
                            if let period = product.subscription?.subscriptionPeriod {
                                Text("/\(period.unit == .month ? "month" : "year")")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
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
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
            }
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isSelected ? Color.blue : (isYearly ? Color.orange : Color.gray.opacity(0.2)), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
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
