//
//  AppState.swift
//  FitTrack
//
//  Created on 1/25/2026.
//

import Foundation
import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var groups: [Group] = []
    @Published var allUsers: [User] = []
    
    init() {
        self.currentUser = nil
        self.allUsers = []
    }

    func setCurrentUser(_ user: User) {
        currentUser = user
        if let index = allUsers.firstIndex(where: { $0.id == user.id }) {
            allUsers[index] = user
        } else {
            allUsers.append(user)
        }
    }

    func replaceWorkouts(_ workouts: [Workout]) {
        guard var user = currentUser else { return }
        user.workouts = workouts
        user.totalScore = workouts.reduce(0) { $0 + $1.score }
        setCurrentUser(user)
    }

    func setGroups(_ groups: [Group]) {
        self.groups = groups.sorted { $0.createdAt > $1.createdAt }
    }
    
    func createGroup(name: String) -> Group? {
        guard let currentUser = currentUser else { return nil }
        
        var newGroup = Group(name: name, createdBy: currentUser.id)
        newGroup.memberIds.append(currentUser.id)
        groups.append(newGroup)
        return newGroup
    }
    
    func joinGroup(code: String) -> Group? {
        guard let currentUser = currentUser else { return nil }
        
        if let groupIndex = groups.firstIndex(where: { $0.code == code.uppercased() }) {
            if !groups[groupIndex].memberIds.contains(currentUser.id) {
                groups[groupIndex].memberIds.append(currentUser.id)
            }
            return groups[groupIndex]
        }
        return nil
    }
    
    func getGroupMembers(for group: Group) -> [User] {
        return allUsers.filter { group.memberIds.contains($0.id) }
            .sorted { $0.totalScore > $1.totalScore }
    }
    
    func addWorkout(_ workout: Workout) {
        guard var user = currentUser else { return }
        
        user.addWorkout(workout)
        currentUser = user
        
        // Update in allUsers array
        if let index = allUsers.firstIndex(where: { $0.id == user.id }) {
            allUsers[index] = user
        }
    }
    
    func updateExercise(_ updatedExercise: Exercise, in workout: Workout) {
        guard var user = currentUser else { return }
        
        // Find the workout index
        if let workoutIndex = user.workouts.firstIndex(where: { $0.id == workout.id }) {
            // Find the exercise index
            if let exerciseIndex = user.workouts[workoutIndex].exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
                // Create a new exercises array with the updated exercise
                var updatedExercises = user.workouts[workoutIndex].exercises
                updatedExercises[exerciseIndex] = updatedExercise
                
                // Create a new workout with updated exercises
                let updatedWorkout = Workout(
                    id: workout.id,
                    userId: workout.userId,
                    date: workout.date,
                    exercises: updatedExercises
                )
                
                // Replace the workout
                user.workouts[workoutIndex] = updatedWorkout
                
                // Recalculate total score
                user.totalScore = user.workouts.reduce(0) { $0 + $1.score }
                
                currentUser = user
                
                // Update in allUsers array
                if let userIndex = allUsers.firstIndex(where: { $0.id == user.id }) {
                    allUsers[userIndex] = user
                }
            }
        }
    }
    
    func deleteExercise(_ exercise: Exercise, from workout: Workout) {
        guard var user = currentUser else { return }
        
        // Find the workout index
        if let workoutIndex = user.workouts.firstIndex(where: { $0.id == workout.id }) {
            // Filter out the exercise to delete
            let updatedExercises = user.workouts[workoutIndex].exercises.filter { $0.id != exercise.id }
            
            // If no exercises left, delete the entire workout
            if updatedExercises.isEmpty {
                user.workouts.remove(at: workoutIndex)
            } else {
                // Create a new workout with remaining exercises
                let updatedWorkout = Workout(
                    id: workout.id,
                    userId: workout.userId,
                    date: workout.date,
                    exercises: updatedExercises
                )
                
                // Replace the workout
                user.workouts[workoutIndex] = updatedWorkout
            }
            
            // Recalculate total score
            user.totalScore = user.workouts.reduce(0) { $0 + $1.score }
            
            currentUser = user
            
            // Update in allUsers array
            if let userIndex = allUsers.firstIndex(where: { $0.id == user.id }) {
                allUsers[userIndex] = user
            }
        }
    }
    
    func getUserRanking(in group: Group) -> Int {
        let members = getGroupMembers(for: group)
        guard let currentUser = currentUser,
              let index = members.firstIndex(where: { $0.id == currentUser.id }) else {
            return 0
        }
        return index + 1
    }
}
