//
//  PremiumUpgradeView.swift - FIXED
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
    @State private var loadAttempts = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    headerSection
                    
                    // Features
                    featuresSection
                    
                    // Pricing
                    productsSection
                    
                    // Subscribe button
                    if !storeManager.products.isEmpty {
                        subscribeButton
                    }
                    
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
                Button("Retry") {
                    Task {
                        await loadProductsWithRetry()
                    }
                }
                Button("Cancel", role: .cancel) { }
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
                await loadProductsWithRetry()
            }
        }
    }
    
    // MARK: - Products Section with Better Error Handling
    
    @ViewBuilder
    private var productsSection: some View {
        if storeManager.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading products...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if storeManager.products.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                Text("Unable to load products")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Please check your internet connection and try again")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    Task {
                        await loadProductsWithRetry()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            pricingSection
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
                description: "Create as many itineraries as you want",
                color: .blue  // ⭐ Added
            )
            
            FeatureRow(
                icon: "xmark.circle",
                title: "Ad-Free",
                description: "Enjoy uninterrupted planning",
                color: .green  // ⭐ Added
            )
            
            FeatureRow(
                icon: "map.fill",
                title: "Multi-City Planner",
                description: "Plan trips across multiple cities",
                color: .purple  // ⭐ Added
            )
            
            FeatureRow(
                icon: "doc.text",
                title: "PDF Export",
                description: "Download and share your trips",
                color: .orange  // ⭐ Added
            )
            
            FeatureRow(
                icon: "bolt.fill",
                title: "Priority Support",
                description: "Get help when you need it",
                color: .yellow  // ⭐ Added
            )
            
            FeatureRow(
                icon: "sparkles",
                title: "Early Access",
                description: "Try new features first",
                color: .pink  // ⭐ Added
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
    
    private func loadProductsWithRetry() async {
        loadAttempts += 1
        
        do {
            await storeManager.loadProducts()
            
            if !storeManager.products.isEmpty {
                selectedProduct = storeManager.products.first
                loadAttempts = 0
            } else if loadAttempts < 3 {
                // Retry after a delay if products are empty
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await loadProductsWithRetry()
            } else {
                // Show error after 3 attempts
                errorMessage = "Could not load products. Please check:\n• Internet connection\n• App Store Connect configuration\n• Try again later"
                showError = true
                loadAttempts = 0
            }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            showError = true
            loadAttempts = 0
        }
    }
    
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
