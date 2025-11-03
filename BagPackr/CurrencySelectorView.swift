//
//  CurrencySelectorView.swift
//  BagPackr
//

import SwiftUI

struct CurrencySelectorView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var currencyManager = CurrencyManager.shared
    @Binding var selectedCurrency: Currency
    @State private var searchText = ""
    
    var filteredCurrencies: [Currency] {
        if searchText.isEmpty {
            return currencyManager.availableCurrencies
        }
        return currencyManager.availableCurrencies.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredCurrencies, id: \.self) { currency in
                    Button(action: {
                        selectedCurrency = currency
                        currencyManager.selectCurrency(currency)
                        dismiss()
                    }) {
                        HStack {
                            Text(currency.flag)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currency.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text(currency.code)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(currency.symbol)
                                .font(.title3)
                                .foregroundColor(.secondary)
                            
                            if currency == selectedCurrency {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search currency")
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
