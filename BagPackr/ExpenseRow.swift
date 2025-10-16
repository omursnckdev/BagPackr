//
//  ExpenseRow.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

struct ExpenseRow: View {
    let expense: GroupExpense
    let members: [GroupMember]
    let onDelete: () -> Void
    @State private var isDeleting = false
    
    var paidByName: String {
        expense.paidBy.components(separatedBy: "@").first ?? "Unknown"
    }
    
    var splitInfo: String {
        if expense.splitBetween.count == members.count {
            return "Split equally"
        } else {
            return "Split \(expense.splitBetween.count) ways"
        }
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(expense.category.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: expense.category.icon)
                        .foregroundColor(expense.category.color)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.description)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(paidByName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(splitInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(expense.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("$\(String(format: "%.2f", expense.amount))")
                    .font(.headline)
                    .foregroundColor(expense.category.color)
                    .padding(.trailing, 30)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(15)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .opacity(isDeleting ? 0.5 : 1.0)
            .scaleEffect(isDeleting ? 0.95 : 1.0)
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isDeleting = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onDelete()
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.red)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                    )
            }
            .offset(x: -8, y: 8)
            .scaleEffect(isDeleting ? 0.8 : 1.0)
        }
    }
}
