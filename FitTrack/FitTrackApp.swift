//
//  FitTrackApp.swift
//  FitTrack
//
//  Created on 1/25/2026.
//

import SwiftUI

@main
struct FitTrackApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var supabase: SupabaseService

    init() {
        let config = SupabaseConfig.load()
        _supabase = StateObject(wrappedValue: SupabaseService(urlString: config.urlString, anonKey: config.anonKey))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(supabase)
        }
    }
}
