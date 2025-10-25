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
                                    Text("Start Premium")
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
                        Text("Auto-renewable. Cancel anytime.")
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
                Text("Welcome to BagPckr Premium!")
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
                }
            } else {
                print("❌ No offering found!")
            }
            
            // Pre-select first package
            selectedPackage = revenueCat.currentOffering?.availablePackages.first
        }
    }
    
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

// MARK: - Feature Row


// MARK: - Package Button
struct PackageButton: View {
    let package: Package
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.headline)
                        .foregroundColor(isSelected ? .blue : .white)
                    
                    Text(package.storeProduct.localizedDescription)
                        .font(.caption)
                        .foregroundColor(isSelected ? .blue.opacity(0.8) : .white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(package.localizedPriceString)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .blue : .white)
                    
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
}
