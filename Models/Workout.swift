//
//  Workout.swift
//  FitTrack
//
//  Created on 1/25/2026.
//

import Foundation

struct Workout: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let date: Date
    let exercises: [Exercise]
    var score: Double {
        exercises.reduce(0) { $0 + $1.score }
    }
    
    init(id: UUID = UUID(), userId: UUID, date: Date = Date(), exercises: [Exercise] = []) {
        self.id = id
        self.userId = userId
        self.date = date
        self.exercises = exercises
    }
}

enum ExerciseType: String, Codable, CaseIterable {
    case cardio = "Cardio"
    case lifting = "Lifting"
}

struct Exercise: Identifiable, Codable {
    let id: UUID
    let type: ExerciseType
    let name: String
    let duration: TimeInterval? // in seconds, for cardio
    let weight: Double? // in lbs/kg, for lifting
    let reps: Int? // for lifting
    let sets: Int? // for lifting
    let distance: Double? // in miles/km, for cardio
    
    var score: Double {
        switch type {
        case .cardio:
            return calculateCardioScore()
        case .lifting:
            return calculateLiftingScore()
        }
    }
    
    init(id: UUID = UUID(), type: ExerciseType, name: String, duration: TimeInterval? = nil, weight: Double? = nil, reps: Int? = nil, sets: Int? = nil, distance: Double? = nil) {
        self.id = id
        self.type = type
        self.name = name
        self.duration = duration
        self.weight = weight
        self.reps = reps
        self.sets = sets
        self.distance = distance
    }
    
    private func calculateCardioScore() -> Double {
        var score: Double = 0
        
        // Base points: distance × 20
        if let distance = distance {
            score += distance * 20
        }
        
        // Pace bonus: (distance / hours) × 10
        // Rewards faster pace
        if let duration = duration, let distance = distance, duration > 0 {
            let hours = duration / 3600.0
            let pace = distance / hours  // miles per hour
            score += pace * 10
        }
        
        return score
    }
    
    private func calculateLiftingScore() -> Double {
        guard let weight = weight, let reps = reps, let sets = sets else {
            return 0
        }
        
        // Base volume score: (weight × reps × sets) / 10
        let volumeScore = (weight * Double(reps) * Double(sets)) / 10.0
        
        // Intensity multiplier based on rep range
        let intensityMultiplier: Double
        if reps <= 5 {
            // Heavy/Strength work: 1.5x bonus
            intensityMultiplier = 1.5
        } else if reps <= 12 {
            // Hypertrophy range: standard scoring
            intensityMultiplier = 1.0
        } else {
            // Endurance/High reps: 0.8x
            intensityMultiplier = 0.8
        }
        
        return volumeScore * intensityMultiplier
    }
}
