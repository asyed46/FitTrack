//
//  ProfileView.swift
//  FitTrack
//
//  Created on 1/25/2026.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var supabase: SupabaseService
    @State private var signOutStatus: String?
    
    var body: some View {
        NavigationStack {
            Form {
                if let user = appState.currentUser {
                    Section(header: Text("Profile")) {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(user.name)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section(header: Text("Statistics")) {
                        HStack {
                            Text("Total Score")
                            Spacer()
                            Text("\(Int(user.totalScore))")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Text("Total Workouts")
                            Spacer()
                            Text("\(user.workouts.count)")
                                .fontWeight(.semibold)
                        }
                        
                        if !user.workouts.isEmpty {
                            let avgScore = user.totalScore / Double(user.workouts.count)
                            HStack {
                                Text("Avg Score/Workout")
                                Spacer()
                                Text("\(Int(avgScore))")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    
                    if !user.workouts.isEmpty {
                        Section(header: Text("Workout History")) {
                            ForEach(user.workouts.suffix(10).reversed()) { workout in
                                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(workout.date, style: .date)
                                                .font(.headline)
                                            Text("\(workout.exercises.count) exercise\(workout.exercises.count == 1 ? "" : "s")")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text("\(Int(workout.score)) pts")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            signOut()
                        } label: {
                            Text("Sign Out")
                        }

                        if let signOutStatus {
                            Text(signOutStatus)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }

    private func signOut() {
        signOutStatus = "Signing out..."
        Task {
            do {
                try await supabase.signOut()
                await MainActor.run {
                    appState.currentUser = nil
                    appState.groups = []
                    signOutStatus = nil
                }
            } catch {
                await MainActor.run {
                    signOutStatus = "Sign out failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct WorkoutDetailView: View {
    let workout: Workout
    
    var body: some View {
        List {
            Section(header: Text("Workout Details")) {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(workout.date, style: .date)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Total Score")
                    Spacer()
                    Text("\(Int(workout.score)) pts")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
            Section(header: Text("Exercises")) {
                ForEach(workout.exercises) { exercise in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(exercise.name)
                                .font(.headline)
                            Spacer()
                            Text("\(Int(exercise.score)) pts")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        
                        if exercise.type == .cardio {
                            if let duration = exercise.duration {
                                Text("Duration: \(formatDuration(duration))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let distance = exercise.distance {
                                Text("Distance: \(String(format: "%.2f", distance)) miles")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            if let weight = exercise.weight, let reps = exercise.reps, let sets = exercise.sets {
                                Text("\(Int(weight)) lbs × \(reps) reps × \(sets) sets")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
