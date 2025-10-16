//
//  GroupDetailView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//
import SwiftUI
import FirebaseCore
import FirebaseFirestore // ✅ Eklendi
import FirebaseAuth // ✅ Eklendi
import GoogleMaps
import GooglePlaces
import MapKit
import Combine
import GoogleMobileAds
import FirebaseMessaging
import UserNotifications

struct GroupDetailView: View {
    let group: GroupPlan
    @State private var showAddMember = false
    @State private var showAddExpense = false
    @State private var newMemberEmail = ""
    @State private var isAddingMember = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var refreshedGroup: GroupPlan?
    @State private var expenses: [GroupExpense] = []
    @State private var selectedTab = 0
    
    // 🔥 Add real-time listeners
    @State private var expensesListener: ListenerRegistration?
    @State private var groupListener: ListenerRegistration?
    
    var currentGroup: GroupPlan {
        refreshedGroup ?? group
    }
    
    var currentUserEmail: String {
        Auth.auth().currentUser?.email ?? ""
    }
    
    var isOwner: Bool {
        currentGroup.members.contains { $0.email == currentUserEmail && $0.isOwner }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedTab) {
                Text("Itinerary").tag(0)
                Text("Members").tag(1)
                Text("Expenses").tag(2)
                Text("Balances").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()
            
            TabView(selection: $selectedTab) {
                ItineraryTabView(group: currentGroup)
                    .tag(0)
                
                MembersTabView(
                    group: currentGroup,
                    isOwner: isOwner,
                    onMemberRemoved: { await refreshGroup() }
                )
                .tag(1)
                
                ExpensesTabView(
                    groupId: currentGroup.id,
                    expenses: $expenses,
                    members: currentGroup.members
                )
                .tag(2)
                
                BalancesTabView(
                    expenses: expenses,
                    members: currentGroup.members
                )
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(currentGroup.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { showAddMember = true }) {
                        Image(systemName: "person.badge.plus")
                            .font(.title3)
                    }
                    .disabled(!isOwner)
                    
                    Button(action: { showAddExpense = true }) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                        
                    }
                }
            }
        }
        .sheet(isPresented: $showAddMember) {
            AddMemberSheet(
                newMemberEmail: $newMemberEmail,
                isAddingMember: $isAddingMember,
                onAdd: { addMember() }
            )
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView(
                groupId: currentGroup.id,
                members: currentGroup.members,
                onExpenseAdded: {
                    // Listener automatically updates
                }
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        // 🔥 Start listeners when view appears
        .onAppear {
            startListeners()
        }
        // 🔥 Stop listeners when view disappears
        .onDisappear {
            stopListeners()
        }
    }
    
    // 🔥 Add listener management methods
    private func startListeners() {
        // Listen to expenses
        expensesListener = FirestoreService.shared.listenToGroupExpenses(groupId: currentGroup.id) { updatedExpenses in
            withAnimation {
                expenses = updatedExpenses
            }
        }
        
        // Listen to group changes (members, etc.)
        groupListener = FirestoreService.shared.listenToGroup(groupId: currentGroup.id) { updatedGroup in
            if let group = updatedGroup {
                withAnimation {
                    refreshedGroup = group
                }
            }
        }
    }
    
    private func stopListeners() {
        expensesListener?.remove()
        groupListener?.remove()
        expensesListener = nil
        groupListener = nil
    }
    
    private func addMember() {
        let email = newMemberEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }
        
        isAddingMember = true
        
        Task {
            do {
                try await FirestoreService.shared.addMemberToGroup(groupId: currentGroup.id, memberEmail: email)
                // Listener will auto-update
                newMemberEmail = ""
                showAddMember = false
                isAddingMember = false
            } catch {
                errorMessage = "An error occurred! Check member email or internet connection."
                showError = true
                isAddingMember = false
            }
        }
    }
    
    private func refreshGroup() async {
        // Listener handles this automatically now
    }
}
