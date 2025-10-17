//
//  MultiCityGroupDetailView.swift
//  BagPackr
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
                itineraryTab.tag(0)
                
                MembersTabView(
                    group: convertToGroupPlan(currentGroup),
                    isOwner: isOwner,
                    onMemberRemoved: { }
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
                onExpenseAdded: { }
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear { startListeners() }
        .onDisappear { stopListeners() }
    }
    
    private var itineraryTab: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                cityTabs

                ScrollView {
                    if let selectedCity = currentGroup.multiCityItinerary.cityStops[safe: selectedCityIndex],
                       let itinerary = currentGroup.multiCityItinerary.itineraries[selectedCity.id] {

                        VStack(alignment: .leading, spacing: 20) {
                            // 🟦 City Header
                            cityHeader(for: selectedCity)
                                .frame(width: geo.size.width - 32) // 👈 forces exact width with 16pt padding on each side

                            // 🟨 Day Plans
                            LazyVStack(spacing: 16) {
                                ForEach(Array(itinerary.dailyPlans.enumerated()), id: \.element.id) { index, plan in
                                    EnhancedDayPlanCard(
                                        dayNumber: index + 1,
                                        plan: plan,
                                        location: selectedCity.location.name,
                                        itinerary: itinerary
                                    )
                                    .frame(width: geo.size.width - 32, alignment: .leading) // 👈 lock card width
                                }
                            }
                        }
                        .padding(.horizontal, 16) // single, outer padding only
                        .padding(.top, 20)
                    }
                }
            }
            .frame(width: geo.size.width, alignment: .leading)
        }
    }




    
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
    
    private func cityHeader(for city: CityStop) -> some View {
        ZStack {
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mappin.circle.fill").font(.title2)
                    Text(city.location.name)
                        .font(.title2).fontWeight(.bold)
                }
                
                Label("\(city.duration) days", systemImage: "calendar")
                    .font(.subheadline)
            }
            .foregroundColor(.white)
            .padding()
        }
        .cornerRadius(20)
    }
    @State private var expensesListener: ListenerRegistration?

    private func startListeners() {
        // 🔥 Add this - listen to expenses
        expensesListener = FirestoreService.shared.listenToGroupExpenses(groupId: currentGroup.id) { updatedExpenses in
            withAnimation {
                expenses = updatedExpenses
            }
        }
        
        // Listen to group changes (existing code)
        groupListener = FirestoreService.shared.listenToMultiCityGroup(groupId: currentGroup.id) { updatedGroup in
            if let group = updatedGroup {
                withAnimation {
                    refreshedGroup = group
                }
            }
        }
    }

    private func stopListeners() {
        expensesListener?.remove()  // 🔥 Add this
        groupListener?.remove()
        expensesListener = nil      // 🔥 Add this
        groupListener = nil
    }
    
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
                errorMessage = "An error occurred!"
                showError = true
                isAddingMember = false
            }
        }
    }
    
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
                dailyPlans: []
            ),
            members: mc.members
        )
    }
}

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
