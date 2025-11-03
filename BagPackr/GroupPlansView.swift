//
//  GroupPlansView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.

import SwiftUI

// MARK: - Group Plans View
struct GroupPlansView: View {
    @StateObject private var viewModel = GroupPlansViewModel()
    @State private var showCreateGroup = false
    
    private var isEmpty: Bool {
        viewModel.groupPlans.isEmpty && viewModel.multiCityGroupPlans.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if isEmpty {
                    emptyStateView
                } else {
                    groupListView
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isEmpty)
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
            // Multi-city groups section
            if !viewModel.multiCityGroupPlans.isEmpty {
                Section(header: sectionHeader(title: "Multi-City Groups", icon: "map.fill", color: .blue)) {
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
            
            // Regular groups section
            if !viewModel.groupPlans.isEmpty {
                Section(header: sectionHeader(title: "Single City Groups", icon: "person.3.fill", color: .purple)) {
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
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        .transition(.opacity.combined(with: .scale))
    }
    
    // Section header helper
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
        }
        .font(.headline)
        .foregroundColor(color)
    }
    
    // MARK: - Delete Actions
    private func deleteGroups(at offsets: IndexSet) {
        for index in offsets {
            let group = viewModel.groupPlans[index]
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
    
    private func deleteMultiCityGroups(at offsets: IndexSet) {
        for index in offsets {
            let group = viewModel.multiCityGroupPlans[index]
            Task {
                do {
                    try await FirestoreService.shared.deleteMultiCityGroup(group.id)
                    print("✅ Multi-city group deleted successfully")
                } catch {
                    print("❌ Error deleting multi-city group: \(error)")
                }
            }
        }
    }
}
