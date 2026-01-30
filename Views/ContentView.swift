//
//  ContentView.swift
//  FitTrack
//
//  Created on 1/25/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var supabase: SupabaseService
    @State private var selectedTab = 0
    
    var body: some View {
        SwiftUI.Group {
            if supabase.authUserId == nil {
                AuthLandingView()
                    .environmentObject(appState)
                    .environmentObject(supabase)
            } else {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .environmentObject(appState)
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }
                        .tag(0)
                    
                    GroupsView()
                        .environmentObject(appState)
                        .tabItem {
                            Label("Groups", systemImage: "person.3.fill")
                        }
                        .tag(1)
                    
                    WorkoutTrackingView()
                        .environmentObject(appState)
                        .tabItem {
                            Label("Log Workout", systemImage: "plus.circle.fill")
                        }
                        .tag(2)
                    
                    ProfileView()
                        .environmentObject(appState)
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                        .tag(3)
                }
                .accentColor(.blue)
            }
        }
    }
}
