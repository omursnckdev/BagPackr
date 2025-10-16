//
//  ProfileView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
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
