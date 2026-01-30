//
//  AuthLandingView.swift
//  FitTrack
//
//  Created on 1/28/2026.
//

import SwiftUI

struct AuthLandingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var supabase: SupabaseService
    @State private var email = ""
    @State private var password = ""
    @State private var statusText = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var isEmailConfirmed = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("FitTrack")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Sign in to sync workouts")
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }

            if !statusText.isEmpty {
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if isEmailConfirmed {
                Text("Email is confirmed. You're ready to go!")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }

            Button(isSignUp ? "Create Account" : "Sign In") {
                submit()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            Button(isSignUp ? "I already have an account" : "Create a new account") {
                isSignUp.toggle()
                statusText = ""
                isEmailConfirmed = false
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)

            if isSignUp {
                Button("I confirmed my email") {
                    refreshSession()
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            Task { await tryRefreshSession() }
        }
    }

    private func submit() {
        guard !email.isEmpty, !password.isEmpty else {
            statusText = "Enter an email and password."
            return
        }

        isLoading = true
        statusText = isSignUp ? "Creating account..." : "Signing in..."
        Task {
            do {
                if isSignUp {
                    try await supabase.signUp(email: email, password: password)
                    await MainActor.run {
                        statusText = "Check your email to confirm, then tap 'I confirmed my email'."
                    }
                    await tryRefreshSession()
                } else {
                    try await supabase.signIn(email: email, password: password)
                    await MainActor.run {
                        statusText = "Signed in."
                    }
                    await updateLocalUser()
                    await loadUserWorkouts()
                    await loadUserGroups()
                }
            } catch {
                await MainActor.run {
                    statusText = "Auth failed: \(error.localizedDescription)"
                }
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func refreshSession() {
        isLoading = true
        statusText = "Checking confirmation..."
        Task {
            await tryRefreshSession()
            await MainActor.run { isLoading = false }
        }
    }

    @MainActor
    private func tryRefreshSession() async {
        do {
            try await supabase.refreshAuthUser()
            if supabase.authUserId != nil {
                isEmailConfirmed = true
                statusText = "Email confirmed."
                await updateLocalUser()
                await loadUserWorkouts()
                await loadUserGroups()
            }
        } catch {
            // No active session yet.
        }
    }

    @MainActor
    private func updateLocalUser() async {
        guard let userId = supabase.authUserId else { return }
        let emailValue = supabase.authEmail ?? email
        let name = emailValue.split(separator: "@").first.map(String.init) ?? "User"
        let newUser = User(id: userId, name: name, email: emailValue)

        appState.setCurrentUser(newUser)

        try? await supabase.insertProfile(id: userId, username: name)
    }

    @MainActor
    private func loadUserWorkouts() async {
        guard let userId = supabase.authUserId else { return }
        do {
            let workouts = try await supabase.fetchWorkoutsWithExercises(userId: userId)
            appState.replaceWorkouts(workouts)
        } catch {
            statusText = "Loaded user, but failed to fetch workouts."
        }
    }

    @MainActor
    private func loadUserGroups() async {
        do {
            let groups = try await supabase.fetchMyGroups()
            appState.setGroups(groups)
        } catch {
            // Groups are optional for the app to function.
        }
    }
}
