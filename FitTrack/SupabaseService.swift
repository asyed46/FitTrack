//
//  SupabaseService.swift
//  FitTrack
//
//  Created on 1/28/2026.
//

import Foundation
import Combine
import Supabase

struct ProfileRow: Codable, Identifiable {
    let id: UUID
    let username: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case createdAt = "created_at"
    }
}

struct GroupRow: Codable, Identifiable {
    let id: UUID
    let name: String
    let code: String
    let createdBy: UUID
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case code
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct GroupMemberUserIdRow: Codable {
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct GroupWithMembersRow: Codable {
    let id: UUID
    let name: String
    let code: String
    let createdBy: UUID
    let createdAt: Date?
    let groupMembers: [GroupMemberUserIdRow]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case code
        case createdBy = "created_by"
        case createdAt = "created_at"
        case groupMembers = "group_members"
    }
}

struct WorkoutRow: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let title: String
    let notes: String?
    let workoutDate: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case notes
        case workoutDate = "workout_date"
        case createdAt = "created_at"
    }
}

struct WorkoutExerciseRow: Codable, Identifiable {
    let id: UUID
    let workoutId: UUID
    let userId: UUID
    let type: ExerciseType
    let name: String
    let duration: Double?
    let weight: Double?
    let reps: Int?
    let sets: Int?
    let distance: Double?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case workoutId = "workout_id"
        case userId = "user_id"
        case type
        case name
        case duration
        case weight
        case reps
        case sets
        case distance
        case createdAt = "created_at"
    }
}

struct LeaderboardRow: Codable, Identifiable {
    let id: UUID
    let username: String?
    let totalScore: Double
    let workoutsCount: Int

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case username
        case totalScore = "total_score"
        case workoutsCount = "workouts_count"
    }
}

final class SupabaseService: ObservableObject {
    let client: SupabaseClient
    @Published private(set) var authUserId: UUID?
    @Published private(set) var authEmail: String?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(urlString: String, anonKey: String) {
        guard let url = URL(string: urlString), !anonKey.isEmpty else {
            preconditionFailure("Supabase config is missing. Add your project URL and anon key.")
        }

        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }

    @MainActor
    func refreshAuthUser() async throws {
        let user = try await client.auth.user()
        authUserId = user.id
        authEmail = user.email
    }

