// Views/CreateGroupView.swift
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
    
    // ✅ Hashable conformance
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
    @ObservedObject var viewModel: GroupPlansViewModel // ✅ parametre olarak geçildi
    @State private var selectedItinerary: ItinerarySelection?
    @State private var groupName = ""
    @State private var memberEmails: [String] = [""]
    @StateObject private var itineraryViewModel = ItineraryListViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Itinerary")) {
                    Picker("Itinerary", selection: $selectedItinerary) {
                        Text("Select...").tag(nil as ItinerarySelection?)
                        
                        // Regular itineraries
                        ForEach(itineraryViewModel.itineraries) { itinerary in
                            Text("\(itinerary.location) - \(itinerary.duration) days")
                                .tag(ItinerarySelection.regular(itinerary) as ItinerarySelection?)
                        }
                        
                        // Multi-city itineraries
                        ForEach(itineraryViewModel.multiCityItineraries) { multiCity in
                            Text("🗺️ \(multiCity.title) - \(multiCity.totalDuration) days")
                                .tag(ItinerarySelection.multiCity(multiCity) as ItinerarySelection?)
                        }
                    }
                    
                    // Selected itinerary preview
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
                    .disabled(selectedItinerary == nil || groupName.isEmpty)
                }
            }
            .onAppear {
                Task {
                    await itineraryViewModel.loadItineraries()
                }
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
                    // ✅ Multi-city için ayrı metod
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

    // ✅ Yeni metod - itinerary kaydetmeden grup oluştur
    private func createGroupPlanWithoutSaving(name: String, itinerary: Itinerary, memberEmails: [String]) async throws {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var members = [GroupMember(email: currentUserEmail, isOwner: true)]
        members.append(contentsOf: memberEmails.map { GroupMember(email: $0, isOwner: false) })
        
        // ✅ isShared flag'i ekleme - bu temporary bir itinerary
        var groupItinerary = itinerary
        // groupItinerary.isShared = true // Bunu eklemeyin, çünkü kaydetmiyoruz
        
        let group = GroupPlan(
            name: name,
            itinerary: groupItinerary,
            members: members
        )
        
        let encoder = Firestore.Encoder()
        let data = try encoder.encode(group)
        try await Firestore.firestore().collection("groupPlans").document(group.id).setData(data)
        
        // ✅ updateItinerary ÇAĞRILMIYOR - bu önemli!
        print("✅ Group created without saving converted itinerary")
    }
    
    private func convertMultiCityToItinerary(_ multiCity: MultiCityItinerary) -> Itinerary {
        var allDailyPlans: [DailyPlan] = []
        var dayCounter = 1
        
        for cityStop in multiCity.cityStops {
            if let itinerary = multiCity.itineraries[cityStop.id] {
                for plan in itinerary.dailyPlans {
                    let adjustedPlan = DailyPlan(
                        day: dayCounter,
                        activities: plan.activities
                    )
                    allDailyPlans.append(adjustedPlan)
                    dayCounter += 1
                }
            }
        }
        
        return Itinerary(
            id: UUID().uuidString,
            userId: multiCity.userId,
            location: multiCity.title,
            duration: multiCity.totalDuration,
            interests: multiCity.interests,
            dailyPlans: allDailyPlans,
            budgetPerDay: multiCity.budgetPerDay,
            createdAt: multiCity.createdAt
        )
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
