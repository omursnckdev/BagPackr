//
//  ContentView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 1.10.2025
//
// MARK: - App Entry Point
import SwiftUI
import FirebaseCore
import GoogleMaps
import GooglePlaces
import MapKit
import Combine
import GoogleMobileAds
import FirebaseMessaging
import UserNotifications

import SwiftUI
import FirebaseCore
import GoogleMaps
import GooglePlaces
import GoogleMobileAds
import FirebaseMessaging
import UserNotifications
import StoreKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, _ in
            print("Permission granted: \(granted)")
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("🚫 User denied push permission")
            }
        }
        
        Messaging.messaging().delegate = self
        
        return true
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs Device Token (raw): \(tokenParts)")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // Handle FCM token
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔸 Received new FCM Token: \(fcmToken ?? "nil")")
        
        guard let token = fcmToken,
              let userId = Auth.auth().currentUser?.uid else { return }
        
        // Save token to Firestore
        Task {
            try? await Firestore.firestore()
                .collection("users")
                .document(userId)
                .setData([
                    "fcmToken": token,
                    "email": Auth.auth().currentUser?.email ?? "",
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
        }
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("Notification tapped: \(userInfo)")
        completionHandler()
    }
}

@main
struct BagPackrApp: App {
    
    @StateObject private var authViewModel = AuthViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Initialize Google Maps & Places
        GMSServices.provideAPIKey("AIzaSyC5wDKS2_3NMA8mxKhEFzktmiPCY4atE10")
        GMSPlacesClient.provideAPIKey("AIzaSyC5wDKS2_3NMA8mxKhEFzktmiPCY4atE10")
        
        // Initialize Google Mobile Ads
        MobileAds.shared.start()
        
        // ✅ Initialize StoreKit Manager
        _ = RevenueCatManager.shared
        print("✅ RevenueCat Manager initialized")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .task {
                    // ✅ Check premium status when app launches
                    await RevenueCatManager.shared.checkSubscriptionStatus()
                    await RevenueCatManager.shared.fetchOfferings()
                }
        }
    }
}// MARK: - Content View
// Update ContentView in ContentView.swift

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                if hasSeenOnboarding {
                    MainTabView()
                } else {
                    OnboardingView {
                        hasSeenOnboarding = true
                    }
                }
            } else {
                AuthView()
            }
        }
        .onAppear {
            // Show onboarding only once after first login
            if authViewModel.isAuthenticated && !hasSeenOnboarding {
                showOnboarding = true
            }
        }
    }
}


struct GlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.2))
            )
            .foregroundColor(.white)
    }
}


// MARK: - Main Tab View
struct MainTabView: View {
    @StateObject private var itineraryListViewModel = ItineraryListViewModel()
    
    var body: some View {
        TabView {
            CreateItineraryView(itineraryListViewModel: itineraryListViewModel)
                         .tabItem {
                             Label("Create", systemImage: "plus.circle.fill")
                         }
                         .onAppear {
                                            // ⭐ Analytics
                                            AnalyticsService.shared.logScreenView("CreateItineraryView")
                                        }
            MultiCityPlannerView(itineraryListViewModel: itineraryListViewModel)
                        .tabItem {
                            Label("Multi-City", systemImage: "map.fill")
                        }
                        .onAppear {
                                         // ⭐ Analytics
                                         AnalyticsService.shared.logScreenView("MultiCityPlannerView")
                                     }
            
            ItineraryListView(viewModel: itineraryListViewModel)
                .tabItem {
                    Label("My Plans", systemImage: "list.bullet")
                }
                .onAppear {
                                   // ⭐ Analytics
                                   AnalyticsService.shared.logScreenView("ItineraryListView")
                               }
            GroupPlansView()
                .tabItem {
                    Label("Groups", systemImage: "person.3.fill")
                }
                .onAppear {
                    // ⭐ Analytics
                    AnalyticsService.shared.logScreenView("GroupPlansView")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .onAppear {
                                   // ⭐ Analytics
                                   AnalyticsService.shared.logScreenView("ProfileView")
                               }
        }
        .accentColor(.blue)
    }
}

// MARK: - Create Itinerary View

extension View {
  
}

struct ModernCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
            )
    }
}

