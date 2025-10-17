//
//  CreateGroupView.swift
//  BagPackr
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Itinerary Selection Type
enum ItinerarySelection: Identifiable, Hashable {
    case regular(Itinerary)
    case multiCity(MultiCityItinerary)
    
    var id: String {
        switch self {
        case .regular(let itinerary):
            return "regular-\(itinerary.id)"
        case .multiCity(let multiCity):
            return "multi-\(multiCity.id)"
        }
    }
    
    var displayName: String {
        switch self {
        case .regular(let itinerary):
            return "\(itinerary.location) - \(itinerary.duration) days"
        case .multiCity(let multiCity):
            return "🗺️ \(multiCity.title) - \(multiCity.totalDuration) days"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ItinerarySelection, rhs: ItinerarySelection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Create Group View
struct CreateGroupView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: GroupPlansViewModel
    @State private var selectedItinerary: ItinerarySelection?
    @State private var groupName = ""
    @State private var memberEmails: [String] = [""]
    @StateObject private var itineraryViewModel = ItineraryListViewModel()
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Itinerary")) {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Picker("Itinerary", selection: $selectedItinerary) {
                            Text("Select...").tag(nil as ItinerarySelection?)
                            
                            // ✅ Multi-city itineraries section
                            if !itineraryViewModel.multiCityItineraries.isEmpty {
                                Section(header: Text("Multi-City Trips")) {
                                    ForEach(itineraryViewModel.multiCityItineraries) { multiCity in
                                        Text("🗺️ \(multiCity.title) - \(multiCity.totalDuration) days")
                                            .tag(ItinerarySelection.multiCity(multiCity) as ItinerarySelection?)
                                    }
                                }
                            }
                            
                            // ✅ Regular itineraries section
                            if !itineraryViewModel.itineraries.isEmpty {
                                Section(header: Text("Single City Trips")) {
                                    ForEach(itineraryViewModel.itineraries) { itinerary in
                                        Text("\(itinerary.location) - \(itinerary.duration) days")
                                            .tag(ItinerarySelection.regular(itinerary) as ItinerarySelection?)
                                    }
                                }
                            }
                            
                            // ✅ No itineraries message
                            if itineraryViewModel.itineraries.isEmpty && itineraryViewModel.multiCityItineraries.isEmpty {
                                Text("No itineraries available")
                                    .foregroundColor(.gray)
                                    .tag(nil as ItinerarySelection?)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                    
                    // ✅ Selected itinerary preview
                    if let selected = selectedItinerary {
                        HStack {
                            Image(systemName: getIcon(for: selected))
                                .foregroundColor(.blue)
                            Text(selected.displayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Group Name")) {
                    TextField("Enter group name", text: $groupName)
                        .submitLabel(.done)
                }
                
                Section(header: Text("Invite Members")) {
                    ForEach(0..<memberEmails.count, id: \.self) { index in
                        HStack {
                            TextField("Email", text: $memberEmails[index])
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
                        Label("Add Member", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(selectedItinerary == nil || groupName.isEmpty || isLoading)
                }
            }
            .onAppear {
                loadItineraries()
            }
        }
    }
    
    // ✅ Load itineraries
    private func loadItineraries() {
        isLoading = true
        Task {
            await itineraryViewModel.loadItineraries()
            await MainActor.run {
                isLoading = false
                print("✅ Loaded \(itineraryViewModel.itineraries.count) regular itineraries")
                print("✅ Loaded \(itineraryViewModel.multiCityItineraries.count) multi-city itineraries")
            }
        }
    }
    
    private func createGroup() {
        guard let selection = selectedItinerary else { return }
        let validEmails = memberEmails.filter { !$0.isEmpty }
        
        Task {
            do {
                switch selection {
                case .regular(let itinerary):
                    try await FirestoreService.shared.createGroupPlan(
                        name: groupName,
                        itinerary: itinerary,
                        memberEmails: validEmails
                    )
                    
                case .multiCity(let multiCity):
                    try await FirestoreService.shared.createMultiCityGroupPlan(
                        name: groupName,
                        multiCity: multiCity,
                        memberEmails: validEmails
                    )
                }
                
                await viewModel.loadGroupPlans()
                dismiss()
            } catch {
                print("❌ Error creating group: \(error)")
            }
        }
    }
    
    private func getIcon(for selection: ItinerarySelection) -> String {
        switch selection {
        case .regular:
            return "mappin.circle.fill"
        case .multiCity:
            return "map.fill"
        }
    }
}
