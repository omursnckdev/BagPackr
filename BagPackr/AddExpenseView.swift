//
//  AddExpenseView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI
import FirebaseCore
import GoogleMaps
import GooglePlaces
import MapKit
import Combine
import GoogleMobileAds
import FirebaseMessaging
import UserNotifications

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    let groupId: String
    let members: [GroupMember]
    let onExpenseAdded: () -> Void
    
    @State private var description = ""
    @State private var amount = ""
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var paidBy: String = ""
    @State private var splitBetween: Set<String> = []
    @State private var isAdding = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var canAdd: Bool {
        !description.isEmpty &&
        !amount.isEmpty &&
        Double(amount) != nil &&
        !paidBy.isEmpty &&
        !splitBetween.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Expense Details")) {
                    TextField("Description", text: $description)
                        .submitLabel(.done)
                    
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    Picker(String(localized: "Category"), selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.localizedName) // ✅ works with LocalizedStringKey
                            }
                            .tag(category)
                        }
                    }
                    
                    
                }
                
                Section(header: Text("Paid By")) {
                    Picker("Select member", selection: $paidBy) {
                        Text("Select...").tag("")
                        ForEach(members, id: \.email) { member in
                            Text(member.email.components(separatedBy: "@").first ?? member.email)
                                .tag(member.email)
                        }
                    }
                }
                
                Section(header: Text("Split Between")) {
                    Button(action: toggleAllMembers) {
                        HStack {
                            Text(splitBetween.count == members.count ? "Deselect All" : "Select All")
                            Spacer()
                            Text("\(splitBetween.count)/\(members.count)")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    ForEach(members, id: \.email) { member in
                        Button(action: { toggleMember(member.email) }) {
                            HStack {
                                Text(member.email.components(separatedBy: "@").first ?? member.email)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if splitBetween.contains(member.email) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.purple)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                
                if !splitBetween.isEmpty, let amountValue = Double(amount) {
                    Section(header: Text("Split Details")) {
                        let perPerson = amountValue / Double(splitBetween.count)
                        Text("$\(String(format: "%.2f", perPerson)) per person")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addExpense()
                    }
                    .disabled(!canAdd || isAdding)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func toggleAllMembers() {
        if splitBetween.count == members.count {
            splitBetween.removeAll()
        } else {
            splitBetween = Set(members.map { $0.email })
        }
    }
    
    private func toggleMember(_ email: String) {
        if splitBetween.contains(email) {
            splitBetween.remove(email)
        } else {
            splitBetween.insert(email)
        }
    }
    
    private func addExpense() {
        guard let amountValue = Double(amount) else { return }
        
        isAdding = true
        
        let expense = GroupExpense(
            groupId: groupId,
            description: description,
            amount: amountValue,
            paidBy: paidBy,
            splitBetween: Array(splitBetween),
            category: selectedCategory
        )
        
        Task {
            do {
                try await FirestoreService.shared.addExpenseToGroup(expense: expense)
                onExpenseAdded()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isAdding = false
            }
        }
    }
}
