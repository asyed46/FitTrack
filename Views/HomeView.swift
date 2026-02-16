//
//  HomeView.swift
//  FitTrack
//
//  Created on 1/25/2026.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var supabase: SupabaseService
    @State private var groupRanks: [UUID: Int] = [:]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Score Card
                    ScoreCardView()
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Active Groups
                    if !appState.groups.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Groups")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ForEach(appState.groups) { group in
                                NavigationLink(destination: LeaderboardView(group: group)) {
                                    GroupCardView(
                                        group: group,
                                        rank: groupRanks[group.id]
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No Groups Yet")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Create or join a group to start competing!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Recent Workouts
                    if let user = appState.currentUser, !user.workouts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Workouts")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ForEach(user.workouts.suffix(3).reversed()) { workout in
                                WorkoutCardView(workout: workout)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("FitTrack")
            .task(id: rankReloadKey) {
                await refreshServerRanks()
            }
        }
    }

    private var rankReloadKey: String {
        let groupPart = appState.groups.map(\.id.uuidString).joined(separator: ",")
        let userPart = appState.currentUser?.id.uuidString ?? "no-user"
        let scorePart = Int(appState.currentUser?.totalScore ?? 0)
        let workoutCountPart = appState.currentUser?.workouts.count ?? 0
        return "\(userPart)|\(groupPart)|\(scorePart)|\(workoutCountPart)"
    }

    private func refreshServerRanks() async {
        guard let userId = appState.currentUser?.id else {
            await MainActor.run { groupRanks = [:] }
            return
        }

        var updatedRanks: [UUID: Int] = [:]

        for group in appState.groups {
            do {
                let leaderboard = try await supabase.fetchGroupLeaderboard(groupId: group.id)
                if let rankIndex = leaderboard.firstIndex(where: { $0.id == userId }) {
                    updatedRanks[group.id] = rankIndex + 1
                }
            } catch {
                // Leave this group unset so UI doesn't show an incorrect local rank.
            }
        }

        await MainActor.run {
            groupRanks = updatedRanks
        }
    }
}

struct ScoreCardView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Total Score")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("\(Int(appState.currentUser?.totalScore ?? 0))")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.blue)
            
            if let user = appState.currentUser {
                Text("\(user.workouts.count) workouts logged")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

struct GroupCardView: View {
    let group: Group
    let rank: Int?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(group.name)
                    .font(.headline)
                
                Text("Code: \(group.code)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(group.memberIds.count) member\(group.memberIds.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let rank {
                VStack(alignment: .trailing) {
                    Text("Rank #\(rank)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    if rank <= 3 && group.memberIds.count > 0 {
                        Image(systemName: rank == 1 ? "trophy.fill" : rank == 2 ? "medal.fill" : "medal")
                            .foregroundColor(rank == 1 ? .yellow : .gray)
                    }
                }
            } else {
                Text("Rank --")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

struct WorkoutCardView: View {
    let workout: Workout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.date, style: .date)
                    .font(.headline)
                Spacer()
                Text("\(Int(workout.score)) pts")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            Text("\(workout.exercises.count) exercise\(workout.exercises.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}
