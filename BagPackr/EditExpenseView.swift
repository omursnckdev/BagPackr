//
//  EditExpenseView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

struct EditExpenseView: View {
    @Environment(\.dismiss) var dismiss
    let groupId: String
    let expense: GroupExpense
    let members: [GroupMember]
    let onExpenseUpdated: () -> Void
    
    @State private var description: String
    @State private var amount: String
    @State private var selectedCategory: ExpenseCategory
    @State private var isUpdating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(groupId: String, expense: GroupExpense, members: [GroupMember], onExpenseUpdated: @escaping () -> Void) {
        self.groupId = groupId
        self.expense = expense
        self.members = members
        self.onExpenseUpdated = onExpenseUpdated
        
        _description = State(initialValue: expense.description)
        _amount = State(initialValue: String(format: "%.2f", expense.amount))
        _selectedCategory = State(initialValue: expense.category)
    }
    
    var canUpdate: Bool {
        !description.isEmpty && !amount.isEmpty && Double(amount) != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Expense Details")) {
                    TextField("Description", text: $description)
                    
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                }
                
                Section {
                    Text("Paid by: \(expense.paidBy.components(separatedBy: "@").first ?? "Unknown")")
                        .foregroundColor(.secondary)
                    
                    Text("Split between: \(expense.splitBetween.count) members")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateExpense()
                    }
                    .disabled(!canUpdate || isUpdating)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func updateExpense() {
        guard let amountValue = Double(amount) else { return }
        
        isUpdating = true
        
        Task {
            do {
                try await FirestoreService.shared.updateExpense(
                    groupId: groupId,
                    expenseId: expense.id,
                    description: description,
                    amount: amountValue,
                    category: selectedCategory
                )
                onExpenseUpdated()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isUpdating = false
            }
        }
    }
}
