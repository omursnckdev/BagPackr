//
//  PremiumPaywallView.swift
//  BagPackr
//
//  Created by Ömür Şenocak
//

import SwiftUI
import RevenueCat

struct PremiumPaywallView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var revenueCat = RevenueCatManager.shared
    
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient Background
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.yellow)
                            
                            Text("Upgrade to Premium")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("Unlimited Travel Planning")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .foregroundColor(.white)
                        .padding(.top, 40)
                        
                        // Features
                        VStack(spacing: 20) {
                            FeatureRow(icon: "infinity", text: "Unlimited Itineraries")
                            FeatureRow(icon: "map.fill", text: "Unlimited Multi-City Plans")
                            FeatureRow(icon: "wand.and.stars", text: "Priority AI Generation")
                            FeatureRow(icon: "bell.slash.fill", text: "Ad-Free Experience")
                            FeatureRow(icon: "doc.richtext.fill", text: "Export Itineraries as PDF")
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.white.opacity(0.15))
                        )
                        .padding(.horizontal)
                        
                        // Packages
                        if let offering = revenueCat.currentOffering {
                            VStack(spacing: 16) {
                                ForEach(offering.availablePackages, id: \.identifier) { package in
                                    PackageButton(
                                        package: package,
                                        isSelected: selectedPackage?.identifier == package.identifier
                                    ) {
                                        selectedPackage = package
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            ProgressView()
                                .tint(.white)
                        }
                        
                        // Purchase Button
                        Button(action: purchaseSelected) {
                            Group {
                                if isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(purchaseButtonText)
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .foregroundColor(.blue)
                            .cornerRadius(16)
                        }
                        .disabled(selectedPackage == nil || isPurchasing)
                        .padding(.horizontal)
                        
                        // Restore Button
                        Button("Restore Purchases") {
                            restorePurchases()
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .font(.footnote)
                        
                        // Terms
                        Text(termsText)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Success! 🎉", isPresented: $showSuccess) {
                Button("Continue") {
                    dismiss()
                }
            } message: {
                Text("Welcome to BagPackr Premium!")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
        .task {
            if revenueCat.currentOffering == nil {
                await revenueCat.fetchOfferings()
            }
            
            // 🔍 DEBUG - Geçici ekle
            if let offering = revenueCat.currentOffering {
                print("🔍 PremiumPaywallView - Total packages: \(offering.availablePackages.count)")
                for (index, package) in offering.availablePackages.enumerated() {
                    print("🔍 Package \(index + 1):")
                    print("   Identifier: \(package.identifier)")
                    print("   Product ID: \(package.storeProduct.productIdentifier)")
                    print("   Title: \(package.storeProduct.localizedTitle)")
                    print("   Price: \(package.localizedPriceString)")
                    print("   Type: \(package.packageType)")
                    
                    // Check for trial
                    if let intro = package.storeProduct.introductoryDiscount {
                        print("   🎁 Has Trial: \(intro.subscriptionPeriod.value) \(intro.subscriptionPeriod.unit)")
                    }
                }
            } else {
                print("❌ No offering found!")
            }
            
            // Pre-select first package
            selectedPackage = revenueCat.currentOffering?.availablePackages.first
        }
    }
    
    // MARK: - Computed Properties
    
    private var purchaseButtonText: String {
        guard let package = selectedPackage,
              let introDiscount = package.storeProduct.introductoryDiscount,
              introDiscount.price == 0 else {
            return "Start Premium"
        }
        
        return "Start Free Trial"
    }
    
    private var termsText: String {
        if let package = selectedPackage,
           let introDiscount = package.storeProduct.introductoryDiscount,
           introDiscount.price == 0 {
            let period = introDiscount.subscriptionPeriod
            let value = period.value
            let unit: String = {
                switch period.unit {
                case .day: return value == 1 ? "day" : "days"
                case .week: return value == 1 ? "week" : "weeks"
                case .month: return value == 1 ? "month" : "months"
                case .year: return value == 1 ? "year" : "years"
                @unknown default: return "days"
                }
            }()
            
            return "Free for \(value) \(unit), then auto-renews at \(package.localizedPriceString). Cancel anytime."
        }
        return "Auto-renewable. Cancel anytime."
    }
    
    // MARK: - Actions
    
    func purchaseSelected() {
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
    
    func restorePurchases() {
        isPurchasing = true
        
        Task {
            do {
                try await revenueCat.restorePurchases()
                
                await MainActor.run {
                    isPurchasing = false
                    showSuccess = true
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
}



// MARK: - Package Button
struct PackageButton: View {
    let package: Package
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    // Show trial badge if available
                    if let trialInfo = getTrialInfo() {
                        Text("🎁 \(trialInfo) FREE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(isSelected ? .green : .yellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.green.opacity(0.2) : Color.yellow.opacity(0.2))
                            )
                    }
                    
                    Text(package.storeProduct.localizedTitle)
                        .font(.headline)
                        .foregroundColor(isSelected ? .blue : .white)
                    
                    // Show "then price" for trials, otherwise description
                    if getTrialInfo() != nil {
                        Text("Then \(package.localizedPriceString)")
                            .font(.subheadline)
                            .foregroundColor(isSelected ? .blue.opacity(0.8) : .white.opacity(0.7))
                    } else {
                        Text(package.storeProduct.localizedDescription)
                            .font(.caption)
                            .foregroundColor(isSelected ? .blue.opacity(0.8) : .white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if getTrialInfo() != nil {
                        Text("FREE")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(isSelected ? .green : .yellow)
                        
                        Text("7 days")
                            .font(.caption2)
                            .foregroundColor(isSelected ? .green.opacity(0.8) : .yellow.opacity(0.8))
                    } else {
                        Text(package.localizedPriceString)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(isSelected ? .blue : .white)
                    }
                    
                    if package.packageType == .annual {
                        Text("Best Value!")
                            .font(.caption2)
                            .foregroundColor(isSelected ? .blue : .yellow)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
            )
        }
    }
    
    // MARK: - Helper
    
    private func getTrialInfo() -> String? {
        guard let introDiscount = package.storeProduct.introductoryDiscount,
              introDiscount.price == 0 else {
            return nil
        }
        
        let period = introDiscount.subscriptionPeriod
        let value = period.value
        let unit: String = {
            switch period.unit {
            case .day: return value == 1 ? "Day" : "Days"
            case .week: return value == 1 ? "Week" : "Weeks"
            case .month: return value == 1 ? "Month" : "Months"
            case .year: return value == 1 ? "Year" : "Years"
            @unknown default: return "Days"
            }
        }()
        
        return "\(value) \(unit)"
    }
}
