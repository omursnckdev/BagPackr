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
                    // Animated icon that changes based on mode
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .blur(radius: 20)
                        
                        Image(systemName: isSignUp ? "person.badge.plus" : "airplane.departure")
                            .font(.system(size: 70))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .transition(.scale.combined(with: .opacity))
                            .id(isSignUp) // Force view refresh for animation
                    }
                    
                    Text("BagPckr")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Dynamic subtitle that changes
                    Text(isSignUp ? "Create your account" : "Plan your perfect journey")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .transition(.opacity)
                        .id(isSignUp ? "signup" : "login")
                }
                .animation(.spring(response: 0.5), value: isSignUp)
                
                VStack(spacing: 20) {
                    // Mode indicator header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isSignUp ? "Sign Up" : "Log In")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(isSignUp ? "Join BagPckr today" : "Welcome back!")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        // Visual indicator badge
                        ZStack {
                            Circle()
                                .fill(isSignUp ? Color.green.opacity(0.3) : Color.blue.opacity(0.3))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: isSignUp ? "person.badge.plus.fill" : "person.fill")
                                .foregroundColor(.white)
                                .font(.title3)
                        }
                    }
                    .padding(.bottom, 10)
                    .transition(.opacity)
                    
                    TextField("", text: $email, prompt: Text("Email").foregroundColor(.white.opacity(0.9)))
                        .textFieldStyle(GlassTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .submitLabel(.next)
                    
                    SecureField("", text: $password, prompt: Text("Password").foregroundColor(.white.opacity(0.9)))
                        .textFieldStyle(GlassTextFieldStyle())
                        .submitLabel(.done)
                        .onSubmit {
                            handleAuth()
                        }
                    
                    // Main action button with clear distinction
                    Button(action: handleAuth) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: isSignUp ? "person.crop.circle.badge.plus" : "arrow.right.circle.fill")
                                    .font(.title3)
                                
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .fontWeight(.bold)
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: isSignUp
                                ? [Color.green.opacity(0.4), Color.green.opacity(0.3)]
                                : [Color.white.opacity(0.3), Color.white.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.white.opacity(isSignUp ? 0.5 : 0.2), lineWidth: 1)
                        )
                    }
                    .disabled(isLoading)
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.vertical, 5)
                    
                    // Toggle button with better visual feedback
                    Button(action: {
                        withAnimation(.spring(response: 0.4)) {
                            isSignUp.toggle()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isSignUp ? "arrow.left.circle" : "person.crop.circle.badge.plus")
                                .font(.body)
                            
                            Text(isSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                        )
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
        .onTapGesture {
            hideKeyboard()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Oops! That email or password doesn’t match our records.")
        }
    }
    
    private func handleAuth() {
        hideKeyboard()
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
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
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
    @StateObject private var adManager = AdManager.shared // ✅ Eklendi
    @State private var showMapPicker = false
    @State private var isWaitingForAd = false // ✅ Zaten var
    
    // Add these computed properties
    private var minBudget: Double {
        Locale.current.language.languageCode?.identifier == "tr" ? 1000 : 50
    }
    
    private var maxBudget: Double {
        Locale.current.language.languageCode?.identifier == "tr" ? 30000 : 1000
    }
    
    private var budgetStep: Double {
        Locale.current.language.languageCode?.identifier == "tr" ? 100 : 10
    }
    
    private var minBudgetText: String {
        Locale.current.language.languageCode?.identifier == "tr" ? "₺1000" : "$50"
    }
    
    private var maxBudgetText: String {
        Locale.current.language.languageCode?.identifier == "tr" ? "₺30000" : "$1000"
    }
    
    // ✅ Güncellenmiş button styling
    private var buttonGradientColors: [Color] {
        if isWaitingForAd || viewModel.isGenerating {
            return [Color.gray, Color.gray]
        } else if viewModel.canGenerate {
            return [Color.blue, Color.purple]
        } else {
            return [Color.gray, Color.gray]
        }
    }
    
    private var buttonShadowColor: Color {
        (viewModel.canGenerate && !viewModel.isGenerating && !isWaitingForAd)
        ? Color.blue.opacity(0.4)
        : Color.clear
    }
    
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
                        locationCard
                        durationCard
                        budgetCard
                        interestsCard
                        customInterestsCard
                        generateButton
                    }
                    .padding()
                }
                .onTapGesture {
                    hideKeyboard()
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
    
    // MARK: - View Components
    
    private var locationCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Location", systemImage: "mappin.circle.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Button(action: { showMapPicker = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.selectedLocation?.name ?? String(localized: "Select Location"))
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
    }
    
    private var durationCard: some View {
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
    }
    
    private var currencySymbol: String {
        Locale.current.language.languageCode?.identifier == "tr" ? "₺" : "$"
    }
    
    @State private var budgetText: String = ""
    @State private var isEditingBudget = false
    
    private var budgetCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Budget per Day", systemImage: "dollarsign.circle.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                HStack {
                    HStack(spacing: 0) {
                        Text(currencySymbol)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.green)
                            .frame(width: 30)
                        
                        TextField("", text: $budgetText)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.green)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.leading)
                            .frame(width: 170)
                            .onChange(of: budgetText) { oldValue, newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue {
                                    budgetText = filtered
                                }
                                if !filtered.isEmpty, let value = Double(filtered), value >= minBudget {
                                    viewModel.budgetPerDay = value
                                    isEditingBudget = true
                                }
                            }
                            .onSubmit {
                                finalizeBudgetEdit()
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green.opacity(0.1))
                    )
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        let totalBudget = Int(viewModel.budgetPerDay * Double(viewModel.duration))
                        VStack(spacing: 4) {
                            Text("Total:")
                            Text("\(currencySymbol)\(totalBudget)")
                        }
                        .font(.headline)
                        .foregroundColor(.primary)
                    }
                }
                
                Slider(
                    value: Binding(
                        get: { min(viewModel.budgetPerDay, maxBudget) },
                        set: {
                            viewModel.budgetPerDay = $0
                            budgetText = String(Int($0))
                            isEditingBudget = false
                        }
                    ),
                    in: minBudget...maxBudget,
                    step: budgetStep
                )
                .accentColor(.green)
                
                HStack {
                    Text(minBudgetText)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(viewModel.budgetPerDay > maxBudget ? "Custom" : "Budget")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(maxBudgetText)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            if viewModel.budgetPerDay > 0 {
                budgetText = String(Int(viewModel.budgetPerDay))
            } else {
                budgetText = ""
            }
        }
    }
    
    private func finalizeBudgetEdit() {
        isEditingBudget = false
        if let value = Double(budgetText), value >= minBudget {
            viewModel.budgetPerDay = value
            budgetText = String(Int(value))
        } else {
            budgetText = String(Int(viewModel.budgetPerDay))
        }
    }
    
    private var interestsCard: some View {
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
    }
    
    private var customInterestsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 15) {
                Label("Custom Interests", systemImage: "plus.square.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                HStack {
                    TextField("e.g., Temple, Sushi, Kebab", text: $viewModel.customInterestInput)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .submitLabel(.done)
                        .cornerRadius(10)
                        .onSubmit {
                            withAnimation(.spring()) {
                                viewModel.addCustomInterest()
                            }
                        }
                    
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
    }
    
    // ✅ Güncellenmiş generate button
    private var generateButton: some View {
        Button(action: handleGenerateButtonTap) {
            buttonContent
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: buttonGradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(15)
                .shadow(color: buttonShadowColor, radius: 10, x: 0, y: 5)
        }
        .disabled(!viewModel.canGenerate || viewModel.isGenerating || isWaitingForAd) // ✅ isWaitingForAd eklendi
        .padding(.horizontal)
    }
    
    // ✅ Güncellenmiş button content
    @ViewBuilder
    private var buttonContent: some View {
        HStack {
            if viewModel.isGenerating || isWaitingForAd {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.9)
                
                if isWaitingForAd {
                    Text("Loading ad...")
                        .fontWeight(.semibold)
                } else {
                    Text("Creating your journey...")
                        .fontWeight(.semibold)
                }
            } else {
                Image(systemName: "sparkles")
                Text("Generate Itinerary")
                    .fontWeight(.semibold)
            }
        }
    }
    
    // MARK: - Actions
    
    // ✅ Düzeltilmiş fonksiyon
    private func handleGenerateButtonTap() {
        Task {
            // 1. İşlemi başlat
            viewModel.generateItinerary(itineraryListViewModel: itineraryListViewModel)
            
            // 2. Reklamı bekle ve göster
            await waitForAdAndShow()
        }
    }
    
    // ✅ Yeni fonksiyon: Reklamı bekle ve göster
    private func waitForAdAndShow() async {
        let maxWaitTime: TimeInterval = 4.0 // Maksimum 4 saniye bekle
        let checkInterval: TimeInterval = 0.2 // Her 200ms kontrol et
        var elapsed: TimeInterval = 0.0
        
        // Reklam zaten hazırsa direkt göster
        if adManager.isAdReady {
            print("✅ Ad already ready, showing immediately")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 saniye bekle
            await MainActor.run {
                AdManager.shared.showAd()
            }
            return
        }
        
        // Reklam hazır değilse bekle
        await MainActor.run {
            isWaitingForAd = true
        }
        print("⏳ Waiting for ad to load...")
        
        while !adManager.isAdReady && elapsed < maxWaitTime {
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            elapsed += checkInterval
        }
        
        await MainActor.run {
            isWaitingForAd = false
        }
        
        // Reklamı göster
        await MainActor.run {
            if adManager.isAdReady {
                print("✅ Ad loaded! Showing now...")
                AdManager.shared.showAd()
            } else {
                print("⏱️ Timeout: Ad couldn't load in \(maxWaitTime) seconds")
            }
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
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
// MARK: - Map Picker View
struct MapPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLocation: LocationData?
    @State private var searchText = ""
    @State private var mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 20.0, longitude: 0.0)
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var placeName: String = ""
    @State private var isLocationLocked = false
    @State private var searchResults: [GMSAutocompletePrediction] = []
    @State private var showResults = false
    @State private var searchTask: DispatchWorkItem?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map - Background
                GoogleMapView(
                    center: $mapCenter,
                    selectedCoordinate: $selectedCoordinate,
                    placeName: $placeName,
                    isLocationLocked: $isLocationLocked
                )
                .ignoresSafeArea()
                
                // Search bar and results - Always on top
                VStack {
                    VStack(spacing: 0) {
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search location", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .autocorrectionDisabled()
                                .foregroundColor(.primary)
                                .onSubmit {
                                    // Trigger search when user presses Enter/Return
                                    performSearch()
                                }
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    searchResults = []
                                    showResults = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        )
                        .padding()
                        
                        // Search Results
                        if showResults && !searchResults.isEmpty {
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(searchResults, id: \.placeID) { result in
                                        Button(action: { selectSearchResult(result) }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(result.attributedPrimaryText.string)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                
                                                if let secondary = result.attributedSecondaryText?.string {
                                                    Text(secondary)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding()
                                        }
                                        
                                        if result.placeID != searchResults.last?.placeID {
                                            Divider()
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
                
                // Confirm Button - Always at bottom when coordinate selected
                if selectedCoordinate != nil {
                    VStack {
                        Spacer()
                        
                        Button(action: confirmSelection) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Confirm: \(placeName)")
                                    .fontWeight(.semibold)
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
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                // Debounce the search - wait 0.3 seconds after user stops typing
                searchTask?.cancel()
                
                guard !newValue.isEmpty else {
                    searchResults = []
                    showResults = false
                    return
                }
                
                let task = DispatchWorkItem { [newValue] in
                    performSearch(query: newValue)
                }
                searchTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
            }
        }
    }
    
    private func performSearch(query: String? = nil) {
        let searchQuery = query ?? searchText
        
        guard !searchQuery.isEmpty else {
            searchResults = []
            showResults = false
            return
        }
        
        print("Searching for: \(searchQuery)")
        
        let placesClient = GMSPlacesClient.shared()
        let filter = GMSAutocompleteFilter()
        // Remove restrictive types or use nil for all types
        filter.types = nil  // This allows all place types including cities
        // Or you can try: filter.types = ["geocode"] for addresses and cities
        
        placesClient.findAutocompletePredictions(fromQuery: searchQuery, filter: filter, sessionToken: nil) { results, error in
            if let error = error {
                print("Search error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.searchResults = []
                    self.showResults = false
                }
                return
            }
            
            print("Found \(results?.count ?? 0) results")
            
            guard let results = results else {
                DispatchQueue.main.async {
                    self.searchResults = []
                    self.showResults = false
                }
                return
            }
            
            DispatchQueue.main.async {
                self.searchResults = results
                self.showResults = true
                print("Results updated, showing: \(results.count) items")
            }
        }
    }
    
    private func selectSearchResult(_ result: GMSAutocompletePrediction) {
        let placesClient = GMSPlacesClient.shared()
        
        print("Selecting place: \(result.attributedPrimaryText.string)")
        
        placesClient.fetchPlace(fromPlaceID: result.placeID, placeFields: .all, sessionToken: nil) { place, error in
            if let error = error {
                print("Fetch place error: \(error.localizedDescription)")
                return
            }
            
            guard let place = place else {
                print("No place returned")
                return
            }
            
            print("Place found: \(place.name ?? "Unknown") at \(place.coordinate.latitude), \(place.coordinate.longitude)")
            
            DispatchQueue.main.async {
                self.mapCenter = place.coordinate
                self.selectedCoordinate = place.coordinate
                self.placeName = place.name ?? result.attributedPrimaryText.string
                self.searchText = self.placeName
                self.searchResults = []
                self.showResults = false
                self.isLocationLocked = true
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
                                let daysText = Locale.current.language.languageCode?.identifier == "tr" ? "Gün" : "Days"
                                Label("\(itinerary.duration) \(daysText)", systemImage: "calendar")
                                Spacer()
                                let currencySymbol = Locale.current.language.languageCode?.identifier == "tr" ? "₺" : "$"
                                Label("\(currencySymbol)\(Int(itinerary.budgetPerDay * Double(itinerary.duration)))", systemImage: "dollarsign.circle.fill")
                            }
                            .font(.subheadline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(itinerary.interests, id: \.self) { interest in
                                        Text(LocalizedStringKey(interest))
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
        
        text += "\nCreated with BagPckr ✈️"
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
                            NavigationLink(destination: ItineraryDetailView(itineraryId: itinerary.id, viewModel: viewModel)) {
                                EnhancedItineraryListRow(itinerary: itinerary)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: deleteItineraries)
                    }
                    .id(UUID())
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
            
            VStack(alignment: .leading, spacing: 8) {
                Text(itinerary.location)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(
                        "\(itinerary.duration) \(String(localized: "Days"))",
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Label(
                        String(
                            localized: "$\(Int(itinerary.budgetPerDay * Double(itinerary.duration)))"
                        ),
                        systemImage: "dollarsign.circle"
                    )
                    .font(.caption)
                    .foregroundColor(.green)
                }
                
                // 🌿 Interests Section
                FlexibleChipLayout(spacing: 6) {
                    ForEach(itinerary.interests.prefix(3), id: \.self) { interest in
                        Text(NSLocalizedString(interest, comment: "Interest category"))
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                    
                    if itinerary.interests.count > 3 {
                        Text("+\(itinerary.interests.count - 3)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
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
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

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


// MARK: - Itinerary Detail View
struct ItineraryDetailView: View {
    let itineraryId: String
    @ObservedObject var viewModel: ItineraryListViewModel
    @State private var showEditSheet = false
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var showGroupShare = false
    @State private var shareText = ""
    @Environment(\.dismiss) var dismiss
    
    // Get the latest itinerary from viewModel
    private var itinerary: Itinerary? {
        viewModel.itineraries.first(where: { $0.id == itineraryId })
    }
    
    private func totalSpent(for itinerary: Itinerary) -> Double {
        itinerary.dailyPlans.reduce(0) { total, plan in
            total + plan.activities.reduce(0) { $0 + $1.cost }
        }
    }
    
    var body: some View {
        Group {
            if let itinerary = itinerary {
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
                                    let daysText = Locale.current.language.languageCode?.identifier == "tr" ? "Gün" : "Days"
                                    Label("\(itinerary.duration) \(daysText)", systemImage: "calendar")
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Budget: $\(Int(itinerary.budgetPerDay * Double(itinerary.duration)))")
                                        Text("Spent: $\(Int(totalSpent(for: itinerary)))")
                                            .font(.caption)
                                    }
                                }
                                .font(.subheadline)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(itinerary.interests, id: \.self) { interest in
                                            Text(LocalizedStringKey(interest))
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
                        HStack(spacing: 12) {
                            ActionButton(icon: "pencil", title: "Edit", color: .blue) {
                                showEditSheet = true
                            }
                            .frame(maxWidth: .infinity)
                            
                            ActionButton(icon: "person.2.fill", title: "Group", color: .purple) {
                                showGroupShare = true
                            }
                            .frame(maxWidth: .infinity)
                            
                            ActionButton(icon: "trash", title: "Delete", color: .red) {
                                showDeleteAlert = true
                            }
                            .frame(maxWidth: .infinity)
                        }
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
            } else {
                ProgressView()
                    .onAppear {
                        Task { await viewModel.loadItineraries() }
                    }
            }
        }
    }
    
    private func shareItinerary(itinerary: Itinerary) {
        shareText = generateShareText(for: itinerary)
        showShareSheet = true
    }
    
    private func generateShareText(for itinerary: Itinerary) -> String {
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
            try? await FirestoreService.shared.deleteItinerary(itineraryId)
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
            .frame(minWidth: 90, minHeight: 70)  // Changed from fixed width: 70
            .frame(maxWidth: .infinity)          // Added to expand with container
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
                    .transition(.opacity.combined(with: .scale))
                } else {
                    List {
                        ForEach(viewModel.groupPlans) { group in
                            NavigationLink(destination: GroupDetailView(group: group)) {
                                GroupPlanRow(group: group)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        }
                        .onDelete(perform: deleteGroups)
                    }
                    .listStyle(.plain)
                    .background(Color(.systemGroupedBackground))
                    .transition(.opacity.combined(with: .scale))
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
        }
        .onAppear {
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
    
    private func deleteGroups(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let group = viewModel.groupPlans[index]
                try? await FirestoreService.shared.deleteGroup(group.id)
            }
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
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Label(
                        "\(group.members.count) \(String(localized: "members"))",
                        systemImage: "person.2"
                    )
                    .font(.caption)
                    .foregroundColor(.purple)
                    .padding(.trailing, 4)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(group.createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2) // ✨ slight breathing space under location
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemBackground))
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
        guard let itinerary = selectedItinerary else { return }
        let validEmails = memberEmails.filter { !$0.isEmpty }
        
        Task {
            try? await FirestoreService.shared.createGroupPlan(
                name: groupName,
                itinerary: itinerary,
                memberEmails: validEmails
            )
            dismiss()
        }
    }
}
struct GroupDetailView: View {
    let group: GroupPlan
    @State private var showAddMember = false
    @State private var showAddExpense = false
    @State private var newMemberEmail = ""
    @State private var isAddingMember = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var refreshedGroup: GroupPlan?
    @State private var expenses: [GroupExpense] = []
    @State private var selectedTab = 0
    
    // 🔥 Add real-time listeners
    @State private var expensesListener: ListenerRegistration?
    @State private var groupListener: ListenerRegistration?
    
    var currentGroup: GroupPlan {
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
                ItineraryTabView(group: currentGroup)
                    .tag(0)
                
                MembersTabView(
                    group: currentGroup,
                    isOwner: isOwner,
                    onMemberRemoved: { await refreshGroup() }
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
                onExpenseAdded: {
                    // Listener automatically updates
                }
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        // 🔥 Start listeners when view appears
        .onAppear {
            startListeners()
        }
        // 🔥 Stop listeners when view disappears
        .onDisappear {
            stopListeners()
        }
    }
    
    // 🔥 Add listener management methods
    private func startListeners() {
        // Listen to expenses
        expensesListener = FirestoreService.shared.listenToGroupExpenses(groupId: currentGroup.id) { updatedExpenses in
            withAnimation {
                expenses = updatedExpenses
            }
        }
        
        // Listen to group changes (members, etc.)
        groupListener = FirestoreService.shared.listenToGroup(groupId: currentGroup.id) { updatedGroup in
            if let group = updatedGroup {
                withAnimation {
                    refreshedGroup = group
                }
            }
        }
    }
    
    private func stopListeners() {
        expensesListener?.remove()
        groupListener?.remove()
        expensesListener = nil
        groupListener = nil
    }
    
    private func addMember() {
        let email = newMemberEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }
        
        isAddingMember = true
        
        Task {
            do {
                try await FirestoreService.shared.addMemberToGroup(groupId: currentGroup.id, memberEmail: email)
                // Listener will auto-update
                newMemberEmail = ""
                showAddMember = false
                isAddingMember = false
            } catch {
                errorMessage = "An error occurred! Check member email or internet connection."
                showError = true
                isAddingMember = false
            }
        }
    }
    
    private func refreshGroup() async {
        // Listener handles this automatically now
    }
}

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

struct MemberRow: View {
    let member: GroupMember
    let isCurrentUser: Bool
    let canRemove: Bool
    let onRemove: () -> Void
    
    var memberName: String {
        member.email.components(separatedBy: "@").first ?? member.email
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(member.isOwner ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 45, height: 45)
                
                Image(systemName: member.isOwner ? "crown.fill" : "person.fill")
                    .foregroundColor(member.isOwner ? .purple : .blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(memberName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text(member.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if member.isOwner {
                        Text("• Owner")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
            }
            
            Spacer()
            
            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                }
            }
        }
        .padding(.vertical, 8)
    }
}


// MARK: - Edit Itinerary View

struct EditItineraryView: View {
    @Environment(\.dismiss) var dismiss
    let itinerary: Itinerary
    let viewModel: ItineraryListViewModel
    
    @StateObject private var adManager = AdManager.shared // ✅ Eklendi
    
    @State private var editedDuration: Int
    @State private var editedBudget: Double
    @State private var editedInterests: Set<String>
    @State private var customInterestInput = ""
    @State private var customInterests: [String]
    @State private var isRegenerating = false
    @State private var isWaitingForAd = false // ✅ Eklendi
    @State private var showError = false
    @State private var errorMessage = ""
    
    @State private var budgetText: String = ""
    @State private var isEditingBudget = false
    
    private var minBudget: Double {
        Locale.current.language.languageCode?.identifier == "tr" ? 1000 : 50
    }
    
    private var maxBudget: Double {
        Locale.current.language.languageCode?.identifier == "tr" ? 30000 : 1000
    }
    
    private var currencySymbol: String {
        Locale.current.language.languageCode?.identifier == "tr" ? "₺" : "$"
    }
    
    private var minBudgetText: String {
        Locale.current.language.languageCode?.identifier == "tr" ? "₺1000" : "$50"
    }
    
    private var maxBudgetText: String {
        Locale.current.language.languageCode?.identifier == "tr" ? "₺30000" : "$1000"
    }
    
    // ✅ Güncellenmiş gradient colors
    private var buttonGradientColors: [Color] {
        if isRegenerating || isWaitingForAd {
            return [.gray, .gray]
        } else {
            return [.blue, .purple]
        }
    }
    
    // ✅ Güncellenmiş shadow color
    private var buttonShadowColor: Color {
        (isRegenerating || isWaitingForAd) ? .clear : .blue.opacity(0.4)
    }
    
    static let builtInInterests = [
        "Beaches",
        "Nightlife",
        "Restaurants",
        "Museums",
        "Shopping",
        "Parks",
        "Adventure Sports",
        "Historical Sites",
        "Art Galleries",
        "Local Markets",
        "Street Food",
        "Temples",
        "Architecture",
        "Hiking",
        "Water Sports",
        "Cafes",
        "Live Music",
        "Theater",
        "Festivals"
    ]
    
    init(itinerary: Itinerary, viewModel: ItineraryListViewModel) {
        self.itinerary = itinerary
        self.viewModel = viewModel
        _editedDuration = State(initialValue: itinerary.duration)
        _editedBudget = State(initialValue: itinerary.budgetPerDay)
        _editedInterests = State(initialValue: Set(itinerary.interests))
        _customInterests = State(initialValue: itinerary.interests.filter { !Self.builtInInterests.contains($0) })
        _budgetText = State(initialValue: String(Int(itinerary.budgetPerDay)))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 📍 LOCATION CARD
                    ModernCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(String(localized: "Location"), systemImage: "mappin.circle.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Text(itinerary.location)
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text(String(localized: "Location cannot be changed"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                    }
                    
                    // 📅 DURATION CARD
                    ModernCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(String(localized: "Duration"), systemImage: "calendar")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            HStack {
                                Text("\(editedDuration)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.blue)
                                
                                Text(String(localized: "days"))
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
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                    }
                    
                    // 💰 BUDGET CARD
                    ModernCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(String(localized: "Budget per Day"), systemImage: "dollarsign.circle.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            HStack {
                                HStack(spacing: 4) {
                                    Text(currencySymbol)
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.green)
                                    
                                    TextField("", text: $budgetText)
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.green)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.leading)
                                        .frame(width: 170)
                                        .onTapGesture {
                                            if !isEditingBudget {
                                                isEditingBudget = true
                                                budgetText = String(Int(editedBudget))
                                            }
                                        }
                                        .onChange(of: budgetText) { oldValue, newValue in
                                            let filtered = newValue.filter { $0.isNumber }
                                            if filtered != newValue {
                                                budgetText = filtered
                                            }
                                            
                                            if let value = Double(filtered), value >= minBudget {
                                                editedBudget = value
                                            }
                                        }
                                        .onSubmit {
                                            finalizeBudgetEdit()
                                        }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.green.opacity(0.1))
                                )
                                
                                Spacer()
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { min(editedBudget, maxBudget) },
                                    set: { editedBudget = $0 }
                                ),
                                in: minBudget...maxBudget,
                                step: 10
                            )
                            .accentColor(.green)
                            .onChange(of: editedBudget) { oldValue, newValue in
                                if !isEditingBudget {
                                    budgetText = String(Int(newValue))
                                }
                            }
                            
                            HStack {
                                Text(minBudgetText)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(editedBudget > maxBudget ? "Custom" : "Tap number to type")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(maxBudgetText)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                    }
                    
                    // 🌟 INTERESTS CARD
                    ModernCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Label(String(localized: "Edit Interests"), systemImage: "star.fill")
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
                                TextField(String(localized: "Add custom interest"), text: $customInterestInput)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                    .submitLabel(.done)
                                
                                Button(action: addCustomInterest) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                    }
                    
                    // 🔁 REGENERATE BUTTON (✅ Güncellenmiş)
                    Button(action: handleRegenerateButtonTap) {
                        HStack {
                            if isRegenerating || isWaitingForAd {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                                
                                if isWaitingForAd {
                                    Text(String(localized: "Loading ad..."))
                                        .fontWeight(.semibold)
                                } else {
                                    Text(String(localized: "Regenerating..."))
                                        .fontWeight(.semibold)
                                }
                            } else {
                                Image(systemName: "arrow.clockwise")
                                Text(String(localized: "Regenerate Itinerary"))
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: buttonGradientColors, // ✅ Dinamik renkler
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(color: buttonShadowColor, radius: 10, x: 0, y: 5) // ✅ Dinamik shadow
                    }
                    .disabled(isRegenerating || isWaitingForAd || editedInterests.isEmpty) // ✅ isWaitingForAd eklendi
                    .padding(.horizontal)
                }
                .padding()
            }
            .onTapGesture {
                hideKeyboard()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "Edit Itinerary"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
            .alert(String(localized: "Error"), isPresented: $showError) {
                Button(String(localized: "OK"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func finalizeBudgetEdit() {
        isEditingBudget = false
        
        if let value = Double(budgetText) {
            let clamped = max(value, minBudget)
            editedBudget = clamped
            budgetText = String(Int(clamped))
        } else {
            budgetText = String(Int(editedBudget))
        }
    }
    
    private func toggleInterest(_ interest: String) {
        if editedInterests.contains(interest) {
            editedInterests.remove(interest)
        } else {
            editedInterests.insert(interest)
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
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
    
    // ✅ Düzeltilmiş fonksiyon
    private func handleRegenerateButtonTap() {
        Task {
            dismiss()
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 saniye
            
            // 1. Reklamı bekle ve göster
            await waitForAdAndShow()
            
            // 2. Regenerate işlemini başlat
            await regenerateItinerary()
        }
    }
    
    // ✅ Yeni fonksiyon: Reklamı bekle ve göster
    
    private func waitForAdAndShow() async {
        let maxWaitTime: TimeInterval = 4.0
        let checkInterval: TimeInterval = 0.2
        var elapsed: TimeInterval = 0.0
        
        if adManager.isAdReady {
            print("✅ Ad already ready, showing immediately")
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                AdManager.shared.showAd()
            }
            return
        }
        
        print("⏳ Waiting for ad to load...")
        
        while !adManager.isAdReady && elapsed < maxWaitTime {
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            elapsed += checkInterval
        }
        
        await MainActor.run {
            if adManager.isAdReady {
                print("✅ Ad loaded! Showing now...")
                AdManager.shared.showAd()
            } else {
                print("⏱️ Timeout")
            }
        }
    }
    
    private func regenerateItinerary() async {
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
            
        } catch {
            print("❌ Regeneration error: \(error.localizedDescription)")
        }
    }
    
    
}


// MARK: - Profile View

import SwiftUI
import FirebaseAuth

// Add this custom text field style

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSignOutAlert = false
    @State private var showDeleteSheet = false
    @State private var email = ""
    @State private var password = ""
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "v\(version)"
    }
    
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
                        
                        // 🔹 User Info Card
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
                        
                        // 🔹 About Card
                        ModernCard {
                            VStack(alignment: .leading, spacing: 15) {
                                Text(String(localized: "About"))
                                    .font(.headline)
                                
                                InfoRow(
                                    icon: "airplane.departure",
                                    title: String(localized: "BagPckr Smart Travel Assistant"),
                                    subtitle: appVersion
                                )
                                InfoRow(
                                    icon: "sparkles",
                                    title: String(localized: "AI Powered"),
                                    subtitle: String(localized: "Gemini Integration")
                                )
                                InfoRow(
                                    icon: "map.fill",
                                    title: String(localized: "Google Maps"),
                                    subtitle: String(localized: "Location Services")
                                )
                                InfoRow(
                                    icon: "person.3.fill",
                                    title: String(localized: "Group Plans"),
                                    subtitle: String(localized: "Collaborate with friends")
                                )
                                InfoRow(
                                    icon: "exclamationmark.triangle.fill",
                                    title: String(localized: "Verify Details"),
                                    subtitle: String(localized: "Results may not be accurate")
                                )
                            }
                        }
                        
                        
                        // 🔹 Sign Out Button
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
                        
                        // 🔹 Delete Account Button
                        Button(role: .destructive) {
                            showDeleteSheet = true
                            email = authViewModel.currentUser?.email ?? ""
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete My Account")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(15)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            
            // 🔹 Sign Out Alert
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            
            // 🔹 Delete Account Sheet
            .sheet(isPresented: $showDeleteSheet) {
                NavigationView {
                    ZStack {
                        LinearGradient(
                            colors: [Color.red.opacity(0.05), Color.orange.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                        
                        ScrollView {
                            VStack(spacing: 25) {
                                // Warning Icon
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.red.opacity(0.2), .orange.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 100, height: 100)
                                    
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.red)
                                }
                                .padding(.top, 20)
                                
                                VStack(spacing: 8) {
                                    Text("Delete Account")
                                        .font(.title)
                                        .fontWeight(.bold)
                                    
                                    Text("This action cannot be undone")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Warning Card
                                ModernCard {
                                    HStack(spacing: 12) {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(.orange)
                                            .font(.title2)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("This will permanently delete:")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            
                                            Text("• Your account\n• All itineraries\n• Group memberships\n• Expense records")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding()
                                }
                                
                                // Credentials Card
                                ModernCard {
                                    VStack(alignment: .leading, spacing: 15) {
                                        Text("Confirm Your Identity")
                                            .font(.headline)
                                        
                                        VStack(spacing: 12) {
                                            TextField("", text: $email, prompt: Text("Email").foregroundColor(.secondary))
                                                .textFieldStyle(StyledTextFieldStyle())
                                                .autocapitalization(.none)
                                                .disableAutocorrection(true)
                                                .submitLabel(.next)
                                            
                                            SecureField("", text: $password, prompt: Text("Password").foregroundColor(.secondary))
                                                .textFieldStyle(StyledTextFieldStyle())
                                                .submitLabel(.done)
                                        }
                                        
                                        if let deleteError = deleteError {
                                            HStack(spacing: 8) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                                Text(deleteError)
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                            }
                                            .padding(.top, 5)
                                        }
                                    }
                                    .padding()
                                }
                                
                                // Action Buttons
                                VStack(spacing: 12) {
                                    if isDeleting {
                                        HStack {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                            Text("Deleting account...")
                                                .font(.subheadline)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(15)
                                    } else {
                                        Button(role: .destructive) {
                                            isDeleting = true
                                            authViewModel.deleteAccount(email: email, password: password) { error in
                                                isDeleting = false
                                                if let error = error {
                                                    deleteError = error.localizedDescription
                                                } else {
                                                    showDeleteSheet = false
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Image(systemName: "trash.fill")
                                                Text("Delete Account Permanently")
                                                    .fontWeight(.semibold)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(
                                                LinearGradient(
                                                    colors: [Color.red, Color.orange],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .foregroundColor(.white)
                                            .cornerRadius(15)
                                            .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
                                        }
                                        //.disabled(email.isEmpty || password.isEmpty)
                                        //.opacity((email.isEmpty || password.isEmpty) ? 0.5 : 1.0)
                                        
                                        Button {
                                            showDeleteSheet = false
                                        } label: {
                                            HStack {
                                                Image(systemName: "xmark.circle")
                                                Text("Cancel")
                                                    .fontWeight(.medium)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color(.secondarySystemBackground))
                                            .foregroundColor(.primary)
                                            .cornerRadius(15)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Close") {
                                showDeleteSheet = false
                            }
                        }
                    }
                }
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






struct ItineraryTabView: View {
    let group: GroupPlan
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                            Text(group.itinerary.location)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            let daysText = Locale.current.language.languageCode?.identifier == "tr" ? "Gün" : "Days"
                            Label("\(group.itinerary.duration) \(daysText)", systemImage: "calendar")
                            
                            Spacer()
                            let membersText = Locale.current.language.languageCode?.identifier == "tr" ? "Üye" : "Members"
                            
                            Label("\(group.members.count) \(membersText)", systemImage: "person.2")
                        }
                        .font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                .cornerRadius(20)
                .padding(.horizontal)
                
                ForEach(Array(group.itinerary.dailyPlans.enumerated()), id: \.element.id) { index, plan in
                    EnhancedDayPlanCard(
                        dayNumber: index + 1,
                        plan: plan,
                        location: group.itinerary.location,
                        itinerary: group.itinerary
                    )
                }
            }
            .padding(.vertical)
        }
    }
}
struct ExpensesTabView: View {
    let groupId: String
    @Binding var expenses: [GroupExpense]
    let members: [GroupMember]
    @State private var showError = false
    @State private var errorMessage = ""
    
    var totalExpenses: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var expensesByCategory: [(category: ExpenseCategory, amount: Double)] {
        Dictionary(grouping: expenses, by: { $0.category })
            .map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ModernCard {
                    VStack(spacing: 15) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Expenses")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("$\(String(format: "%.2f", totalExpenses))")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("\(expenses.count)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("transactions")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        if !expensesByCategory.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("By Category")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                ForEach(expensesByCategory, id: \.category) { item in
                                    HStack {
                                        Image(systemName: item.category.icon)
                                            .foregroundColor(item.category.color)
                                            .frame(width: 25)
                                        
                                        Text(item.category.rawValue)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        Text("$\(String(format: "%.2f", item.amount))")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(item.category.color)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                if expenses.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No expenses yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Add your first expense to start tracking")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .transition(.opacity.combined(with: .scale))
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(expenses) { expense in
                            ExpenseRow(
                                expense: expense,
                                members: members,
                                onDelete: { deleteExpense(expense) }
                            )
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func deleteExpense(_ expense: GroupExpense) {
        Task {
            do {
                // Animate the removal
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    expenses.removeAll { $0.id == expense.id }
                }
                
                // Delete from Firestore
                try await FirestoreService.shared.deleteExpense(groupId: groupId, expenseId: expense.id)
            } catch {
                // If deletion fails, restore the expense
                withAnimation {
                    if let deletedExpense = expense as? GroupExpense {
                        expenses.append(deletedExpense)
                        expenses.sort { $0.date > $1.date }
                    }
                }
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct EditExpenseView: View {
    @Environment(\.dismiss) var dismiss
    let groupId: String
    let expense: GroupExpense
    let members: [GroupMember]
    let onExpenseUpdated: () -> Void
    
    @State private var description: String
    @State private var amount: String
    @State private var selectedCategory: ExpenseCategory
    @State private var isUpdating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(groupId: String, expense: GroupExpense, members: [GroupMember], onExpenseUpdated: @escaping () -> Void) {
        self.groupId = groupId
        self.expense = expense
        self.members = members
        self.onExpenseUpdated = onExpenseUpdated
        
        _description = State(initialValue: expense.description)
        _amount = State(initialValue: String(format: "%.2f", expense.amount))
        _selectedCategory = State(initialValue: expense.category)
    }
    
    var canUpdate: Bool {
        !description.isEmpty && !amount.isEmpty && Double(amount) != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Expense Details")) {
                    TextField("Description", text: $description)
                    
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                }
                
                Section {
                    Text("Paid by: \(expense.paidBy.components(separatedBy: "@").first ?? "Unknown")")
                        .foregroundColor(.secondary)
                    
                    Text("Split between: \(expense.splitBetween.count) members")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateExpense()
                    }
                    .disabled(!canUpdate || isUpdating)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func updateExpense() {
        guard let amountValue = Double(amount) else { return }
        
        isUpdating = true
        
        Task {
            do {
                try await FirestoreService.shared.updateExpense(
                    groupId: groupId,
                    expenseId: expense.id,
                    description: description,
                    amount: amountValue,
                    category: selectedCategory
                )
                onExpenseUpdated()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isUpdating = false
            }
        }
    }
}
struct ExpenseRow: View {
    let expense: GroupExpense
    let members: [GroupMember]
    let onDelete: () -> Void
    @State private var isDeleting = false
    
    var paidByName: String {
        expense.paidBy.components(separatedBy: "@").first ?? "Unknown"
    }
    
    var splitInfo: String {
        if expense.splitBetween.count == members.count {
            return "Split equally"
        } else {
            return "Split \(expense.splitBetween.count) ways"
        }
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(expense.category.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: expense.category.icon)
                        .foregroundColor(expense.category.color)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.description)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(paidByName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(splitInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(expense.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("$\(String(format: "%.2f", expense.amount))")
                    .font(.headline)
                    .foregroundColor(expense.category.color)
                    .padding(.trailing, 30)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(15)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .opacity(isDeleting ? 0.5 : 1.0)
            .scaleEffect(isDeleting ? 0.95 : 1.0)
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isDeleting = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onDelete()
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.red)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                    )
            }
            .offset(x: -8, y: 8)
            .scaleEffect(isDeleting ? 0.8 : 1.0)
        }
    }
}

struct BalancesTabView: View {
    let expenses: [GroupExpense]
    let members: [GroupMember]
    
    var balances: [Balance] {
        calculateBalances()
    }
    
    var settlements: [Settlement] {
        calculateSettlements()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ModernCard {
                    VStack(alignment: .leading, spacing: 15) {
                        Label("Member Balances", systemImage: "person.2.fill")
                            .font(.headline)
                            .foregroundColor(.purple)
                        
                        if balances.isEmpty {
                            Text("No expenses to calculate")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(balances, id: \.person) { balance in
                                BalanceRow(balance: balance)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                if !settlements.isEmpty {
                    ModernCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Label("Settle Up", systemImage: "arrow.left.arrow.right")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            ForEach(settlements.indices, id: \.self) { index in
                                SettlementRow(settlement: settlements[index])
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private func calculateBalances() -> [Balance] {
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
        
        return balanceMap.map { Balance(person: $0.key, amount: $0.value) }
            .sorted { abs($0.amount) > abs($1.amount) }
    }
    private func calculateSettlements() -> [Settlement] {
        // Step 1: Build creditors and debtors separately
        var creditors: [(person: String, amount: Double)] = balances
            .filter { $0.amount > 0.01 }
            .map { (person: $0.person, amount: $0.amount) }
        
        var debtors: [(person: String, amount: Double)] = balances
            .filter { $0.amount < -0.01 }
            .map { (person: $0.person, amount: abs($0.amount)) }
        
        // Step 2: Sort deterministically
        creditors.sort {
            if abs($0.amount - $1.amount) < 0.01 {
                return $0.person < $1.person
            }
            return $0.amount > $1.amount
        }
        
        debtors.sort {
            if abs($0.amount - $1.amount) < 0.01 {
                return $0.person < $1.person
            }
            return $0.amount > $1.amount
        }
        
        // Step 3: Match creditors and debtors greedily
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
    
}

struct BalanceRow: View {
    let balance: Balance
    
    var name: String {
        balance.person.components(separatedBy: "@").first ?? "Unknown"
    }
    
    var isBalanced: Bool {
        abs(balance.amount) < 0.01
    }
    private var currencySymbol: String {
        Locale.current.language.languageCode?.identifier == "tr" ? "₺" : "$"
    }
    var body: some View {
        HStack {
            Text(name)
                .font(.subheadline)
            
            Spacer()
            
            if isBalanced {
                Text("Settled")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else if balance.amount > 0 {
                Text("gets back \(currencySymbol)\(String(format: "%.2f", balance.amount))")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else {
                Text("owes \(currencySymbol)\(String(format: "%.2f", abs(balance.amount)))")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }
}

struct SettlementRow: View {
    let settlement: Settlement
    
    var fromName: String {
        settlement.from.components(separatedBy: "@").first ?? "Unknown"
    }
    
    var toName: String {
        settlement.to.components(separatedBy: "@").first ?? "Unknown"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(fromName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(toName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Text("Settlement payment")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("$\(String(format: "%.2f", settlement.amount))")
                .font(.headline)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    let groupId: String
    let members: [GroupMember]
    let onExpenseAdded: () -> Void
    
    @State private var description = ""
    @State private var amount = ""
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var paidBy: String = ""
    @State private var splitBetween: Set<String> = []
    @State private var isAdding = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var canAdd: Bool {
        !description.isEmpty &&
        !amount.isEmpty &&
        Double(amount) != nil &&
        !paidBy.isEmpty &&
        !splitBetween.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Expense Details")) {
                    TextField("Description", text: $description)
                        .submitLabel(.done)
                    
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    Picker(String(localized: "Category"), selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.localizedName) // ✅ works with LocalizedStringKey
                            }
                            .tag(category)
                        }
                    }
                    
                    
                }
                
                Section(header: Text("Paid By")) {
                    Picker("Select member", selection: $paidBy) {
                        Text("Select...").tag("")
                        ForEach(members, id: \.email) { member in
                            Text(member.email.components(separatedBy: "@").first ?? member.email)
                                .tag(member.email)
                        }
                    }
                }
                
                Section(header: Text("Split Between")) {
                    Button(action: toggleAllMembers) {
                        HStack {
                            Text(splitBetween.count == members.count ? "Deselect All" : "Select All")
                            Spacer()
                            Text("\(splitBetween.count)/\(members.count)")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    ForEach(members, id: \.email) { member in
                        Button(action: { toggleMember(member.email) }) {
                            HStack {
                                Text(member.email.components(separatedBy: "@").first ?? member.email)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if splitBetween.contains(member.email) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.purple)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                
                if !splitBetween.isEmpty, let amountValue = Double(amount) {
                    Section(header: Text("Split Details")) {
                        let perPerson = amountValue / Double(splitBetween.count)
                        Text("$\(String(format: "%.2f", perPerson)) per person")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addExpense()
                    }
                    .disabled(!canAdd || isAdding)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func toggleAllMembers() {
        if splitBetween.count == members.count {
            splitBetween.removeAll()
        } else {
            splitBetween = Set(members.map { $0.email })
        }
    }
    
    private func toggleMember(_ email: String) {
        if splitBetween.contains(email) {
            splitBetween.remove(email)
        } else {
            splitBetween.insert(email)
        }
    }
    
    private func addExpense() {
        guard let amountValue = Double(amount) else { return }
        
        isAdding = true
        
        let expense = GroupExpense(
            groupId: groupId,
            description: description,
            amount: amountValue,
            paidBy: paidBy,
            splitBetween: Array(splitBetween),
            category: selectedCategory
        )
        
        Task {
            do {
                try await FirestoreService.shared.addExpenseToGroup(expense: expense)
                onExpenseAdded()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isAdding = false
            }
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
    
    // MARK: - Progress Tracking
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
    
    // MARK: - Expenses + Settlements
    func addExpenseToGroup(expense: GroupExpense) async throws {
        let encoder = Firestore.Encoder()
        let data = try encoder.encode(expense)
        
        try await db.collection("groupPlans")
            .document(expense.groupId)
            .collection("expenses")
            .document(expense.id)
            .setData(data)
        
        // 🔄 Recalculate settlements
        let expenses = try await fetchGroupExpenses(groupId: expense.groupId)
        let group = try await getGroupById(groupId: expense.groupId)
        let newSettlements = calculateSettlements(expenses: expenses, members: group.members)
        try await saveSettlements(groupId: expense.groupId, settlements: newSettlements)
    }
    
    func fetchGroupExpenses(groupId: String) async throws -> [GroupExpense] {
        let snapshot = try await db.collection("groupPlans")
            .document(groupId)
            .collection("expenses")
            .getDocuments()
        
        let decoder = Firestore.Decoder()
        return try snapshot.documents.compactMap { doc in
            try? decoder.decode(GroupExpense.self, from: doc.data())
        }.sorted { $0.date > $1.date }
    }
    
    func deleteExpense(groupId: String, expenseId: String) async throws {
        try await db.collection("groupPlans")
            .document(groupId)
            .collection("expenses")
            .document(expenseId)
            .delete()
        
        // 🔄 Recalculate settlements
        let expenses = try await fetchGroupExpenses(groupId: groupId)
        let group = try await getGroupById(groupId: groupId)
        let newSettlements = calculateSettlements(expenses: expenses, members: group.members)
        try await saveSettlements(groupId: groupId, settlements: newSettlements)
    }
    func updateExpense(groupId: String, expenseId: String, description: String, amount: Double, category: ExpenseCategory) async throws {
        try await db.collection("groupPlans")
            .document(groupId)
            .collection("expenses")
            .document(expenseId)
            .updateData([
                "description": description,
                "amount": amount,
                "category": category.rawValue
            ])
        
        // Recalculate settlements
        let expenses = try await fetchGroupExpenses(groupId: groupId)
        let group = try await getGroupById(groupId: groupId)
        let newSettlements = calculateSettlements(expenses: expenses, members: group.members)
        try await saveSettlements(groupId: groupId, settlements: newSettlements)
    }
    
    // MARK: - Settlements
    func saveSettlements(groupId: String, settlements: [Settlement]) async throws {
        let encoder = Firestore.Encoder()
        let data = try settlements.map { try encoder.encode($0) }
        
        try await db.collection("groupPlans")
            .document(groupId)
            .collection("settlements")
            .document("current")
            .setData(["items": data])
    }
    
    func fetchSettlements(groupId: String) async throws -> [Settlement] {
        let snapshot = try await db.collection("groupPlans")
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
    func listenToGroupExpenses(groupId: String, completion: @escaping ([GroupExpense]) -> Void) -> ListenerRegistration {
        let listener = db.collection("groupPlans")
            .document(groupId)
            .collection("expenses")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to expenses: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let decoder = Firestore.Decoder()
                let expenses = documents.compactMap { doc -> GroupExpense? in
                    try? decoder.decode(GroupExpense.self, from: doc.data())
                }.sorted { $0.date > $1.date }
                
                completion(expenses)
            }
        
        return listener
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