struct EnhancedInterestChip: View {
    let title: String
    let isSelected: Bool
    var isCustom: Bool = false
    let action: () -> Void
    var onRemove: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 6) {
            Text(LocalizedStringKey(title))
                .font(.subheadline)
                .fontWeight(.medium)
            
            if isCustom, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isSelected ?
                      LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) :
                        LinearGradient(colors: [.gray.opacity(0.2), .gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                     )
        )
        .foregroundColor(isSelected ? .white : .primary)
        .shadow(color: isSelected ? Color.blue.opacity(0.3) : Color.clear, radius: 5, x: 0, y: 3)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .onTapGesture(perform: action)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth, currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}


struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}







// MARK: - Flexible Chip Layout
struct FlexibleChipLayout<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    
    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        FlowLayout(spacing: spacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(minWidth: 90, minHeight: 70)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(15)
        }
    }
}



struct AddMemberSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var newMemberEmail: String
    @Binding var isAddingMember: Bool
    let onAdd: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Add Member")) {
                    TextField("Email address", text: $newMemberEmail)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .submitLabel(.done)
                }
                
                Section {
                    Button(action: {
                        onAdd()
                    }) {
                        if isAddingMember {
                            ProgressView()
                        } else {
                            Text("Add Member")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(newMemberEmail.isEmpty || isAddingMember)
                }
            }
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        newMemberEmail = ""
                        dismiss()
                    }
                }
            }
        }
    }
}

import FirebaseAuth
import FirebaseFirestore

