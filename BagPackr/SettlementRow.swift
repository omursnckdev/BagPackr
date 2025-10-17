//
//  SettlementRow.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

struct SettlementRow: View {
    let settlement: Settlement
    
    var fromName: String {
        settlement.from.components(separatedBy: "@").first ?? "Unknown"
    }
    
    var toName: String {
        settlement.to.components(separatedBy: "@").first ?? "Unknown"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(fromName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(toName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Text("Settlement payment")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("$\(String(format: "%.2f", settlement.amount))")
                .font(.headline)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}
