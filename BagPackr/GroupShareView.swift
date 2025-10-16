//
//  GroupShareView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI
// MARK: - Group Share View
struct GroupShareView: View {
    @Environment(\.dismiss) var dismiss
    let itinerary: Itinerary
    @State private var groupName = ""
    @State private var memberEmails: [String] = [""]
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group Details")) {
                    TextField("Group Name", text: $groupName)
                        .submitLabel(.done)
                    
                    Text("Trip: \(itinerary.location)")
                        .foregroundColor(.gray)
                }
                
                Section(header: Text("Invite Members")) {
                    ForEach(0..<memberEmails.count, id: \.self) { index in
                        HStack {
                            TextField("Email address", text: $memberEmails[index])
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .submitLabel(.done)
                            
                            if memberEmails.count > 1 {
                                Button(action: { memberEmails.remove(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    Button(action: { memberEmails.append("") }) {
                        Label("Add Member", systemImage: "plus.circle.fill")
                    }
                }
                
                Section {
                    Button(action: createGroup) {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create Group")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(groupName.isEmpty || isCreating)
                }
            }
            .navigationTitle("Share with Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createGroup() {
        let validEmails = memberEmails.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard !groupName.isEmpty else { return }
        
        isCreating = true
        
        Task {
            do {
                try await FirestoreService.shared.createGroupPlan(
                    name: groupName,
                    itinerary: itinerary,
                    memberEmails: validEmails
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isCreating = false
            }
        }
    }
}
