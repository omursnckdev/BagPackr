//
//  BalancesTabView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

struct BalancesTabView: View {
    let expenses: [GroupExpense]
    let members: [GroupMember]
    
    var balances: [Balance] {
        calculateBalances()
    }
    
    var settlements: [Settlement] {
        calculateSettlements()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ModernCard {
                    VStack(alignment: .leading, spacing: 15) {
                        Label("Member Balances", systemImage: "person.2.fill")
                            .font(.headline)
                            .foregroundColor(.purple)
                        
                        if balances.isEmpty {
                            Text("No expenses to calculate")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(balances, id: \.person) { balance in
                                BalanceRow(balance: balance)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                if !settlements.isEmpty {
                    ModernCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Label("Settle Up", systemImage: "arrow.left.arrow.right")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            ForEach(settlements.indices, id: \.self) { index in
                                SettlementRow(settlement: settlements[index])
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private func calculateBalances() -> [Balance] {
        var balanceMap: [String: Double] = [:]
        
        for member in members {
            balanceMap[member.email] = 0
        }
        
        for expense in expenses {
            let shareAmount = expense.amount / Double(expense.splitBetween.count)
            balanceMap[expense.paidBy, default: 0] += expense.amount
            
            for person in expense.splitBetween {
                balanceMap[person, default: 0] -= shareAmount
            }
        }
        
        return balanceMap.map { Balance(person: $0.key, amount: $0.value) }
            .sorted { abs($0.amount) > abs($1.amount) }
    }
    private func calculateSettlements() -> [Settlement] {
        // Step 1: Build creditors and debtors separately
        var creditors: [(person: String, amount: Double)] = balances
            .filter { $0.amount > 0.01 }
            .map { (person: $0.person, amount: $0.amount) }
        
        var debtors: [(person: String, amount: Double)] = balances
            .filter { $0.amount < -0.01 }
            .map { (person: $0.person, amount: abs($0.amount)) }
        
        // Step 2: Sort deterministically
        creditors.sort {
            if abs($0.amount - $1.amount) < 0.01 {
                return $0.person < $1.person
            }
            return $0.amount > $1.amount
        }
        
        debtors.sort {
            if abs($0.amount - $1.amount) < 0.01 {
                return $0.person < $1.person
            }
            return $0.amount > $1.amount
        }
        
        // Step 3: Match creditors and debtors greedily
        var settlements: [Settlement] = []
        var i = 0, j = 0
        
        while i < creditors.count && j < debtors.count {
            let amountToSettle = min(creditors[i].amount, debtors[j].amount)
            
            settlements.append(Settlement(
                from: debtors[j].person,
                to: creditors[i].person,
                amount: amountToSettle
            ))
            
            creditors[i].amount -= amountToSettle
            debtors[j].amount -= amountToSettle
            
            if creditors[i].amount < 0.01 { i += 1 }
            if debtors[j].amount < 0.01 { j += 1 }
        }
        
        return settlements
    }
    
}
