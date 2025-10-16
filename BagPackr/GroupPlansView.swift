//
//  GroupPlansView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

// MARK: - Group Plans View
struct GroupPlansView: View {
    @StateObject private var viewModel = GroupPlansViewModel()
    @State private var showCreateGroup = false
    @State private var showDeleteAlert = false
    @State private var groupToDelete: GroupPlan?
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.groupPlans.isEmpty {
                    emptyStateView
                } else {
                    groupListView
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.groupPlans.count)
            .navigationTitle("Group Plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateGroup = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView(viewModel: viewModel)
            }
            .alert("Delete Group", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let group = groupToDelete {
                        deleteGroup(group)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this group? This action cannot be undone.")
            }
        }
        .onAppear {
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.2), .pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.purple)
            }
            
            Text("No Group Plans")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create or join a group to plan trips together!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showCreateGroup = true }) {
                Text("Create Group Plan")
                    .fontWeight(.semibold)
                    .frame(maxWidth: 200)
                    .padding()
                    .background(
                        LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    // MARK: - Group List
    private var groupListView: some View {
        List {
            // Regular groups
            if !viewModel.groupPlans.isEmpty {
                Section(header: Text("Single City Groups")) {
                    ForEach(viewModel.groupPlans) { group in
                        NavigationLink(destination: GroupDetailView(group: group)) {
                            GroupPlanRow(group: group)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deleteGroups)
                }
            }
            
            // ✅ Multi-city groups
            if !viewModel.multiCityGroupPlans.isEmpty {
                Section(header: Text("Multi-City Groups")) {
                    ForEach(viewModel.multiCityGroupPlans) { group in
                        NavigationLink(destination: MultiCityGroupDetailView(group: group)) {
                            MultiCityGroupPlanRow(group: group)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deleteMultiCityGroups)
                }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
    }

    private func deleteMultiCityGroups(at offsets: IndexSet) {
        for index in offsets {
            let group = viewModel.multiCityGroupPlans[index]
            Task {
                try? await FirestoreService.shared.deleteMultiCityGroup(group.id)
            }
        }
    }
    
    // MARK: - Delete Actions
    private func deleteGroups(at offsets: IndexSet) {
        for index in offsets {
            groupToDelete = viewModel.groupPlans[index]
            showDeleteAlert = true
        }
    }
    
    private func deleteGroup(_ group: GroupPlan) {
        Task {
            do {
                try await FirestoreService.shared.deleteGroup(group.id)
                print("✅ Group deleted successfully")
            } catch {
                print("❌ Error deleting group: \(error)")
            }
        }
    }
}


// MARK: - Preview
struct GroupPlansView_Previews: PreviewProvider {
    static var previews: some View {
        GroupPlansView()
    }
}