    @MainActor
    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)

        do {
            try await refreshAuthUser()
        } catch {
            // Likely requires email confirmation before a session exists.
        }
    }

    @MainActor
    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
        try await refreshAuthUser()
    }

    @MainActor
    func signOut() async throws {
        try await client.auth.signOut()
        authUserId = nil
        authEmail = nil
    }

    func fetchProfile(userId: UUID) async throws -> ProfileRow? {
        let rows: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .execute()
            .value

        return rows.first
    }

    func insertProfile(id: UUID, username: String?) async throws {
        let row = ProfileRow(id: id, username: username, createdAt: nil)
        try await client
            .from("profiles")
            .insert(row)
            .execute()
    }

    func fetchMyGroups() async throws -> [Group] {
        let rows: [GroupWithMembersRow] = try await client
            .from("groups")
            .select("id,name,code,created_by,created_at,group_members(user_id)")
            .execute()
            .value

        return rows.map { row in
            Group(
                id: row.id,
                name: row.name,
                code: row.code,
                memberIds: row.groupMembers.map(\.userId),
                createdBy: row.createdBy,
                createdAt: row.createdAt ?? Date()
            )
        }
    }

    func createGroup(name: String, code: String) async throws -> Group {
        // Uses the SQL RPC we'll add in Supabase.
        let created: GroupRow = try await client
            .rpc("create_group", params: ["p_name": name, "p_code": code])
            .execute()
            .value

        // Fetch with members so memberIds count is correct.
        let groups = try await fetchMyGroups()
        if let g = groups.first(where: { $0.id == created.id }) { return g }
        return Group(
            id: created.id,
            name: created.name,
            code: created.code,
            memberIds: authUserId.map { [$0] } ?? [],
            createdBy: created.createdBy,
            createdAt: created.createdAt ?? Date()
        )
    }

    func joinGroup(code: String) async throws -> Group {
        let joined: GroupRow = try await client
            .rpc("join_group", params: ["p_code": code])
            .execute()
            .value

        let groups = try await fetchMyGroups()
        if let g = groups.first(where: { $0.id == joined.id }) { return g }
        return Group(
            id: joined.id,
            name: joined.name,
            code: joined.code,
            memberIds: [],
            createdBy: joined.createdBy,
            createdAt: joined.createdAt ?? Date()
        )
    }

    func fetchGroupLeaderboard(groupId: UUID) async throws -> [LeaderboardRow] {
        let rows: [LeaderboardRow] = try await client
            .rpc("group_leaderboard", params: ["p_group_id": groupId.uuidString])
            .execute()
            .value
        return rows
    }

    func deleteGroup(groupId: UUID) async throws {
        struct DeleteGroupResponse: Codable {
            let ok: Bool
        }

        let res: DeleteGroupResponse = try await client
            .rpc("delete_group", params: ["p_group_id": groupId.uuidString])
            .execute()
            .value

        if res.ok != true {
            throw NSError(domain: "FitTrack", code: 1, userInfo: [NSLocalizedDescriptionKey: "Delete failed."])
        }
    }

    func fetchWorkouts(userId: UUID) async throws -> [WorkoutRow] {
        let rows: [WorkoutRow] = try await client
            .from("workouts")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        return rows
    }

    func fetchWorkoutExercises(userId: UUID) async throws -> [WorkoutExerciseRow] {
        let rows: [WorkoutExerciseRow] = try await client
            .from("workout_exercises")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        return rows
    }

    func fetchWorkoutsWithExercises(userId: UUID) async throws -> [Workout] {
        let workouts = try await fetchWorkouts(userId: userId)
        let exerciseRows = try await fetchWorkoutExercises(userId: userId)

        let exercisesByWorkoutId = Dictionary(grouping: exerciseRows, by: { $0.workoutId })

        return workouts.compactMap { row in
            guard let date = Self.dateFormatter.date(from: row.workoutDate) else { return nil }
            let exRows = exercisesByWorkoutId[row.id] ?? []
            let exercises = exRows.map { ex in
                Exercise(
                    id: ex.id,
                    type: ex.type,
                    name: ex.name,
                    duration: ex.duration,
                    weight: ex.weight,
                    reps: ex.reps,
                    sets: ex.sets,
                    distance: ex.distance
                )
            }

            return Workout(id: row.id, userId: row.userId, date: date, exercises: exercises)
        }
    }

    func insertWorkout(userId: UUID, title: String, notes: String?, date: Date) async throws -> WorkoutRow {
        let row = WorkoutRow(
            id: UUID(),
            userId: userId,
            title: title,
            notes: notes,
            workoutDate: Self.dateFormatter.string(from: date),
            createdAt: nil
        )

        try await client
            .from("workouts")
            .insert(row)
            .execute()

        return row
    }

    func insertWorkoutWithExercises(userId: UUID, date: Date, exercises: [Exercise]) async throws -> Workout {
        let workoutId = UUID()

        let workoutRow = WorkoutRow(
            id: workoutId,
            userId: userId,
            title: defaultTitle(for: exercises),
            notes: nil,
            workoutDate: Self.dateFormatter.string(from: date),
            createdAt: nil
        )

        do {
            try await client
                .from("workouts")
                .insert(workoutRow)
                .execute()

            if !exercises.isEmpty {
                let exerciseRows = exercises.map { exercise in
                    WorkoutExerciseRow(
                        id: exercise.id,
                        workoutId: workoutId,
                        userId: userId,
                        type: exercise.type,
                        name: exercise.name,
                        duration: exercise.duration,
                        weight: exercise.weight,
                        reps: exercise.reps,
                        sets: exercise.sets,
                        distance: exercise.distance,
                        createdAt: nil
                    )
                }

                try await client
                    .from("workout_exercises")
                    .insert(exerciseRows)
                    .execute()
            }
        } catch {
            // Best-effort cleanup to avoid orphan workouts if exercises insert fails.
            try? await client
                .from("workouts")
                .delete()
                .eq("id", value: workoutId.uuidString)
                .execute()
            throw error
        }

        return Workout(id: workoutId, userId: userId, date: date, exercises: exercises)
    }

    private func defaultTitle(for exercises: [Exercise]) -> String {
        let types = Set(exercises.map(\.type))
        if types.count == 1, let only = types.first {
            return only.rawValue
        }
        return "Workout"
    }
}
