//
//  MultiCityGroupDetailView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MultiCityGroupDetailView: View {
    let group: MultiCityGroupPlan
    @State private var refreshedGroup: MultiCityGroupPlan?
    @State private var selectedCityIndex = 0
    @State private var selectedTab = 0
    
    @State private var showAddMember = false
    @State private var showAddExpense = false
    @State private var newMemberEmail = ""
    @State private var isAddingMember = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @State private var expenses: [GroupExpense] = []
    @State private var groupListener: ListenerRegistration?
    // @State private var expensesListener: ListenerRegistration? — for later if needed
    
    var currentGroup: MultiCityGroupPlan {
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
                
                // MARK: - Itinerary Tab
                itineraryTab
                    .tag(0)
                
                // MARK: - Members Tab
                MembersTabView(
                    group: convertToGroupPlan(currentGroup),
                    isOwner: isOwner,
                    onMemberRemoved: {
                        // Real-time listener handles UI refresh
                    }
                )
                .tag(1)
                
                // MARK: - Expenses Tab
                ExpensesTabView(
                    groupId: currentGroup.id,
                    expenses: $expenses,
                    members: currentGroup.members
                )
                .tag(2)
                
                // MARK: - Balances Tab
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
                    // listener auto-refreshes
                }
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            startListeners()
        }
        .onDisappear {
            stopListeners()
        }
    }
    
    // MARK: - Itinerary Tab Content
    private var itineraryTab: some View {
        VStack(spacing: 0) {
            cityTabs
            
            ScrollView {
                if let selectedCity = currentGroup.multiCityItinerary.cityStops[safe: selectedCityIndex],
                   let itinerary = currentGroup.multiCityItinerary.itineraries[selectedCity.id] {
                    
                    VStack(spacing: 20) {
                        cityHeader(for: selectedCity)
                        
                        ForEach(Array(itinerary.dailyPlans.enumerated()), id: \.element.id) { index, plan in
                            EnhancedDayPlanCard(
                                dayNumber: index + 1,
                                plan: plan,
                                location: selectedCity.location.name,
                                itinerary: itinerary
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - City Tabs
    private var cityTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(currentGroup.multiCityItinerary.cityStops.enumerated()), id: \.element.id) { index, city in
                    CityTabButton(
                        city: city,
                        index: index + 1,
                        isSelected: selectedCityIndex == index
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedCityIndex = index
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - City Header
    private func cityHeader(for city: CityStop) -> some View {
        ZStack {
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                    Text(city.location.name)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Label("\(city.duration) days", systemImage: "calendar")
                    .font(.subheadline)
            }
            .foregroundColor(.white)
            .padding()
        }
        .cornerRadius(20)
    }
    
    // MARK: - Firestore Listeners
    private func startListeners() {
        groupListener = FirestoreService.shared.listenToMultiCityGroup(groupId: currentGroup.id) { updatedGroup in
            if let updatedGroup = updatedGroup {
                withAnimation {
                    refreshedGroup = updatedGroup
                }
            }
        }
        
        // If you later support multi-city expenses in Firestore:
        // expensesListener = FirestoreService.shared.listenToGroupExpenses(groupId: currentGroup.id) { updated in
        //    withAnimation { expenses = updated }
        // }
    }
    
    private func stopListeners() {
        groupListener?.remove()
        groupListener = nil
        // expensesListener?.remove()
    }
    
    // MARK: - Add Member
    private func addMember() {
        let email = newMemberEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }
        
        isAddingMember = true
        
        Task {
            do {
                try await Firestore.firestore()
                    .collection("multiCityGroupPlans")
                    .document(currentGroup.id)
                    .updateData([
                        "members": FieldValue.arrayUnion([["email": email, "isOwner": false]]),
                        "memberEmails": FieldValue.arrayUnion([email])
                    ])
                
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
    
    // MARK: - Convert MultiCityGroupPlan → GroupPlan (for MembersTabView)
    private func convertToGroupPlan(_ mc: MultiCityGroupPlan) -> GroupPlan {
        GroupPlan(
            id: mc.id,
            name: mc.name,
            itinerary: Itinerary(
                id: mc.id,
                userId: "",
                location: mc.multiCityItinerary.cityNames,
                duration: mc.multiCityItinerary.totalDuration,
                interests: mc.multiCityItinerary.interests,
                dailyPlans: [] // not used in MembersTabView
            ),
            members: mc.members
        )
    }
}

// MARK: - City Tab Button
struct CityTabButton: View {
    let city: CityStop
    let index: Int
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 24, height: 24)
                    
                    Text("\(index)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .blue : .white)
                }
                
                Text(city.location.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            
            Text("\(city.duration) days")
                .font(.caption2)
                .opacity(0.8)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(isSelected ? Color.blue : Color.gray.opacity(0.3))
        )
    }
}
