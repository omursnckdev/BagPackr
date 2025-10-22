//
//  PremiumUpgradeView.swift - RevenueCat Version
//  BagPackr
//

import SwiftUI
import RevenueCat

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var revenueCat = RevenueCatManager.shared
    @State private var selectedPackage: Package?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var isPurchasing = false
    @State private var isRestoring = false
    
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
                    if revenueCat.currentOffering != nil {
                        subscribeButton
                    }
                    
                    // Restore purchases button
                    Button(action: handleRestore) {
                        HStack {
                            if isRestoring {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Restore Purchases")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .disabled(isPurchasing || isRestoring)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .disabled(isPurchasing)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success! 🎉", isPresented: $showSuccess) {
                Button("Start Planning!") {
                    dismiss()
                }
            } message: {
                Text("You're now a premium member!")
            }
        }
        .task {
            // Load offerings when view appears
            if revenueCat.currentOffering == nil {
                await revenueCat.fetchOfferings()
            }
            
            // Auto-select first package (usually monthly)
            if selectedPackage == nil {
                selectedPackage = revenueCat.currentOffering?.availablePackages.first
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
                description: "Create as many itineraries as you want",
                color: .blue
            )
            
            FeatureRow(
                icon: "xmark.circle",
                title: "Ad-Free",
                description: "Enjoy uninterrupted planning",
                color: .green
            )
            
            FeatureRow(
                icon: "map.fill",
                title: "Multi-City Planner",
                description: "Plan trips across multiple cities",
                color: .purple
            )
            
            FeatureRow(
                icon: "doc.text",
                title: "PDF Export",
                description: "Download and share your trips",
                color: .orange
            )
            
            FeatureRow(
                icon: "bolt.fill",
                title: "Priority Support",
                description: "Get help when you need it",
                color: .yellow
            )
            
            FeatureRow(
                icon: "sparkles",
                title: "Early Access",
                description: "Try new features first",
                color: .pink
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Products Section
    
    @ViewBuilder
    private var productsSection: some View {
        if revenueCat.currentOffering == nil {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading products...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if let offering = revenueCat.currentOffering {
            if offering.availablePackages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("No products available")
                        .font(.headline)
                    
                    Text("Please check your internet connection")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                pricingSection(packages: offering.availablePackages)
            }
        }
    }
    
    // MARK: - Pricing Section
    
    private func pricingSection(packages: [Package]) -> some View {
        VStack(spacing: 16) {
            ForEach(packages, id: \.identifier) { package in
                RevenueCatProductCard(
                    package: package,
                    isSelected: selectedPackage?.identifier == package.identifier,
                    onSelect: { selectedPackage = package }
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
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                        Text("Processing...")
                    } else {
                        Text("Start Premium")
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
            .disabled(isPurchasing || isRestoring || selectedPackage == nil)
            .padding(.horizontal)
            
            if let package = selectedPackage {
                VStack(spacing: 8) {
                    Text(package.storeProduct.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Text("Cancel anytime")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleSubscribe() {
        guard let package = selectedPackage else { return }
        
        isPurchasing = true
        
        Task {
            do {
                try await revenueCat.purchase(package: package)
                
                await MainActor.run {
                    isPurchasing = false
                    showSuccess = true
                }
                
            } catch PurchaseError.cancelled {
                await MainActor.run {
                    isPurchasing = false
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func handleRestore() {
        isRestoring = true
        
        Task {
            do {
                try await revenueCat.restorePurchases()
                
                await MainActor.run {
                    isRestoring = false
                    showSuccess = true
                }
                
            } catch PurchaseError.nothingToRestore {
                await MainActor.run {
                    isRestoring = false
                    errorMessage = "No previous purchases found"
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isRestoring = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - RevenueCat Product Card

struct RevenueCatProductCard: View {
    let package: Package
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var isYearly: Bool {
        package.packageType == .annual
    }
    
    private var savings: String? {
        guard isYearly else { return nil }
        return "Save 17%" // Veya hesaplayabilirsiniz
    }
    
    private var periodText: String {
        switch package.packageType {
        case .monthly:
            return "/month"
        case .annual:
            return "/year"
        case .weekly:
            return "/week"
        case .lifetime:
            return "one-time"
        default:
            return ""
        }
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
                        Text(package.storeProduct.localizedTitle)
                            .font(.headline)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(package.localizedPriceString)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(periodText)
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
    let description: String?
    let color: Color
    
    // Convenience initializer - eski kullanım için
    init(icon: String, text: String) {
        self.icon = icon
        self.title = text
        self.description = nil
        self.color = .yellow
    }
    
    // Full initializer - yeni kullanım için
    init(icon: String, title: String, description: String, color: Color) {
        self.icon = icon
        self.title = title
        self.description = description
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(description != nil ? .title2 : .title3)
                .foregroundColor(color)
                .frame(width: description != nil ? 40 : 30, height: description != nil ? 40 : 30)
                .background(description != nil ? color.opacity(0.1) : Color.clear)
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(description != nil ? .headline : .body)
                    .foregroundColor(description != nil ? .primary : .white)
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
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
