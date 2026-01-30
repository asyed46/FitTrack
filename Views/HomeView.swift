//
//  HomeView.swift
//  FitTrack
//
//  Created on 1/25/2026.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    
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
                                    GroupCardView(group: group)
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
    @EnvironmentObject var appState: AppState
    let group: Group
    
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
            
            if let user = appState.currentUser {
                let members = appState.getGroupMembers(for: group)
                let rank = appState.getUserRanking(in: group)
                
                VStack(alignment: .trailing) {
                    Text("Rank #\(rank)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    if rank <= 3 && members.count > 0 {
                        Image(systemName: rank == 1 ? "trophy.fill" : rank == 2 ? "medal.fill" : "medal")
                            .foregroundColor(rank == 1 ? .yellow : .gray)
                    }
                }
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
