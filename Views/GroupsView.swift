//
//  GroupsView.swift
//  FitTrack
//
//  Created on 1/25/2026.
//

import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var supabase: SupabaseService
    @State private var showingCreateGroup = false
    @State private var showingJoinGroup = false
    @State private var groupName = ""
    @State private var joinCode = ""
    @State private var showJoinError = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            List {
                if appState.groups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Groups Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Create a group or join one with a code")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(appState.groups) { group in
                        NavigationLink(destination: LeaderboardView(group: group)) {
                            GroupRowView(group: group)
                        }
                    }
                }
            }
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateGroup = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingJoinGroup = true }) {
                        Image(systemName: "qrcode")
                    }
                }
            }
            .refreshable {
                await refreshGroups()
            }
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView(groupName: $groupName, isPresented: $showingCreateGroup)
            }
            .sheet(isPresented: $showingJoinGroup) {
                JoinGroupView(joinCode: $joinCode, isPresented: $showingJoinGroup, showError: $showJoinError)
            }
            .onAppear {
                Task { await refreshGroups() }
            }
        }
    }

    @MainActor
    private func refreshGroups() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let groups = try await supabase.fetchMyGroups()
            appState.setGroups(groups)
        } catch {
            // Ignore; user can still create/join.
        }
    }
}

struct GroupRowView: View {
    @EnvironmentObject var appState: AppState
    let group: Group
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                Text("Code: \(group.code) • \(group.memberIds.count) member\(group.memberIds.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let user = appState.currentUser {
                let rank = appState.getUserRanking(in: group)
                Text("#\(rank)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreateGroupView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var supabase: SupabaseService
    @Binding var groupName: String
    @Binding var isPresented: Bool
    @State private var statusText: String?
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Group Details")) {
                    TextField("Group Name", text: $groupName)
                }

                if let statusText {
                    Section {
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                        groupName = ""
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task { await createGroup() }
                    }
                    .disabled(groupName.isEmpty)
                }
            }
        }
    }

    @MainActor
    private func createGroup() async {
        guard !groupName.isEmpty else { return }
        guard !isLoading else { return }
        isLoading = true
        statusText = "Creating..."
        defer { isLoading = false }

        do {
            // Reuse your model's code generator by constructing a Group once.
            let temp = Group(name: groupName, createdBy: appState.currentUser?.id ?? UUID())
            let created = try await supabase.createGroup(name: groupName, code: temp.code)
            var updated = appState.groups
            updated.append(created)
            appState.setGroups(updated)
            isPresented = false
            groupName = ""
        } catch {
            statusText = "Create failed: \(error.localizedDescription)"
        }
    }
}

struct JoinGroupView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var supabase: SupabaseService
    @Binding var joinCode: String
    @Binding var isPresented: Bool
    @Binding var showError: Bool
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Enter Group Code")) {
                    TextField("Group Code", text: $joinCode)
                        .autocapitalization(.allCharacters)
                }
                
                if showError {
                    Section {
                        Text("Group not found. Please check the code and try again.")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Join Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                        joinCode = ""
                        showError = false
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Join") {
                        Task { await joinGroup() }
                    }
                    .disabled(joinCode.isEmpty)
                }
            }
        }
    }

    @MainActor
    private func joinGroup() async {
        guard !joinCode.isEmpty else { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let joined = try await supabase.joinGroup(code: joinCode.uppercased())
            var updated = appState.groups
            if !updated.contains(where: { $0.id == joined.id }) {
                updated.append(joined)
            }
            appState.setGroups(updated)
            isPresented = false
            joinCode = ""
            showError = false
        } catch {
            showError = true
        }
    }
}
