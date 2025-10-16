//
//  MembersTabView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI
import FirebaseFirestore // ✅ Eklendi
import FirebaseAuth // ✅ Eklendi
// New Members Tab View
struct MembersTabView: View {
    let group: GroupPlan
    let isOwner: Bool
    let onMemberRemoved: () async -> Void
    
    @State private var showRemoveAlert = false
    @State private var memberToRemove: GroupMember?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var localMembers: [GroupMember] = [] // Add this
    
    var currentUserEmail: String {
        Auth.auth().currentUser?.email ?? ""
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                ModernCard {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Label(String(localized: "Members"), systemImage: "person.2.fill")
                                .font(.headline)
                                .foregroundColor(.purple)
                            
                            Spacer()
                            
                            Text("\(localMembers.count) \(String(localized: "total"))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        ForEach(localMembers, id: \.email) { member in
                            MemberRow(
                                member: member,
                                isCurrentUser: member.email == currentUserEmail,
                                canRemove: isOwner && !member.isOwner && member.email != currentUserEmail,
                                onRemove: {
                                    memberToRemove = member
                                    showRemoveAlert = true
                                }
                            )
                            
                            if member.email != localMembers.last?.email {
                                Divider()
                            }
                        }
                    }
                }
                
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .onAppear {
            localMembers = group.members
        }
        .onChange(of: group.members) { newMembers in
            localMembers = newMembers
        }
        .alert("Remove Member", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) {
                memberToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let member = memberToRemove {
                    removeMember(member)
                }
            }
        } message: {
            if let member = memberToRemove {
                Text("Remove \(member.email.components(separatedBy: "@").first ?? member.email) from the group?")
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func removeMember(_ member: GroupMember) {
        Task {
            do {
                // Animate the removal
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    localMembers.removeAll { $0.email == member.email }
                }
                
                // Delete from Firestore
                try await FirestoreService.shared.removeMemberFromGroup(
                    groupId: group.id,
                    memberEmail: member.email
                )
                await onMemberRemoved()
                memberToRemove = nil
            } catch {
                // If deletion fails, restore the member
                withAnimation {
                    localMembers = group.members
                }
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
