//
//  AuthView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI


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
