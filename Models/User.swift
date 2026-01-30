//
//  User.swift
//  FitTrack
//
//  Created on 1/25/2026.
//

import Foundation

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var email: String
    var totalScore: Double
    var workouts: [Workout]
    
    init(id: UUID = UUID(), name: String, email: String, totalScore: Double = 0, workouts: [Workout] = []) {
        self.id = id
        self.name = name
        self.email = email
        self.totalScore = totalScore
        self.workouts = workouts
    }
    
    mutating func addWorkout(_ workout: Workout) {
        workouts.append(workout)
        totalScore += workout.score
    }
    
    // Hashable conformance - use id for hashing since Workout doesn't conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable conformance - use id for equality
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}
