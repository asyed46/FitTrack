//
//  LeaderboardView.swift
//  FitTrack
//
//  Created on 1/25/2026.
//

import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var supabase: SupabaseService
    @Environment(\.dismiss) private var dismiss
    let group: Group
    @State private var rows: [LeaderboardRow] = []
    @State private var errorText: String?
    @State private var showingDeleteConfirm = false
    @State private var isDeleting = false
    
    var body: some View {
        List {
            if let errorText {
                Text(errorText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                LeaderboardRowView(
                    username: row.username ?? "User",
                    workoutsCount: row.workoutsCount,
                    totalScore: row.totalScore,
                    rank: index + 1,
                    isCurrentUser: row.id == appState.currentUser?.id
                )
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if isCurrentUserGroupOwner {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Text("Delete Group")
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .alert("Delete Group?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteGroup() }
            }
        } message: {
            Text("This will remove the group for everyone.")
        }
        .task {
            await loadLeaderboard()
        }
    }

    private var isCurrentUserGroupOwner: Bool {
        guard let userId = appState.currentUser?.id else { return false }
        return userId == group.createdBy
    }

    @MainActor
    private func loadLeaderboard() async {
        do {
            let fetched = try await supabase.fetchGroupLeaderboard(groupId: group.id)
            rows = fetched.sorted { $0.totalScore > $1.totalScore }
            errorText = nil
        } catch {
            errorText = "Couldn't load leaderboard."
        }
    }

    @MainActor
    private func deleteGroup() async {
        guard isCurrentUserGroupOwner else { return }
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await supabase.deleteGroup(groupId: group.id)
            appState.groups.removeAll { $0.id == group.id }
            dismiss()
        } catch {
            errorText = "Couldn't delete group."
        }
    }
}

struct LeaderboardRowView: View {
    let username: String
    let workoutsCount: Int
    let totalScore: Double
    let rank: Int
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank indicator
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                if rank <= 3 {
                    Image(systemName: rankIcon)
                        .font(.title2)
                        .foregroundColor(rankColor)
                } else {
                    Text("\(rank)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(rankColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(username)
                        .font(.headline)
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("\(workoutsCount) workout\(workoutsCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(totalScore))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Text("points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(isCurrentUser ? Color.blue.opacity(0.1) : Color.clear)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default: return .blue
        }
    }
    
    private var rankIcon: String {
        switch rank {
        case 1: return "trophy.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return ""
        }
    }
}
