//
//  BalanceRow.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

struct BalanceRow: View {
    let balance: Balance
    
    var name: String {
        balance.person.components(separatedBy: "@").first ?? "Unknown"
    }
    
    var isBalanced: Bool {
        abs(balance.amount) < 0.01
    }
    private var currencySymbol: String {
        Locale.current.language.languageCode?.identifier == "tr" ? "₺" : "$"
    }
    var body: some View {
        HStack {
            Text(name)
                .font(.subheadline)
            
            Spacer()
            
            if isBalanced {
                Text("Settled")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else if balance.amount > 0 {
                Text("gets back \(currencySymbol)\(String(format: "%.2f", balance.amount))")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else {
                Text("owes \(currencySymbol)\(String(format: "%.2f", abs(balance.amount)))")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }
}