class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Itineraries
    func saveItinerary(_ itinerary: Itinerary) async throws {
        let encoder = Firestore.Encoder()
        let data = try encoder.encode(itinerary)
        try await db.collection("itineraries").document(itinerary.id).setData(data)
    }
    
    
    // FirestoreService içine:

 
    func fetchItineraries() async throws -> [Itinerary] {
        guard let userId = Auth.auth().currentUser?.uid else { return [] }

        let snapshot = try await db.collection("itineraries")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let decoder = Firestore.Decoder()

        // Inject the Firestore document ID, then decode
        let itineraries: [Itinerary] = snapshot.documents.compactMap { doc in
            var data = doc.data()
            data["id"] = doc.documentID
            do {
                return try decoder.decode(Itinerary.self, from: data)
            } catch {
                print("⚠️ Skipping malformed itinerary \(doc.documentID): \(error)")
                return nil
            }
        }

        return itineraries.sorted { $0.createdAt > $1.createdAt }
    }

    func loadItineraries(userId: String) async throws -> [Itinerary] {
        let snapshot = try await db.collection("itineraries")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        let decoder = Firestore.Decoder()

        let itineraries: [Itinerary] = snapshot.documents.compactMap { doc in
            var data = doc.data()
            data["id"] = doc.documentID
            do {
                return try decoder.decode(Itinerary.self, from: data)
            } catch {
                print("⚠️ Skipping malformed itinerary \(doc.documentID): \(error)")
                return nil
            }
        }

        return itineraries
    }

    
    
    func deleteItinerary(_ id: String) async throws {
        try await db.collection("itineraries").document(id).delete()
    }
    
    func updateItinerary(_ itinerary: Itinerary) async throws {
        let encoder = Firestore.Encoder()
        let data = try encoder.encode(itinerary)
        try await db.collection("itineraries").document(itinerary.id).setData(data)
    }
    
    // MARK: - Progress Tracking
    func updateItineraryProgress(itineraryId: String, dayId: String, completedActivities: [String]) async throws {
        try await db.collection("itineraries")
            .document(itineraryId)
            .collection("progress")
            .document(dayId)
            .setData(["completedActivities": completedActivities])
    }
    
    
    // MARK: - Multi-City Itinerary Methods (FirestoreService içine ekleyin)

    func saveMultiCityItinerary(_ multiCity: MultiCityItinerary) async throws {
        let docRef = db.collection("multiCityItineraries").document(multiCity.id)
        try docRef.setData(from: multiCity)
        print("✅ Multi-city itinerary saved: \(multiCity.id)")
    }

    func loadMultiCityItineraries(userId: String) async throws -> [MultiCityItinerary] {
        let snapshot = try await db.collection("multiCityItineraries")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        let itineraries = snapshot.documents.compactMap { doc -> MultiCityItinerary? in
            try? doc.data(as: MultiCityItinerary.self)
        }
        
        print("✅ Loaded \(itineraries.count) multi-city itineraries")
        return itineraries
    }

    func updateMultiCityItinerary(_ multiCity: MultiCityItinerary) async throws {
        let docRef = db.collection("multiCityItineraries").document(multiCity.id)
        try docRef.setData(from: multiCity, merge: true)
        print("✅ Multi-city itinerary updated: \(multiCity.id)")
    }

    func deleteMultiCityItinerary(_ id: String) async throws {
        try await db.collection("multiCityItineraries").document(id).delete()
        print("✅ Multi-city itinerary deleted: \(id)")
    }

    func getMultiCityItinerary(_ id: String) async throws -> MultiCityItinerary? {
        let docRef = db.collection("multiCityItineraries").document(id)
        let snapshot = try await docRef.getDocument()
        return try? snapshot.data(as: MultiCityItinerary.self)
    }

    // MARK: - Multi-City Group Methods

    func createMultiCityGroupPlan(name: String, multiCity: MultiCityItinerary, memberEmails: [String]) async throws {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var members = [GroupMember(email: currentUserEmail, isOwner: true)]
        members.append(contentsOf: memberEmails.map { GroupMember(email: $0, isOwner: false) })
        
        let group = MultiCityGroupPlan(
            name: name,
            multiCityItinerary: multiCity,
            members: members
        )
        
        let encoder = Firestore.Encoder()
        let data = try encoder.encode(group)
        try await db.collection("multiCityGroupPlans").document(group.id).setData(data)
        
        print("✅ Multi-city group plan created: \(group.id)")
        
        AnalyticsService.shared.logGroupCreated(
             memberCount: memberEmails.count + 1,
             isMultiCity: true
         )
        
    }

    func fetchMultiCityGroupPlans() async throws -> [MultiCityGroupPlan] {
        guard let userEmail = Auth.auth().currentUser?.email else { return [] }
        
        let snapshot = try await db.collection("multiCityGroupPlans")
            .whereField("memberEmails", arrayContains: userEmail)
            .getDocuments()
        
        let decoder = Firestore.Decoder()
        return try snapshot.documents.compactMap { doc in
            try? decoder.decode(MultiCityGroupPlan.self, from: doc.data())
        }
    }

    func listenToMultiCityGroup(groupId: String, completion: @escaping (MultiCityGroupPlan?) -> Void) -> ListenerRegistration {
        db.collection("multiCityGroupPlans")
            .document(groupId)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data() else {
                    completion(nil)
                    return
                }
                let decoder = Firestore.Decoder()
                let group = try? decoder.decode(MultiCityGroupPlan.self, from: data)
                completion(group)
            }
    }

    func deleteMultiCityGroup(_ id: String) async throws {
        try await db.collection("multiCityGroupPlans").document(id).delete()
    }
    
    func getItineraryProgress(itineraryId: String, dayId: String) async throws -> [String] {
        let doc = try await db.collection("itineraries")
            .document(itineraryId)
            .collection("progress")
            .document(dayId)
            .getDocument()
        
        if let data = doc.data(), let completed = data["completedActivities"] as? [String] {
            return completed
        }
        return []
    }
    
    // MARK: - Group Plans
    func createGroupPlan(name: String, itinerary: Itinerary, memberEmails: [String]) async throws {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var members = [GroupMember(email: currentUserEmail, isOwner: true)]
        members.append(contentsOf: memberEmails.map { GroupMember(email: $0, isOwner: false) })
        
        var sharedItinerary = itinerary
        sharedItinerary.isShared = true
        
        let group = GroupPlan(
            name: name,
            itinerary: sharedItinerary,
            members: members
        )
        
        let encoder = Firestore.Encoder()
        let data = try encoder.encode(group)
        try await db.collection("groupPlans").document(group.id).setData(data)
        
        try await updateItinerary(sharedItinerary)
        
        AnalyticsService.shared.logGroupCreated(
              memberCount: memberEmails.count + 1,
              isMultiCity: false
          )
    }
    
    func fetchGroupPlans() async throws -> [GroupPlan] {
        guard let userEmail = Auth.auth().currentUser?.email else {
            return []
        }
        
        let snapshot = try await db.collection("groupPlans")
            .whereField("memberEmails", arrayContains: userEmail)
            .getDocuments()
        
        let decoder = Firestore.Decoder()
        return try snapshot.documents.compactMap { doc in
            try? decoder.decode(GroupPlan.self, from: doc.data())
        }
    }
    

    

    // MARK: - User Premium Methods

    func updateUserPremiumStatus(userId: String, isPremium: Bool) async throws {
        let userRef = db.collection("users").document(userId)
        try await userRef.setData([
            "isPremium": isPremium,
            "premiumUpdatedAt": Timestamp(date: Date())
        ], merge: true)
        print("✅ User premium status updated: \(isPremium)")
    }

    func getUserPremiumStatus(userId: String) async throws -> Bool {
        let userRef = db.collection("users").document(userId)
        let snapshot = try await userRef.getDocument()
        return snapshot.data()?["isPremium"] as? Bool ?? false
    }
    
    func addMemberToGroup(groupId: String, memberEmail: String) async throws {
        let docRef = db.collection("groupPlans").document(groupId)
        let document = try await docRef.getDocument()
        guard let data = document.data() else {
            throw NSError(domain: "Firestore", code: 404)
        }
        
        let decoder = Firestore.Decoder()
        let group = try decoder.decode(GroupPlan.self, from: data)
        
        guard !group.members.contains(where: { $0.email == memberEmail }) else {
            throw NSError(domain: "Firestore", code: 400)
        }
        
        // Add member
        try await docRef.updateData([
            "members": FieldValue.arrayUnion([["email": memberEmail, "isOwner": false]]),
            "memberEmails": FieldValue.arrayUnion([memberEmail])
        ])
        
        // Send notification
        guard let senderEmail = Auth.auth().currentUser?.email else { return }
        let senderName = senderEmail.components(separatedBy: "@").first ?? "Someone"
        
        try await sendNotification(
            toEmail: memberEmail,
            title: "Added to Group",
            body: "\(senderName) has added you to group \"\(group.name)\"",
            data: ["groupId": groupId, "type": "group_invite"]
        )
    }
    
    func removeMemberFromGroup(groupId: String, memberEmail: String) async throws {
        let docRef = db.collection("groupPlans").document(groupId)
        let document = try await docRef.getDocument()
        guard let data = document.data() else {
            throw NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
        }
        
        let decoder = Firestore.Decoder()
        let group = try decoder.decode(GroupPlan.self, from: data)
        
        // Don't allow removing the owner
        guard !group.members.contains(where: { $0.email == memberEmail && $0.isOwner }) else {
            throw NSError(domain: "Firestore", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot remove group owner"])
        }
        
        // Remove member
        try await docRef.updateData([
            "members": FieldValue.arrayRemove([["email": memberEmail, "isOwner": false]]),
            "memberEmails": FieldValue.arrayRemove([memberEmail])
        ])
    }
    
    private func sendNotification(toEmail: String, title: String, body: String, data: [String: String]) async throws {
        // Get recipient's FCM token
        let userSnapshot = try await db.collection("users")
            .whereField("email", isEqualTo: toEmail)
            .limit(to: 1)
            .getDocuments()
        
        guard let userDoc = userSnapshot.documents.first,
              let fcmToken = userDoc.data()["fcmToken"] as? String else {
            print("No FCM token found for \(toEmail)")
            return
        }
        
        // Create notification document (Cloud Function will handle sending)
        try await db.collection("notifications").addDocument(data: [
            "token": fcmToken,
            "title": title,
            "body": body,
            "data": data,
            "timestamp": FieldValue.serverTimestamp()
        ])
    }
    
    private func sendGroupInviteNotification(toEmail: String, groupName: String, inviterEmail: String) async throws {
        // Get recipient's FCM token
        let userSnapshot = try await db.collection("users")
            .whereField("email", isEqualTo: toEmail)
            .limit(to: 1)
            .getDocuments()
        
        guard let userDoc = userSnapshot.documents.first,
              let fcmToken = userDoc.data()["fcmToken"] as? String else {
            return // User doesn't have app installed or token not available
        }
        
        // Send notification via Cloud Function (see below)
        try await db.collection("notifications").addDocument(data: [
            "token": fcmToken,
            "title": "New Group Invitation",
            "body": "\(inviterEmail.components(separatedBy: "@").first ?? "Someone") invited you to \(groupName)",
            "data": [
                "type": "group_invite",
                "groupId": groupName
            ],
            "timestamp": FieldValue.serverTimestamp()
        ])
    }
    
    func getGroupById(groupId: String) async throws -> GroupPlan {
        let document = try await db.collection("groupPlans").document(groupId).getDocument()
        guard let data = document.data() else {
            throw NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
        }
        
        let decoder = Firestore.Decoder()
        return try decoder.decode(GroupPlan.self, from: data)
    }
    
    func deleteGroup(_ id: String) async throws {
        try await db.collection("groupPlans").document(id).delete()
    }


    // MARK: - Expenses + Settlements (Fixed for Multi-City Support)

    func addExpenseToGroup(expense: GroupExpense) async throws {
        print("🔵 Adding expense to group: \(expense.groupId)")
        
        let encoder = Firestore.Encoder()
        let data = try encoder.encode(expense)
        
        // ✅ Try to find group in either collection
        let collectionName = try await getGroupCollectionName(groupId: expense.groupId)
        print("✅ Found group in collection: \(collectionName)")
        
        try await db.collection(collectionName)
            .document(expense.groupId)
            .collection("expenses")
            .document(expense.id)
            .setData(data)
        
        print("✅ Expense added successfully")
        
        // 🔄 Recalculate settlements
        let expenses = try await fetchGroupExpenses(groupId: expense.groupId, collectionName: collectionName)
        let members = try await getGroupMembers(groupId: expense.groupId, collectionName: collectionName)
        let newSettlements = calculateSettlements(expenses: expenses, members: members)
        try await saveSettlements(groupId: expense.groupId, settlements: newSettlements, collectionName: collectionName)
        
        print("✅ Settlements recalculated")
        
        AnalyticsService.shared.logExpenseAdded(
              amount: expense.amount,
              category: expense.category.rawValue,
              splitCount: expense.splitBetween.count
          )
    }

    func fetchGroupExpenses(groupId: String, collectionName: String? = nil) async throws -> [GroupExpense] {
        let collection: String
        if let collectionName = collectionName {
            collection = collectionName
        } else {
            collection = try await getGroupCollectionName(groupId: groupId)
        }
        
        let snapshot = try await db.collection(collection)
            .document(groupId)
            .collection("expenses")
            .getDocuments()
        
        let decoder = Firestore.Decoder()
        return try snapshot.documents.compactMap { doc in
            try? decoder.decode(GroupExpense.self, from: doc.data())
        }.sorted { $0.date > $1.date }
    }

    func deleteExpense(groupId: String, expenseId: String) async throws {
        let collectionName = try await getGroupCollectionName(groupId: groupId)
        
        try await db.collection(collectionName)
            .document(groupId)
            .collection("expenses")
            .document(expenseId)
            .delete()
        
        // 🔄 Recalculate settlements
        let expenses = try await fetchGroupExpenses(groupId: groupId, collectionName: collectionName)
        let members = try await getGroupMembers(groupId: groupId, collectionName: collectionName)
        let newSettlements = calculateSettlements(expenses: expenses, members: members)
        try await saveSettlements(groupId: groupId, settlements: newSettlements, collectionName: collectionName)
    }

    func updateExpense(groupId: String, expenseId: String, description: String, amount: Double, category: ExpenseCategory) async throws {
        let collectionName = try await getGroupCollectionName(groupId: groupId)
        
        try await db.collection(collectionName)
            .document(groupId)
            .collection("expenses")
            .document(expenseId)
            .updateData([
                "description": description,
                "amount": amount,
                "category": category.rawValue
            ])
        
        // Recalculate settlements
        let expenses = try await fetchGroupExpenses(groupId: groupId, collectionName: collectionName)
        let members = try await getGroupMembers(groupId: groupId, collectionName: collectionName)
        let newSettlements = calculateSettlements(expenses: expenses, members: members)
        try await saveSettlements(groupId: groupId, settlements: newSettlements, collectionName: collectionName)
    }

    // MARK: - Settlements (Fixed)

    func saveSettlements(groupId: String, settlements: [Settlement], collectionName: String? = nil) async throws {
        let collection: String
        if let collectionName = collectionName {
            collection = collectionName
        } else {
            collection = try await getGroupCollectionName(groupId: groupId)
        }
        
        let encoder = Firestore.Encoder()
        let data = try settlements.map { try encoder.encode($0) }
        
        try await db.collection(collection)
            .document(groupId)
            .collection("settlements")
            .document("current")
            .setData(["items": data])
    }

    func fetchSettlements(groupId: String) async throws -> [Settlement] {
        let collectionName = try await getGroupCollectionName(groupId: groupId)
        
        let snapshot = try await db.collection(collectionName)
            .document(groupId)
            .collection("settlements")
            .document("current")
            .getDocument()
        
        guard let data = snapshot.data(),
              let items = data["items"] as? [[String: Any]] else {
            return []
        }
        
        let decoder = Firestore.Decoder()
        return try items.compactMap { try decoder.decode(Settlement.self, from: $0) }
    }
    func markSettlementAsPaid(groupId: String, settlementId: String) async throws {
        let collectionName = try await getGroupCollectionName(groupId: groupId)
        
        // Get current settlements
        var settlements = try await fetchSettlements(groupId: groupId)
        
        // Find and update the settlement
        if let index = settlements.firstIndex(where: { $0.id == settlementId }) {
            settlements[index].isSettled = true
            settlements[index].settledAt = Date()
            
            // Save updated settlements
            try await saveSettlements(groupId: groupId, settlements: settlements, collectionName: collectionName)
        }
    }

    func unmarkSettlement(groupId: String, settlementId: String) async throws {
        let collectionName = try await getGroupCollectionName(groupId: groupId)
        
        var settlements = try await fetchSettlements(groupId: groupId)
        
        if let index = settlements.firstIndex(where: { $0.id == settlementId }) {
            settlements[index].isSettled = false
            settlements[index].settledAt = nil
            
            try await saveSettlements(groupId: groupId, settlements: settlements, collectionName: collectionName)
        }
    }

    func listenToGroupExpenses(groupId: String, completion: @escaping ([GroupExpense]) -> Void) -> ListenerRegistration {
        print("🎧 Setting up expense listener for group: \(groupId)")
        
        // Create a container to hold the listener reference
        class ListenerContainer {
            var listener: ListenerRegistration?
        }
        let container = ListenerContainer()
        
        Task {
            do {
                let collectionName = try await getGroupCollectionName(groupId: groupId)
                print("🎧 Listener using collection: \(collectionName)")
                
                await MainActor.run {
                    container.listener = db.collection(collectionName)
                        .document(groupId)
                        .collection("expenses")
                        .addSnapshotListener { snapshot, error in
                            if let error = error {
                                print("❌ Error in expense listener: \(error)")
                                return
                            }
                            
                            guard let documents = snapshot?.documents else {
                                print("⚠️ No documents in snapshot")
                                completion([])
                                return
                            }
                            
                            print("📦 Received \(documents.count) expense documents")
                            
                            let decoder = Firestore.Decoder()
                            let expenses = documents.compactMap { doc -> GroupExpense? in
                                try? decoder.decode(GroupExpense.self, from: doc.data())
                            }.sorted { $0.date > $1.date }
                            
                            print("✅ Decoded \(expenses.count) expenses")
                            completion(expenses)
                        }
                    print("✅ Listener attached successfully")
                }
            } catch {
                print("❌ Error setting up expense listener: \(error)")
                completion([])
            }
        }
        
        return DummyListenerRegistration(removeHandler: {
            print("🔇 Removing expense listener")
            container.listener?.remove()
        })
    }

    // MARK: - Dummy Listener Registration
    private class DummyListenerRegistration: NSObject, ListenerRegistration {
        private let removeHandler: () -> Void
        
        init(removeHandler: @escaping () -> Void) {
            self.removeHandler = removeHandler
            super.init()
        }
        
        func remove() {
            removeHandler()
        }
    }

    // MARK: - Helper Functions

    /// Determines which collection a group belongs to (groupPlans or multiCityGroupPlans)
    private func getGroupCollectionName(groupId: String) async throws -> String {
        print("🔍 Searching for group: \(groupId)")
        
        // Check regular groups first
        let regularDoc = try await db.collection("groupPlans").document(groupId).getDocument()
        if regularDoc.exists {
            print("✅ Found in groupPlans")
            return "groupPlans"
        }
        
        // Check multi-city groups
        let multiCityDoc = try await db.collection("multiCityGroupPlans").document(groupId).getDocument()
        if multiCityDoc.exists {
            print("✅ Found in multiCityGroupPlans")
            return "multiCityGroupPlans"
        }
        
        print("❌ Group not found in any collection")
        throw NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
    }

    /// Gets members from either type of group
    private func getGroupMembers(groupId: String, collectionName: String) async throws -> [GroupMember] {
        let document = try await db.collection(collectionName).document(groupId).getDocument()
        
        guard let data = document.data() else {
            throw NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
        }
        
        let decoder = Firestore.Decoder()
        
        if collectionName == "groupPlans" {
            let group = try decoder.decode(GroupPlan.self, from: data)
            return group.members
        } else {
            let group = try decoder.decode(MultiCityGroupPlan.self, from: data)
            return group.members
        }
    }
    
    func calculateSettlements(expenses: [GroupExpense], members: [GroupMember]) -> [Settlement] {
        var balanceMap: [String: Double] = [:]
        
        for member in members {
            balanceMap[member.email] = 0
        }
        
        for expense in expenses {
            let shareAmount = expense.amount / Double(expense.splitBetween.count)
            balanceMap[expense.paidBy, default: 0] += expense.amount
            for person in expense.splitBetween {
                balanceMap[person, default: 0] -= shareAmount
            }
        }
        
        var creditors = balanceMap.filter { $0.value > 0.01 }
            .map { (person: $0.key, amount: $0.value) }
        creditors.sort {
            $0.amount == $1.amount ? $0.person < $1.person : $0.amount > $1.amount
        }
        
        var debtors = balanceMap.filter { $0.value < -0.01 }
            .map { (person: $0.key, amount: abs($0.value)) }
        debtors.sort {
            $0.amount == $1.amount ? $0.person < $1.person : $0.amount > $1.amount
        }
        
        var settlements: [Settlement] = []
        var i = 0, j = 0
        
        while i < creditors.count && j < debtors.count {
            let amountToSettle = min(creditors[i].amount, debtors[j].amount)
            
            settlements.append(Settlement(
                from: debtors[j].person,
                to: creditors[i].person,
                amount: amountToSettle
            ))
            
            creditors[i].amount -= amountToSettle
            debtors[j].amount -= amountToSettle
            
            if creditors[i].amount < 0.01 { i += 1 }
            if debtors[j].amount < 0.01 { j += 1 }
        }
        
        return settlements
    }

    
    
    

    
    /// Listen to a specific group in real-time
    func listenToGroup(groupId: String, completion: @escaping (GroupPlan?) -> Void) -> ListenerRegistration {
        let listener = db.collection("groupPlans")
            .document(groupId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to group: \(error)")
                    completion(nil)
                    return
                }
                
                guard let data = snapshot?.data() else {
                    completion(nil)
                    return
                }
                
                let decoder = Firestore.Decoder()
                let group = try? decoder.decode(GroupPlan.self, from: data)
                completion(group)
            }
        
        return listener
    }
}

struct StyledTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(10)
    }
}
