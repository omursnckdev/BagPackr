//
//  ExpensesTabView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

struct ExpensesTabView: View {
    let groupId: String
    @Binding var expenses: [GroupExpense]
    let members: [GroupMember]
    @State private var showError = false
    @State private var errorMessage = ""
    
    var totalExpenses: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var expensesByCategory: [(category: ExpenseCategory, amount: Double)] {
        Dictionary(grouping: expenses, by: { $0.category })
            .map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ModernCard {
                    VStack(spacing: 15) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Expenses")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("$\(String(format: "%.2f", totalExpenses))")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("\(expenses.count)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("transactions")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        if !expensesByCategory.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("By Category")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                ForEach(expensesByCategory, id: \.category) { item in
                                    HStack {
                                        Image(systemName: item.category.icon)
                                            .foregroundColor(item.category.color)
                                            .frame(width: 25)
                                        
                                        Text(item.category.rawValue)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        Text("$\(String(format: "%.2f", item.amount))")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(item.category.color)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                if expenses.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No expenses yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Add your first expense to start tracking")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .transition(.opacity.combined(with: .scale))
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(expenses) { expense in
                            ExpenseRow(
                                expense: expense,
                                members: members,
                                onDelete: { deleteExpense(expense) }
                            )
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func deleteExpense(_ expense: GroupExpense) {
        Task {
            do {
                // Animate the removal
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    expenses.removeAll { $0.id == expense.id }
                }
                
                // Delete from Firestore
                try await FirestoreService.shared.deleteExpense(groupId: groupId, expenseId: expense.id)
            } catch {
                // If deletion fails, restore the expense
                withAnimation {
                    if let deletedExpense = expense as? GroupExpense {
                        expenses.append(deletedExpense)
                        expenses.sort { $0.date > $1.date }
                    }
                }
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
