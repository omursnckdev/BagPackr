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

@main
struct TravelItineraryApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        FirebaseApp.configure()
        GMSServices.provideAPIKey("AIzaSyC5wDKS2_3NMA8mxKhEFzktmiPCY4atE10")
        GMSPlacesClient.provideAPIKey("AIzaSyC5wDKS2_3NMA8mxKhEFzktmiPCY4atE10")
        MobileAds.shared.start() 

    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
    }
}

// MARK: - Authentication View
struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 15) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .blur(radius: 20)
                        
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 70))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Text("Travel Itinerary")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Plan your perfect journey")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                VStack(spacing: 20) {
                    TextField("", text: $email, prompt: Text("Email").foregroundColor(.gray))
                        .textFieldStyle(GlassTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("", text: $password, prompt: Text("Password").foregroundColor(.gray))
                        .textFieldStyle(GlassTextFieldStyle())
                    
                    Button(action: handleAuth) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(isSignUp ? "Sign Up" : "Log In")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    }
                    .disabled(isLoading)
                    
                    Button(action: { withAnimation { isSignUp.toggle() } }) {
                        Text(isSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.white.opacity(0.15))
                        .blur(radius: 1)
                )
                .padding(.horizontal, 30)
                
                Spacer()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleAuth() {
        isLoading = true
        Task {
            do {
                if isSignUp {
                    try await authViewModel.signUp(email: email, password: password)
                } else {
                    try await authViewModel.signIn(email: email, password: password)
                }
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
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
            
            ItineraryListView(viewModel: itineraryListViewModel)
                .tabItem {
                    Label("My Plans", systemImage: "list.bullet")
                }
            
            GroupPlansView()
                .tabItem {
                    Label("Groups", systemImage: "person.3.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .accentColor(.blue)
    }
}

// MARK: - Create Itinerary View
struct CreateItineraryView: View {
    @StateObject private var viewModel = CreateItineraryViewModel()
    @ObservedObject var itineraryListViewModel: ItineraryListViewModel
    @State private var showMapPicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        ModernCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Location", systemImage: "mappin.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Button(action: { showMapPicker = true }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(viewModel.selectedLocation?.name ?? "Select Location")
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                            
                                            if viewModel.selectedLocation != nil {
                                                Text("Tap to change")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
         
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.blue)
                                    }
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        
                        ModernCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Duration", systemImage: "calendar")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                HStack {
                                    Text("\(viewModel.duration)")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(.blue)
                                    
                                    Text("days")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                    
                                    VStack(spacing: 8) {
                                        Button(action: { viewModel.duration = min(14, viewModel.duration + 1) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Button(action: { viewModel.duration = max(1, viewModel.duration - 1) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Budget Estimation
                        ModernCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Budget per Day", systemImage: "dollarsign.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                HStack {
                                    Text("$\(Int(viewModel.budgetPerDay))")
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.green)
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing) {
                                        Text("Total: $\(Int(viewModel.budgetPerDay * Double(viewModel.duration)))")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("Budget range")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Slider(value: $viewModel.budgetPerDay, in: 50...500, step: 10)
                                    .accentColor(.green)
                                
                                HStack {
                                    Text("$50")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("Budget")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("$500")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        ModernCard {
                            VStack(alignment: .leading, spacing: 15) {
                                Label("Select Interests", systemImage: "star.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                FlowLayout(spacing: 10) {
                                    ForEach(viewModel.builtInInterests, id: \.self) { interest in
                                        EnhancedInterestChip(
                                            title: interest,
                                            isSelected: viewModel.selectedInterests.contains(interest),
                                            action: { withAnimation(.spring()) { viewModel.toggleInterest(interest) } }
                                        )
                                    }
                                }
                            }
                        }
                        
                        ModernCard {
                            VStack(alignment: .leading, spacing: 15) {
                                Label("Custom Interests", systemImage: "plus.square.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                HStack {
                                    TextField("e.g., Temple, Sushi, Kebab", text: $viewModel.customInterestInput)
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(10)
                                    
                                    Button(action: { withAnimation(.spring()) { viewModel.addCustomInterest() } }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                if !viewModel.customInterests.isEmpty {
                                    FlowLayout(spacing: 10) {
                                        ForEach(viewModel.customInterests, id: \.self) { interest in
                                            EnhancedInterestChip(
                                                title: interest,
                                                isSelected: viewModel.selectedInterests.contains(interest),
                                                isCustom: true,
                                                action: { withAnimation(.spring()) { viewModel.toggleInterest(interest) } },
                                                onRemove: { withAnimation(.spring()) { viewModel.removeCustomInterest(interest) } }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        
                        Button(action: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                  AdManager.shared.showAd()
                              }
                            viewModel.generateItinerary(itineraryListViewModel: itineraryListViewModel)
                            
                          
                        }) {
                            HStack {
                                if viewModel.isGenerating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Creating your journey...")
                                        .fontWeight(.semibold)
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Generate Itinerary")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: viewModel.canGenerate ? [Color.blue, Color.purple] : [Color.gray, Color.gray],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .shadow(color: viewModel.canGenerate ? Color.blue.opacity(0.4) : Color.clear, radius: 10, x: 0, y: 5)
                        }
                        .disabled(!viewModel.canGenerate || viewModel.isGenerating)
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Itinerary")
            .sheet(isPresented: $showMapPicker) {
                MapPickerView(selectedLocation: $viewModel.selectedLocation)
            }
            .sheet(item: $viewModel.generatedItinerary) { itinerary in
                ItineraryResultView(itinerary: itinerary, itineraryListViewModel: itineraryListViewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
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
                    .fill(Color.white)
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
            Text(title)
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
                .fill(isSelected ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [.gray.opacity(0.2), .gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
        )
        .foregroundColor(isSelected ? .white : .primary)
        .shadow(color: isSelected ? Color.blue.opacity(0.3) : Color.clear, radius: 5, x: 0, y: 3)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .onTapGesture(perform: action)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Map Picker View
struct MapPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLocation: LocationData?
    @State private var mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 20.0, longitude: 0.0)
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var placeName: String = ""
    @State private var isLocationLocked = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                GoogleMapView(
                    center: $mapCenter,
                    selectedCoordinate: $selectedCoordinate,
                    placeName: $placeName,
                    isLocationLocked: $isLocationLocked
                )
                .ignoresSafeArea()
                
                if selectedCoordinate != nil {
                    Button(action: confirmSelection) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Confirm: \(placeName)")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .padding()
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func confirmSelection() {
        if let coordinate = selectedCoordinate {
            selectedLocation = LocationData(
                name: placeName,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            dismiss()
        }
    }
}

struct GoogleMapView: UIViewRepresentable {
    @Binding var center: CLLocationCoordinate2D
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var placeName: String
    @Binding var isLocationLocked: Bool
    
    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: center.latitude, longitude: center.longitude, zoom: 2.0)
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.parent = self
        
        // Add/update marker for selected location
        if let coordinate = selectedCoordinate {
            mapView.clear()
            let marker = GMSMarker(position: coordinate)
            marker.icon = GMSMarker.markerImage(with: .systemBlue)
            marker.map = mapView
            
            // Animate to the selected location with appropriate zoom
            let camera = GMSCameraPosition.camera(withLatitude: coordinate.latitude, longitude: coordinate.longitude, zoom: 12.0)
            mapView.animate(to: camera)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        var marker: GMSMarker?
        
        init(_ parent: GoogleMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            // Don't allow map taps to override search selections
            guard !parent.isLocationLocked else { return }
            
            marker?.map = nil
            
            let newMarker = GMSMarker(position: coordinate)
            newMarker.icon = GMSMarker.markerImage(with: .systemBlue)
            newMarker.map = mapView
            marker = newMarker
            
            parent.selectedCoordinate = coordinate
            
            let geocoder = GMSGeocoder()
            geocoder.reverseGeocodeCoordinate(coordinate) { response, error in
                if let address = response?.firstResult() {
                    self.parent.placeName = address.locality ?? address.administrativeArea ?? "Selected Location"
                }
            }
        }
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

// MARK: - Itinerary Result View
struct ItineraryResultView: View {
    @Environment(\.dismiss) var dismiss
    let itinerary: Itinerary
    @ObservedObject var itineraryListViewModel: ItineraryListViewModel
    @State private var showShareSheet = false
    @State private var shareText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                Text(itinerary.location)
                                    .font(.title)
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                Label("\(itinerary.duration) Days", systemImage: "calendar")
                                Spacer()
                                Label("$\(Int(itinerary.budgetPerDay * Double(itinerary.duration)))", systemImage: "dollarsign.circle.fill")
                            }
                            .font(.subheadline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(itinerary.interests, id: \.self) { interest in
                                        Text(interest)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.white.opacity(0.3))
                                            .cornerRadius(15)
                                    }
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .padding()
                    }
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    ForEach(Array(itinerary.dailyPlans.enumerated()), id: \.element.id) { index, plan in
                        EnhancedDayPlanCard(
                            dayNumber: index + 1,
                            plan: plan,
                            location: itinerary.location,
                            itinerary: itinerary
                        )
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Your Itinerary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // FIX #3: Refresh list when dismissing
                        Task {
                            await itineraryListViewModel.loadItineraries()
                        }
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareItinerary) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [shareText])
            }
        }
    }
    
    private func shareItinerary() {
        shareText = generateShareText()
        showShareSheet = true
    }
    
    private func generateShareText() -> String {
        var text = "🌍 \(itinerary.location) - \(itinerary.duration) Day Itinerary\n\n"
        text += "📍 Interests: \(itinerary.interests.joined(separator: ", "))\n"
        text += "💰 Budget: $\(Int(itinerary.budgetPerDay * Double(itinerary.duration)))\n\n"
        
        for (index, plan) in itinerary.dailyPlans.enumerated() {
            text += "📅 Day \(index + 1):\n"
            for activity in plan.activities {
                text += "  • \(activity.time) - \(activity.name)\n"
                text += "    \(activity.description)\n"
                if activity.cost > 0 {
                    text += "    💵 $\(Int(activity.cost))\n"
                }
            }
            text += "\n"
        }
        
        text += "\nCreated with Travel Itinerary App ✈️"
        return text
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Enhanced Day Plan Card with Checklist & Navigation
struct EnhancedDayPlanCard: View {
    let dayNumber: Int
    let plan: DailyPlan
    let location: String
    let itinerary: Itinerary
    @State private var showMap = false
    @State private var completedActivities: Set<String> = []
    
    var dailyBudget: Double {
        plan.activities.reduce(0) { $0 + $1.cost }
    }
    
    var completionPercentage: Double {
        guard !plan.activities.isEmpty else { return 0 }
        return Double(completedActivities.count) / Double(plan.activities.count) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Day \(dayNumber)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("$\(Int(dailyBudget))")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text("\(completedActivities.count)/\(plan.activities.count) done")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Button(action: { showMap.toggle() }) {
                    Label(showMap ? "Hide" : "Map", systemImage: showMap ? "map.fill" : "map")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(15)
                }
            }
            .padding()
            .background(
                ZStack {
                    Color.blue.opacity(0.1)
                    
                    // Progress bar
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: geometry.size.width * (completionPercentage / 100))
                    }
                }
            )
            
            // Map View - FIX #2: Improved to show activity locations
            if showMap {
                ActivitiesMapView(
                    activities: plan.activities,
                    location: location,
                  
                )
                .frame(height: 250)
                .transition(.opacity)
            }
            
            // Activities with Checklist
            VStack(spacing: 0) {
                ForEach(Array(plan.activities.enumerated()), id: \.element.id) { index, activity in
                    EnhancedActivityRow(
                        activity: activity,
                        number: index + 1,
                        isCompleted: completedActivities.contains(activity.id),
                        onToggleComplete: {
                            withAnimation {
                                if completedActivities.contains(activity.id) {
                                    completedActivities.remove(activity.id)
                                } else {
                                    completedActivities.insert(activity.id)
                                }
                                // Save to Firestore
                                saveProgress()
                            }
                        },
                        onNavigate: {
                            openInMaps(activity: activity, location: location)
                        }
                    )
                    
                    if index < plan.activities.count - 1 {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
        .animation(.spring(), value: showMap)
        .onAppear {
            loadProgress()
        }
    }
    
    private func saveProgress() {
        Task {
            try? await FirestoreService.shared.updateItineraryProgress(
                itineraryId: itinerary.id,
                dayId: plan.id,
                completedActivities: Array(completedActivities)
            )
        }
    }
    
    private func loadProgress() {
        Task {
            if let progress = try? await FirestoreService.shared.getItineraryProgress(
                itineraryId: itinerary.id,
                dayId: plan.id
            ) {
                completedActivities = Set(progress)
            }
        }
    }
    
    private func openInMaps(activity: Activity, location: String) {
        let query = "\(activity.name), \(location)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Try Google Maps first
        if let url = URL(string: "comgooglemaps://?q=\(query)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "http://maps.google.com/?q=\(query)") {
            UIApplication.shared.open(url)
        } else {
            // Fallback to Apple Maps
            let coordinate = CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
            let placemark = MKPlacemark(coordinate: coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = activity.name
            mapItem.openInMaps(launchOptions: nil)
        }
    }
}

// Fixed ActivitiesMapView with proper marker display
struct ActivitiesMapView: UIViewRepresentable {
    let activities: [Activity]
    let location: String
    
    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: 0, longitude: 0, zoom: 12.0)
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        context.coordinator.mapView = mapView
        context.coordinator.geocodeAndPlaceMarkers()
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Update coordinator references
        context.coordinator.activities = activities
        context.coordinator.location = location
        context.coordinator.mapView = mapView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(activities: activities, location: location)
    }
    
    class Coordinator: NSObject {
        var activities: [Activity]
        var location: String
        var mapView: GMSMapView?
        
        init(activities: [Activity], location: String) {
            self.activities = activities
            self.location = location
        }
        
        func geocodeAndPlaceMarkers() {
            guard let mapView = mapView else { return }
            
            let placesClient = GMSPlacesClient.shared()
            var bounds = GMSCoordinateBounds()
            var markersPlaced = 0
            
            // First, get the city location to center the map
            placesClient.findAutocompletePredictions(fromQuery: location, filter: nil, sessionToken: nil) { predictions, error in
                if let cityPrediction = predictions?.first {
                    placesClient.fetchPlace(fromPlaceID: cityPrediction.placeID, placeFields: .coordinate, sessionToken: nil) { cityPlace, _ in
                        if let cityCoordinate = cityPlace?.coordinate {
                            // Now geocode each activity
                            for (index, activity) in self.activities.enumerated() {
                                let searchQuery = "\(activity.name), \(self.location)"
                                
                                placesClient.findAutocompletePredictions(fromQuery: searchQuery, filter: nil, sessionToken: nil) { predictions, error in
                                    if let prediction = predictions?.first {
                                        placesClient.fetchPlace(fromPlaceID: prediction.placeID, placeFields: .coordinate, sessionToken: nil) { place, error in
                                            if let coordinate = place?.coordinate {
                                                DispatchQueue.main.async {
                                                    self.addMarker(
                                                        at: coordinate,
                                                        for: activity,
                                                        number: index + 1,
                                                        to: mapView,
                                                        bounds: &bounds
                                                    )
                                                    markersPlaced += 1
                                                    
                                                    if markersPlaced == self.activities.count {
                                                        self.updateCamera(mapView: mapView, bounds: bounds)
                                                    }
                                                }
                                            } else {
                                                // Fallback: place marker near city center with offset
                                                DispatchQueue.main.async {
                                                    let offset = Double(index) * 0.01
                                                    let fallbackCoordinate = CLLocationCoordinate2D(
                                                        latitude: cityCoordinate.latitude + offset,
                                                        longitude: cityCoordinate.longitude + offset
                                                    )
                                                    self.addMarker(
                                                        at: fallbackCoordinate,
                                                        for: activity,
                                                        number: index + 1,
                                                        to: mapView,
                                                        bounds: &bounds
                                                    )
                                                    markersPlaced += 1
                                                    
                                                    if markersPlaced == self.activities.count {
                                                        self.updateCamera(mapView: mapView, bounds: bounds)
                                                    }
                                                }
                                            }
                                        }
                                    } else {
                                        // Fallback if no predictions
                                        DispatchQueue.main.async {
                                            let offset = Double(index) * 0.01
                                            let fallbackCoordinate = CLLocationCoordinate2D(
                                                latitude: cityCoordinate.latitude + offset,
                                                longitude: cityCoordinate.longitude + offset
                                            )
                                            self.addMarker(
                                                at: fallbackCoordinate,
                                                for: activity,
                                                number: index + 1,
                                                to: mapView,
                                                bounds: &bounds
                                            )
                                            markersPlaced += 1
                                            
                                            if markersPlaced == self.activities.count {
                                                self.updateCamera(mapView: mapView, bounds: bounds)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        private func addMarker(at coordinate: CLLocationCoordinate2D, for activity: Activity, number: Int, to mapView: GMSMapView, bounds: inout GMSCoordinateBounds) {
            let marker = GMSMarker()
            marker.position = coordinate
            marker.title = activity.name
            marker.snippet = "\(activity.time) • $\(Int(activity.cost))"
            marker.icon = markerIcon(for: number, type: activity.type)
            marker.map = mapView
            bounds = bounds.includingCoordinate(coordinate)
        }
        
        private func updateCamera(mapView: GMSMapView, bounds: GMSCoordinateBounds) {
            let update = GMSCameraUpdate.fit(bounds, withPadding: 50)
            mapView.animate(with: update)
        }
        
        private func markerIcon(for number: Int, type: String) -> UIImage {
            let size = CGSize(width: 40, height: 40)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                let color = colorForActivityType(type)
                color.setFill()
                
                let circle = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
                circle.fill()
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 18),
                    .foregroundColor: UIColor.white
                ]
                
                let text = "\(number)"
                let textSize = text.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                
                text.draw(in: textRect, withAttributes: attributes)
            }
        }
        
        private func colorForActivityType(_ type: String) -> UIColor {
            switch type.lowercased() {
            case "beach", "beaches": return .systemCyan
            case "nightlife": return .systemPurple
            case "restaurant", "restaurants": return .systemOrange
            case "museum", "museums": return .systemBrown
            default: return .systemBlue
            }
        }
    }
}

// MARK: - Enhanced Activity Row with Checklist & Navigation
struct EnhancedActivityRow: View {
    let activity: Activity
    let number: Int
    let isCompleted: Bool
    let onToggleComplete: () -> Void
    let onNavigate: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: onToggleComplete) {
                ZStack {
                    Circle()
                        .strokeBorder(isCompleted ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Number Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                colorForType(activity.type).opacity(isCompleted ? 0.4 : 0.8),
                                colorForType(activity.type).opacity(isCompleted ? 0.3 : 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Text("\(number)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(activity.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .strikethrough(isCompleted)
                    .foregroundColor(isCompleted ? .gray : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Image(systemName: iconForType(activity.type))
                        .foregroundColor(colorForType(activity.type))
                        .font(.caption)
                    
                    Text(activity.type)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                
                Text(activity.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack {
                    Label(activity.time, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Label(String(format: "%.1f km", activity.distance), systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if activity.cost > 0 {
                        Label("$\(Int(activity.cost))", systemImage: "dollarsign.circle")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    // Navigate Button
                    Button(action: onNavigate) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            Text("Navigate")
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .opacity(isCompleted ? 0.6 : 1.0)
    }
    
    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "beach", "beaches": return "beach.umbrella.fill"
        case "nightlife": return "moon.stars.fill"
        case "restaurant", "restaurants": return "fork.knife"
        case "museum", "museums": return "building.columns.fill"
        case "temple": return "building.fill"
        default: return "mappin.circle.fill"
        }
    }
    
    private func colorForType(_ type: String) -> Color {
        switch type.lowercased() {
        case "beach", "beaches": return .cyan
        case "nightlife": return .purple
        case "restaurant", "restaurants": return .orange
        case "museum", "museums": return .brown
        default: return .blue
        }
    }
}

// MARK: - Itinerary List View
struct ItineraryListView: View {
    @ObservedObject var viewModel: ItineraryListViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.itineraries.isEmpty {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        }
                        
                        Text("No itineraries yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Create your first travel plan and start exploring!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    List {
                        ForEach(viewModel.itineraries) { itinerary in
                            NavigationLink(destination: ItineraryDetailView(itinerary: itinerary, viewModel: viewModel)) {
                                EnhancedItineraryListRow(itinerary: itinerary)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: deleteItineraries)
                    }
                    .listStyle(.plain)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("My Itineraries")
            .onAppear {
                Task {
                    await viewModel.loadItineraries()
                }
            }
            .refreshable {
                await viewModel.loadItineraries()
            }
        }
    }
    
    private func deleteItineraries(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let itinerary = viewModel.itineraries[index]
                try? await FirestoreService.shared.deleteItinerary(itinerary.id)
            }
            await viewModel.loadItineraries()
        }
    }
}

struct EnhancedItineraryListRow: View {
    let itinerary: Itinerary
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "airplane.departure")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(itinerary.location)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Label("\(itinerary.duration) days", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Label("$\(Int(itinerary.budgetPerDay * Double(itinerary.duration)))", systemImage: "dollarsign.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                HStack {
                    ForEach(itinerary.interests.prefix(3), id: \.self) { interest in
                        Text(interest)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    if itinerary.interests.count > 3 {
                        Text("+\(itinerary.interests.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            if itinerary.isShared {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                    .font(.caption)
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Itinerary Detail View
struct ItineraryDetailView: View {
    let itinerary: Itinerary
    let viewModel: ItineraryListViewModel
    @State private var showEditSheet = false
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var showGroupShare = false
    @State private var shareText = ""
    @Environment(\.dismiss) var dismiss
    
    var totalSpent: Double {
        itinerary.dailyPlans.reduce(0) { total, plan in
            total + plan.activities.reduce(0) { $0 + $1.cost }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                            Text(itinerary.location)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            if itinerary.isShared {
                                Image(systemName: "person.2.fill")
                                    .font(.title3)
                            }
                        }
                        
                        HStack {
                            Label("\(itinerary.duration) Days", systemImage: "calendar")
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Budget: $\(Int(itinerary.budgetPerDay * Double(itinerary.duration)))")
                                Text("Spent: $\(Int(totalSpent))")
                                    .font(.caption)
                            }
                        }
                        .font(.subheadline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(itinerary.interests, id: \.self) { interest in
                                    Text(interest)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.3))
                                        .cornerRadius(15)
                                }
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                .cornerRadius(20)
                .padding(.horizontal)
                
                // Action Buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ActionButton(icon: "pencil", title: "Edit", color: .blue) {
                            showEditSheet = true
                        }
                        
                        ActionButton(icon: "square.and.arrow.up", title: "Share", color: .green) {
                            shareItinerary()
                        }
                        
                        ActionButton(icon: "person.2.fill", title: "Group", color: .purple) {
                            showGroupShare = true
                        }
                        
                        ActionButton(icon: "trash", title: "Delete", color: .red) {
                            showDeleteAlert = true
                        }
                    }
                    .padding(.horizontal)
                }
                
                ForEach(Array(itinerary.dailyPlans.enumerated()), id: \.element.id) { index, plan in
                    EnhancedDayPlanCard(
                        dayNumber: index + 1,
                        plan: plan,
                        location: itinerary.location,
                        itinerary: itinerary
                    )
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Itinerary Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditSheet) {
            EditItineraryView(itinerary: itinerary, viewModel: viewModel)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareText])
        }
        .sheet(isPresented: $showGroupShare) {
            GroupShareView(itinerary: itinerary)
        }
        .alert("Delete Itinerary", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteItinerary()
            }
        } message: {
            Text("Are you sure you want to delete this itinerary? This action cannot be undone.")
        }
    }
    
    private func shareItinerary() {
        shareText = generateShareText()
        showShareSheet = true
    }
    
    private func generateShareText() -> String {
        var text = "🌍 \(itinerary.location) - \(itinerary.duration) Day Itinerary\n\n"
        text += "📍 Interests: \(itinerary.interests.joined(separator: ", "))\n"
        text += "💰 Budget: $\(Int(itinerary.budgetPerDay * Double(itinerary.duration)))\n\n"
        
        for (index, plan) in itinerary.dailyPlans.enumerated() {
            text += "📅 Day \(index + 1):\n"
            for activity in plan.activities {
                text += "  • \(activity.time) - \(activity.name)\n"
                text += "    \(activity.description)\n"
                if activity.cost > 0 {
                    text += "    💵 $\(Int(activity.cost))\n"
                }
            }
            text += "\n"
        }
        
        text += "\nCreated with Travel Itinerary App ✈️"
        return text
    }
    
    private func deleteItinerary() {
        Task {
            try? await FirestoreService.shared.deleteItinerary(itinerary.id)
            await viewModel.loadItineraries()
            dismiss()
        }
    }
}

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
            .frame(width: 70, height: 70)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(15)
        }
    }
}

// MARK: - Group Plans View
struct GroupPlansView: View {
    @StateObject private var viewModel = GroupPlansViewModel()
    @State private var showCreateGroup = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.groupPlans.isEmpty {
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
                } else {
                    List {
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
                    .listStyle(.plain)
                    .background(Color(.systemGroupedBackground))
                }
            }
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
            .onAppear {
                Task {
                    await viewModel.loadGroupPlans()
                }
            }
            .refreshable {
                await viewModel.loadGroupPlans()
            }
        }
    }
    
    private func deleteGroups(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let group = viewModel.groupPlans[index]
                try? await FirestoreService.shared.deleteGroup(group.id)
            }
            await viewModel.loadGroupPlans()
        }
    }
}

struct GroupPlanRow: View {
    let group: GroupPlan
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(group.itinerary.location)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack {
                    Label("\(group.members.count) members", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.purple)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text(group.createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

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

// MARK: - Create Group View
struct CreateGroupView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: GroupPlansViewModel
    @State private var selectedItinerary: Itinerary?
    @State private var groupName = ""
    @State private var memberEmails: [String] = [""]
    @StateObject private var itineraryViewModel = ItineraryListViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Itinerary")) {
                    Picker("Itinerary", selection: $selectedItinerary) {
                        Text("Select...").tag(nil as Itinerary?)

                        ForEach(itineraryViewModel.itineraries) { itinerary in
                            Text("\(itinerary.location) - \(itinerary.duration) days")
                                .tag(itinerary as Itinerary?)
                        }
                    }
                }

                
                Section(header: Text("Group Name")) {
                    TextField("Enter group name", text: $groupName)
                }
                
                Section(header: Text("Invite Members")) {
                    ForEach(0..<memberEmails.count, id: \.self) { index in
                        HStack {
                            TextField("Email", text: $memberEmails[index])
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                            
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
        guard let itinerary = selectedItinerary else { return }
        let validEmails = memberEmails.filter { !$0.isEmpty }
        
        Task {
            try? await FirestoreService.shared.createGroupPlan(
                name: groupName,
                itinerary: itinerary,
                memberEmails: validEmails
            )
            await viewModel.loadGroupPlans()
            dismiss()
        }
    }
}

struct GroupDetailView: View {
    let group: GroupPlan
    @State private var showAddMember = false
    @State private var newMemberEmail = ""
    @State private var isAddingMember = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var refreshedGroup: GroupPlan?
    
    var currentGroup: GroupPlan {
        refreshedGroup ?? group
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Group Header
                ZStack {
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .font(.title)
                            Text(currentGroup.name)
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        
                        Text(currentGroup.itinerary.location)
                            .font(.title3)
                        
                        Text("\(currentGroup.members.count) members • Created \(currentGroup.createdAt, style: .date)")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                .cornerRadius(20)
                .padding(.horizontal)
                
                // Members List
                ModernCard {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Label("Members", systemImage: "person.2.fill")
                                .font(.headline)
                                .foregroundColor(.purple)
                            
                            Spacer()
                            
                            Button(action: { showAddMember = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                        
                        ForEach(currentGroup.members, id: \.email) { member in
                            HStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(String(member.email.prefix(1).uppercased()))
                                            .foregroundColor(.purple)
                                    )
                                
                                VStack(alignment: .leading) {
                                    Text(member.email)
                                        .font(.subheadline)
                                    
                                    if member.isOwner {
                                        Text("Owner")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Itinerary
                Text("Trip Details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                ForEach(Array(currentGroup.itinerary.dailyPlans.enumerated()), id: \.element.id) { index, plan in
                    EnhancedDayPlanCard(
                        dayNumber: index + 1,
                        plan: plan,
                        location: currentGroup.itinerary.location,
                        itinerary: currentGroup.itinerary
                    )
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(currentGroup.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddMember) {
            NavigationView {
                Form {
                    Section(header: Text("Add Member")) {
                        TextField("Email address", text: $newMemberEmail)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                    }
                    
                    Section {
                        Button(action: addMember) {
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
                            showAddMember = false
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func addMember() {
        let email = newMemberEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }
        
        isAddingMember = true
        
        Task {
            do {
                try await FirestoreService.shared.addMemberToGroup(groupId: currentGroup.id, memberEmail: email)
                
                // Refresh the group data
                if let updated = try? await FirestoreService.shared.getGroupById(groupId: currentGroup.id) {
                    refreshedGroup = updated
                }
                
                newMemberEmail = ""
                showAddMember = false
                isAddingMember = false
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isAddingMember = false
            }
        }
    }
}

// MARK: - Edit Itinerary View
struct EditItineraryView: View {
    @Environment(\.dismiss) var dismiss
    let itinerary: Itinerary
    let viewModel: ItineraryListViewModel
    
    @State private var editedDuration: Int
    @State private var editedBudget: Double
    @State private var editedInterests: Set<String>
    @State private var customInterestInput = ""
    @State private var customInterests: [String]
    @State private var isRegenerating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    static let builtInInterests = [
        "Beaches", "Nightlife", "Restaurants", "Museums",
        "Shopping", "Parks", "Adventure Sports", "Historical Sites",
        "Art Galleries", "Local Markets", "Street Food", "Temples",
        "Architecture", "Photography", "Hiking", "Water Sports",
        "Cafes", "Live Music", "Theater", "Festivals"
    ]
    
    init(itinerary: Itinerary, viewModel: ItineraryListViewModel) {
        self.itinerary = itinerary
        self.viewModel = viewModel
        _editedDuration = State(initialValue: itinerary.duration)
        _editedBudget = State(initialValue: itinerary.budgetPerDay)
        _editedInterests = State(initialValue: Set(itinerary.interests))
        _customInterests = State(initialValue: itinerary.interests.filter { !Self.builtInInterests.contains($0) })
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ModernCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Location", systemImage: "mappin.circle.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Text(itinerary.location)
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Location cannot be changed")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    ModernCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Duration", systemImage: "calendar")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            HStack {
                                Text("\(editedDuration)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.blue)
                                
                                Text("days")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                VStack(spacing: 8) {
                                    Button(action: { editedDuration = min(14, editedDuration + 1) }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Button(action: { editedDuration = max(1, editedDuration - 1) }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    
                    ModernCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Budget per Day", systemImage: "dollarsign.circle.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Text("$\(Int(editedBudget))")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.green)
                            
                            Slider(value: $editedBudget, in: 50...500, step: 10)
                                .accentColor(.green)
                        }
                    }
                    
                    ModernCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Label("Edit Interests", systemImage: "star.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            FlowLayout(spacing: 10) {
                                ForEach(Self.builtInInterests, id: \.self) { interest in
                                    EnhancedInterestChip(
                                        title: interest,
                                        isSelected: editedInterests.contains(interest),
                                        action: { toggleInterest(interest) }
                                    )
                                }
                            }
                            
                            if !customInterests.isEmpty {
                                Divider()
                                
                                FlowLayout(spacing: 10) {
                                    ForEach(customInterests, id: \.self) { interest in
                                        EnhancedInterestChip(
                                            title: interest,
                                            isSelected: editedInterests.contains(interest),
                                            isCustom: true,
                                            action: { toggleInterest(interest) },
                                            onRemove: { removeCustomInterest(interest) }
                                        )
                                    }
                                }
                            }
                            
                            HStack {
                                TextField("Add custom interest", text: $customInterestInput)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                
                                Button(action: addCustomInterest) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    Button(action: regenerateItinerary) {
                        HStack {
                            if isRegenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Regenerating...")
                                    .fontWeight(.semibold)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                Text("Regenerate Itinerary")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .disabled(isRegenerating || editedInterests.isEmpty)
                    .padding(.horizontal)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Itinerary")
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
    
    private func toggleInterest(_ interest: String) {
        if editedInterests.contains(interest) {
            editedInterests.remove(interest)
        } else {
            editedInterests.insert(interest)
        }
    }
    
    private func addCustomInterest() {
        let trimmed = customInterestInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        customInterests.append(trimmed)
        editedInterests.insert(trimmed)
        customInterestInput = ""
    }
    
    private func removeCustomInterest(_ interest: String) {
        customInterests.removeAll { $0 == interest }
        editedInterests.remove(interest)
    }
    
    private func regenerateItinerary() {
        isRegenerating = true
        
        Task {
            do {
                let location = LocationData(
                    name: itinerary.location,
                    latitude: 0,
                    longitude: 0
                )
                
                let newItinerary = try await GeminiService.shared.generateItinerary(
                    location: location,
                    duration: editedDuration,
                    interests: Array(editedInterests),
                    budgetPerDay: editedBudget
                )
                
                let updatedItinerary = Itinerary(
                    id: itinerary.id,
                    userId: itinerary.userId,
                    location: itinerary.location,
                    duration: editedDuration,
                    interests: Array(editedInterests),
                    dailyPlans: newItinerary.dailyPlans,
                    budgetPerDay: editedBudget,
                    createdAt: itinerary.createdAt
                )
                
                try await FirestoreService.shared.updateItinerary(updatedItinerary)
                await viewModel.loadItineraries()
                
                isRegenerating = false
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isRegenerating = false
            }
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSignOutAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        ModernCard {
                            HStack(spacing: 20) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(authViewModel.currentUser?.email?.components(separatedBy: "@").first ?? "User")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Text(authViewModel.currentUser?.email ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    Text("Travel Enthusiast")
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(
                                            LinearGradient(
                                                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(10)
                                }
                                
                                Spacer()
                            }
                            .padding()
                        }
                        
                        ModernCard {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("About")
                                    .font(.headline)
                                
                                InfoRow(icon: "airplane.departure", title: "Travel Itinerary", subtitle: "v1.0.0")
                                InfoRow(icon: "sparkles", title: "AI Powered", subtitle: "Gemini Integration")
                                InfoRow(icon: "map.fill", title: "Google Maps", subtitle: "Location Services")
                                InfoRow(icon: "person.3.fill", title: "Group Plans", subtitle: "Collaborate with friends")
                            }
                        }
                        
                        Button(action: { showSignOutAlert = true }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                Text("Sign Out")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(15)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

// MARK: - Models
struct LocationData: Codable {
    let name: String
    let latitude: Double
    let longitude: Double
}

struct Itinerary: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let userId: String
    let location: String
    let duration: Int
    let interests: [String]
    let dailyPlans: [DailyPlan]
    let budgetPerDay: Double
    let createdAt: Date
    var isShared: Bool = false
    
    init(id: String = UUID().uuidString,
         userId: String,
         location: String,
         duration: Int,
         interests: [String],
         dailyPlans: [DailyPlan],
         budgetPerDay: Double = 150,
         createdAt: Date = Date(),
         isShared: Bool = false) {
        self.id = id
        self.userId = userId
        self.location = location
        self.duration = duration
        self.interests = interests
        self.dailyPlans = dailyPlans
        self.budgetPerDay = budgetPerDay
        self.createdAt = createdAt
        self.isShared = isShared
    }
    
    static func == (lhs: Itinerary, rhs: Itinerary) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct DailyPlan: Identifiable, Codable {
    let id: String
    let day: Int
    let activities: [Activity]
    
    init(id: String = UUID().uuidString, day: Int, activities: [Activity]) {
        self.id = id
        self.day = day
        self.activities = activities
    }
}

struct Activity: Identifiable, Codable {
    let id: String
    let name: String
    let type: String
    let description: String
    let time: String
    let distance: Double
    let cost: Double
    var coordinate: CLLocationCoordinate2D?
    
    init(id: String = UUID().uuidString, name: String, type: String, description: String, time: String, distance: Double, cost: Double = 0, coordinate: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.time = time
        self.distance = distance
        self.cost = cost
        self.coordinate = coordinate
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, description, time, distance, cost
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        description = try container.decode(String.self, forKey: .description)
        time = try container.decode(String.self, forKey: .time)
        distance = try container.decode(Double.self, forKey: .distance)
        cost = try container.decode(Double.self, forKey: .cost)
        coordinate = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(description, forKey: .description)
        try container.encode(time, forKey: .time)
        try container.encode(distance, forKey: .distance)
        try container.encode(cost, forKey: .cost)
    }
}

struct GroupPlan: Identifiable, Codable {
    let id: String
    let name: String
    let itinerary: Itinerary
    let members: [GroupMember]
    let memberEmails: [String] // For Firestore querying
    let createdAt: Date
    
    init(id: String = UUID().uuidString, name: String, itinerary: Itinerary, members: [GroupMember], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.itinerary = itinerary
        self.members = members
        self.memberEmails = members.map { $0.email } // Extract emails for querying
        self.createdAt = createdAt
    }
}

struct GroupMember: Codable {
    let email: String
    let isOwner: Bool
    
    init(email: String, isOwner: Bool = false) {
        self.email = email
        self.isOwner = isOwner
    }
}

// MARK: - View Models
import FirebaseAuth
import FirebaseFirestore
import GoogleGenerativeAI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    init() {
        checkAuth()
    }
    
    func checkAuth() {
        if let user = Auth.auth().currentUser {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        self.currentUser = result.user
        self.isAuthenticated = true
    }
    
    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        self.currentUser = result.user
        self.isAuthenticated = true
    }
    
    func signOut() {
        try? Auth.auth().signOut()
        self.currentUser = nil
        self.isAuthenticated = false
    }
}

@MainActor
class CreateItineraryViewModel: ObservableObject {
    @Published var selectedLocation: LocationData?
    @Published var duration = 3
    @Published var budgetPerDay: Double = 150
    @Published var selectedInterests: Set<String> = []
    @Published var customInterestInput = ""
    @Published var customInterests: [String] = []
    @Published var isGenerating = false
    @Published var generatedItinerary: Itinerary?
    @Published var showError = false
    @Published var errorMessage = ""
    
    let builtInInterests = [
        "Beaches", "Nightlife", "Restaurants", "Museums",
        "Shopping", "Parks", "Adventure Sports", "Historical Sites",
        "Art Galleries", "Local Markets", "Street Food", "Temples",
        "Architecture", "Photography", "Hiking", "Water Sports",
        "Cafes", "Live Music", "Theater", "Festivals"
    ]
    
    var canGenerate: Bool {
        selectedLocation != nil && !selectedInterests.isEmpty
    }
    
    func toggleInterest(_ interest: String) {
        if selectedInterests.contains(interest) {
            selectedInterests.remove(interest)
        } else {
            selectedInterests.insert(interest)
        }
    }
    
    func addCustomInterest() {
        let trimmed = customInterestInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        customInterests.append(trimmed)
        selectedInterests.insert(trimmed)
        customInterestInput = ""
    }
    
    func removeCustomInterest(_ interest: String) {
        customInterests.removeAll { $0 == interest }
        selectedInterests.remove(interest)
    }
    
    // FIX #3: Pass itineraryListViewModel to refresh the list
    func generateItinerary(itineraryListViewModel: ItineraryListViewModel) {
        guard let location = selectedLocation else { return }
        
        isGenerating = true
        
        Task {
            do {
                let itinerary = try await GeminiService.shared.generateItinerary(
                    location: location,
                    duration: duration,
                    interests: Array(selectedInterests),
                    budgetPerDay: budgetPerDay
                )
                
                try await FirestoreService.shared.saveItinerary(itinerary)
                
                // FIX #3: Reload the list after saving
                await itineraryListViewModel.loadItineraries()
                
                generatedItinerary = itinerary
                isGenerating = false
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isGenerating = false
            }
        }
    }
}

@MainActor
class ItineraryListViewModel: ObservableObject {
    @Published var itineraries: [Itinerary] = []
    
    func loadItineraries() async {
        do {
            itineraries = try await FirestoreService.shared.fetchItineraries()
        } catch {
            print("Error loading itineraries: \(error)")
        }
    }
}

@MainActor
class GroupPlansViewModel: ObservableObject {
    @Published var groupPlans: [GroupPlan] = []
    
    func loadGroupPlans() async {
        do {
            groupPlans = try await FirestoreService.shared.fetchGroupPlans()
        } catch {
            print("Error loading group plans: \(error)")
        }
    }
}

// MARK: - Services
class GeminiService {
    static let shared = GeminiService()
    private let model: GenerativeModel
    
    private init() {
        model = GenerativeModel(name: "gemini-2.5-flash", apiKey: "AIzaSyAoUnnvwIeBbxYo0RncGtteOJCaViLwJRI")
    }
    
    func generateItinerary(location: LocationData, duration: Int, interests: [String], budgetPerDay: Double) async throws -> Itinerary {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let prompt = """
        Create a \(duration)-day itinerary for \(location.name).
        
        Interests: \(interests.joined(separator: ", "))
        Daily budget: $\(Int(budgetPerDay))
        
        Rules:
        - 4-5 activities per day with variety
        - Real place names in \(location.name)
        - Include time (e.g., "09:00 AM - 11:00 AM"), distance (km), and cost ($)
        - Daily costs should total ~$\(Int(budgetPerDay))
        - Don't repeat similar activities
        
        Return ONLY this JSON (no markdown):
        {
          "dailyPlans": [
            {
              "day": 1,
              "activities": [
                {
                  "name": "Place Name",
                  "type": "Beach/Restaurant/Museum/etc",
                  "description": "Brief description",
                  "time": "09:00 AM - 11:00 AM",
                  "distance": 2.5,
                  "cost": 25.0
                }
              ]
            }
          ]
        }
        """
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw NSError(domain: "Gemini", code: 500, userInfo: [NSLocalizedDescriptionKey: "No response from Gemini"])
        }
        
        let cleanedText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedText.data(using: .utf8) else {
            throw NSError(domain: "Parsing", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response"])
        }
        
        let decoder = JSONDecoder()
        let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)
        
        let dailyPlans = geminiResponse.dailyPlans.map { plan in
            DailyPlan(
                day: plan.day,
                activities: plan.activities.map { activity in
                    Activity(
                        name: activity.name,
                        type: activity.type,
                        description: activity.description,
                        time: activity.time,
                        distance: activity.distance,
                        cost: activity.cost
                    )
                }
            )
        }
        
        return Itinerary(
            userId: userId,
            location: location.name,
            duration: duration,
            interests: interests,
            dailyPlans: dailyPlans,
            budgetPerDay: budgetPerDay
        )
    }
}

struct GeminiResponse: Codable {
    let dailyPlans: [GeminiDailyPlan]
}

struct GeminiDailyPlan: Codable {
    let day: Int
    let activities: [GeminiActivity]
}

struct GeminiActivity: Codable {
    let name: String
    let type: String
    let description: String
    let time: String
    let distance: Double
    let cost: Double
}

class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func saveItinerary(_ itinerary: Itinerary) async throws {
        let encoder = Firestore.Encoder()
        let data = try encoder.encode(itinerary)
        try await db.collection("itineraries").document(itinerary.id).setData(data)
    }
    
    func fetchItineraries() async throws -> [Itinerary] {
        guard let userId = Auth.auth().currentUser?.uid else {
            return []
        }
        
        let snapshot = try await db.collection("itineraries")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let decoder = Firestore.Decoder()
        let itineraries = try snapshot.documents.compactMap { doc in
            try decoder.decode(Itinerary.self, from: doc.data())
        }
        
        // Sort locally by createdAt (descending)
        return itineraries.sorted { $0.createdAt > $1.createdAt }
    }
    
    func deleteItinerary(_ id: String) async throws {
        try await db.collection("itineraries").document(id).delete()
    }
    
    func updateItinerary(_ itinerary: Itinerary) async throws {
        let encoder = Firestore.Encoder()
        let data = try encoder.encode(itinerary)
        try await db.collection("itineraries").document(itinerary.id).setData(data)
    }
    
    // Progress tracking
    func updateItineraryProgress(itineraryId: String, dayId: String, completedActivities: [String]) async throws {
        try await db.collection("itineraries")
            .document(itineraryId)
            .collection("progress")
            .document(dayId)
            .setData(["completedActivities": completedActivities])
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
    
    // Group Plans
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
        
        // Update original itinerary to mark as shared
        try await updateItinerary(sharedItinerary)
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
    
    func addMemberToGroup(groupId: String, memberEmail: String) async throws {
        let docRef = db.collection("groupPlans").document(groupId)
        
        // Get current group data
        let document = try await docRef.getDocument()
        guard let data = document.data() else {
            throw NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
        }
        
        let decoder = Firestore.Decoder()
        var group = try decoder.decode(GroupPlan.self, from: data)
        
        // Check if member already exists
        guard !group.members.contains(where: { $0.email == memberEmail }) else {
            throw NSError(domain: "Firestore", code: 400, userInfo: [NSLocalizedDescriptionKey: "Member already exists in group"])
        }
        
        // Add new member
        let newMember = GroupMember(email: memberEmail, isOwner: false)
        
        // Update Firestore with array union
        try await docRef.updateData([
            "members": FieldValue.arrayUnion([["email": memberEmail, "isOwner": false]]),
            "memberEmails": FieldValue.arrayUnion([memberEmail])
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
}
