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
    @State private var showItineraryPicker = false
    
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
                        Button(action: {
                            showItineraryPicker = true
                        }) {
                            HStack {
                                if let selected = selectedItinerary {
                                    Image(systemName: getIcon(for: selected))
                                        .foregroundColor(.blue)
                                    Text(selected.displayName)
                                        .foregroundColor(.primary)
                                } else {
                                    Text("Select an itinerary...")
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
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
            .sheet(isPresented: $showItineraryPicker) {
                ItineraryPickerSheet(
                    selectedItinerary: $selectedItinerary,
                    regularItineraries: itineraryViewModel.itineraries,
                    multiCityItineraries: itineraryViewModel.multiCityItineraries
                )
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

// MARK: - Itinerary Picker Sheet

//
//  ItineraryPickerSheet.swift - FIXED
//  BagPackr
//

import SwiftUI

//
//  ItineraryPickerSheet.swift - FIXED
//  BagPackr
//

import SwiftUI

struct ItineraryPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedItinerary: ItinerarySelection?
    let regularItineraries: [Itinerary]
    let multiCityItineraries: [MultiCityItinerary]
    
    var body: some View {
        NavigationView {
            List {
                // Multi-City Section
                if !multiCityItineraries.isEmpty {
                    Section {
                        ForEach(multiCityItineraries) { multiCity in
                            MultiCityPickerRow(
                                multiCity: multiCity,
                                isSelected: isMultiCitySelected(multiCity),
                                onTap: {
                                    selectedItinerary = .multiCity(multiCity)
                                    dismiss()
                                }
                            )
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "map.fill")
                                .font(.caption)
                            Text("MULTI-CITY TRIPS")
                                .font(.caption)
                        }
                        .foregroundColor(.purple)
                    }
                }
                
                // Regular Itineraries Section
                if !regularItineraries.isEmpty {
                    Section {
                        ForEach(regularItineraries) { itinerary in
                            RegularItineraryPickerRow(
                                itinerary: itinerary,
                                isSelected: isRegularSelected(itinerary),
                                onTap: {
                                    selectedItinerary = .regular(itinerary)
                                    dismiss()
                                }
                            )
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                            Text("SINGLE CITY TRIPS")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Empty State
                if regularItineraries.isEmpty && multiCityItineraries.isEmpty {
                    emptyStateView
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Itinerary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Itineraries Available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Create an itinerary first to start a group plan")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Helper Methods
    
    private func isMultiCitySelected(_ multiCity: MultiCityItinerary) -> Bool {
        if case .multiCity(let selected) = selectedItinerary {
            return selected.id == multiCity.id
        }
        return false
    }
    
    private func isRegularSelected(_ itinerary: Itinerary) -> Bool {
        if case .regular(let selected) = selectedItinerary {
            return selected.id == itinerary.id
        }
        return false
    }
}

// MARK: - Multi-City Picker Row

struct MultiCityPickerRow: View {
    let multiCity: MultiCityItinerary
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                iconView
                detailsView
                Spacer()
                if isSelected {
                    checkmarkView
                }
            }
        }
    }
    
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
            
            Image(systemName: "map.fill")
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
    }
    
    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(multiCity.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            FlexibleChipLayout(spacing: 6) {
                infoChip(icon: "mappin.and.ellipse", text: "\(multiCity.citiesCount) cities")
                infoChip(icon: "calendar", text: "\(multiCity.totalDuration) days")
                infoChip(icon: "dollarsign.circle", text: "$\(Int(multiCity.totalBudget))")
            }
        }
    }
    
    private var checkmarkView: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.blue)
    }
    
    private func infoLabel(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    
    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Regular Itinerary Picker Row

struct RegularItineraryPickerRow: View {
    let itinerary: Itinerary
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                iconView
                detailsView
                Spacer()
                if isSelected {
                    checkmarkView
                }
            }
        }
    }
    
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .cyan.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
            
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
    }
    
    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(itinerary.location)
                .font(.headline)
                .foregroundColor(.primary)
            
            FlexibleChipLayout(spacing: 6) {
                infoChip(icon: "calendar", text: "\(itinerary.duration) days")
                infoChip(icon: "dollarsign.circle", text: "$\(Int(itinerary.budgetPerDay * Double(itinerary.duration)))")
            }
        }
    }
    
    private var checkmarkView: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.blue)
    }
    
    private func infoLabel(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    
    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}





