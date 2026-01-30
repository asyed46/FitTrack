//
//  WorkoutTrackingView.swift
//  FitTrack
//
//  Created on 1/25/2026.
//

import SwiftUI

struct WorkoutTrackingView: View {
    @State private var selectedView = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedView) {
                    Text("Log Workout").tag(0)
                    Text("Calendar").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedView == 0 {
                    LogWorkoutView()
                } else {
                    WorkoutCalendarView()
                }
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct LogWorkoutView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var supabase: SupabaseService
    @State private var workoutDate = Date()
    @State private var exercises: [Exercise] = []
    @State private var showingAddExercise = false
    @State private var showingSaveConfirmation = false
    @State private var statusText: String?
    
    var body: some View {
        Form {
            Section(header: Text("Workout Date")) {
                DatePicker("Date", selection: $workoutDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
            
            Section(header: Text("Exercises")) {
                if exercises.isEmpty {
                    Text("Tap + to add an exercise")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(exercises) { exercise in
                        ExerciseRowView(exercise: exercise)
                    }
                    .onDelete(perform: deleteExercise)
                }
            }
            
            Section {
                Button(action: { showingAddExercise = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Exercise")
                    }
                }
            }
            
            if !exercises.isEmpty {
                Section(header: Text("Workout Summary")) {
                    HStack {
                        Text("Total Score")
                        Spacer()
                        Text("\(Int(exercises.reduce(0) { $0 + $1.score })) pts")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                
                Section {
                    Button(action: saveWorkout) {
                        HStack {
                            Spacer()
                            Text("Save Workout")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(exercises.isEmpty)
                }
            }

            if let statusText {
                Section {
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView(
                exercises: $exercises,
                isPresented: $showingAddExercise
            )
        }
        .alert("Workout Saved!", isPresented: $showingSaveConfirmation) {
            Button("OK") {
                exercises = []
                workoutDate = Date() // Reset to today
            }
        } message: {
            Text("Your workout has been logged successfully.")
        }
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }
    
    private func saveWorkout() {
        guard let userId = supabase.authUserId else {
            statusText = "Sign in to save workouts."
            return
        }

        statusText = "Saving..."
        Task {
            do {
                let workout = try await supabase.insertWorkoutWithExercises(
                    userId: userId,
                    date: workoutDate,
                    exercises: exercises
                )
                await MainActor.run {
                    appState.addWorkout(workout)
                    statusText = nil
                    showingSaveConfirmation = true
                }
            } catch {
                await MainActor.run {
                    statusText = "Save failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct WorkoutCalendarView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDate = Date()
    @State private var editContext: EditContext?
    
    struct EditContext: Identifiable {
        let id = UUID()
        let workout: Workout
        let exercise: Exercise
    }
    
    var workoutsForSelectedDate: [Workout] {
        guard let user = appState.currentUser else { return [] }
        return user.workouts.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar Date Picker
            DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
            
            Divider()
            
            // Workouts for selected date
            if workoutsForSelectedDate.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No workouts logged for this day")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(workoutsForSelectedDate) { workout in
                            WorkoutDayCard(
                                workout: workout,
                                onEdit: { exercise in
                                    editContext = EditContext(workout: workout, exercise: exercise)
                                },
                                onDelete: { exercise in
                                    appState.deleteExercise(exercise, from: workout)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $editContext) { context in
            EditExerciseView(
                workout: context.workout,
                exercise: context.exercise,
                isPresented: Binding(
                    get: { editContext != nil },
                    set: { if !$0 { editContext = nil } }
                )
            )
            .environmentObject(appState)
        }
    }
}

struct WorkoutDayCard: View {
    let workout: Workout
    let onEdit: (Exercise) -> Void
    let onDelete: (Exercise) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(workout.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(workout.score)) pts")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            Divider()
            
            ForEach(workout.exercises) { exercise in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.headline)
                        
                        if exercise.type == .cardio {
                            if let duration = exercise.duration {
                                Text("Duration: \(formatDuration(duration))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let distance = exercise.distance {
                                Text("Distance: \(String(format: "%.2f", distance)) mi")
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
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Text("\(Int(exercise.score)) pts")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Button(action: { onEdit(exercise) }) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                        }
                        
                        Button(action: { onDelete(exercise) }) {
                            Image(systemName: "trash.circle.fill")
                                .foregroundColor(.red)
                                .font(.title2)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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

struct ExerciseRowView: View {
    let exercise: Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.headline)
            
            HStack {
                if exercise.type == .cardio {
                    if let duration = exercise.duration {
                        Text("Duration: \(formatDuration(duration))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let distance = exercise.distance {
                        Text("Distance: \(String(format: "%.2f", distance)) mi")
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
                Spacer()
                Text("\(Int(exercise.score)) pts")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
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

struct EditExerciseView: View {
    @EnvironmentObject var appState: AppState
    let workout: Workout
    let exercise: Exercise
    @Binding var isPresented: Bool
    
    @State private var exerciseName = ""
    
    // Cardio fields
    @State private var durationHours = 0
    @State private var durationMinutes = 0
    @State private var distance = ""
    
    // Lifting fields
    @State private var weight = ""
    @State private var reps = ""
    @State private var sets = ""
    
    init(workout: Workout, exercise: Exercise, isPresented: Binding<Bool>) {
        self.workout = workout
        self.exercise = exercise
        self._isPresented = isPresented
        
        // Initialize state with existing exercise values
        _exerciseName = State(initialValue: exercise.name)
        
        if exercise.type == .cardio {
            if let duration = exercise.duration {
                _durationHours = State(initialValue: Int(duration) / 3600)
                _durationMinutes = State(initialValue: (Int(duration) % 3600) / 60)
            }
            if let dist = exercise.distance {
                _distance = State(initialValue: String(format: "%.2f", dist))
            }
        } else {
            if let w = exercise.weight {
                _weight = State(initialValue: String(format: "%.0f", w))
            }
            if let r = exercise.reps {
                _reps = State(initialValue: String(r))
            }
            if let s = exercise.sets {
                _sets = State(initialValue: String(s))
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Exercise Type")) {
                    Text(exercise.type.rawValue)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Exercise Name")) {
                    TextField(exercise.type == .cardio ? "e.g., Running, Cycling" : "e.g., Bench Press, Squats", text: $exerciseName)
                }
                
                if exercise.type == .cardio {
                    Section(header: Text("Cardio Details")) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Picker("Hours", selection: $durationHours) {
                                ForEach(0..<24) { hour in
                                    Text("\(hour)h").tag(hour)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            Picker("Minutes", selection: $durationMinutes) {
                                ForEach(0..<60) { minute in
                                    Text("\(minute)m").tag(minute)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        TextField("Distance (miles)", text: $distance)
                            .keyboardType(.decimalPad)
                    }
                } else {
                    Section(header: Text("Lifting Details")) {
                        TextField("Weight (lbs)", text: $weight)
                            .keyboardType(.decimalPad)
                        
                        TextField("Reps", text: $reps)
                            .keyboardType(.numberPad)
                        
                        TextField("Sets", text: $sets)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateExercise()
                    }
                    .disabled(!canSaveExercise)
                }
            }
        }
    }
    
    private var canSaveExercise: Bool {
        if exercise.type == .cardio {
            return !exerciseName.isEmpty && 
                   (durationHours > 0 || durationMinutes > 0) &&
                   !distance.isEmpty &&
                   Double(distance) != nil
        } else {
            return !exerciseName.isEmpty &&
                   !weight.isEmpty &&
                   !reps.isEmpty &&
                   !sets.isEmpty
        }
    }
    
    private func updateExercise() {
        var updatedExercise: Exercise
        
        if exercise.type == .cardio {
            guard let distanceValue = Double(distance), distanceValue > 0 else {
                return
            }
            
            let totalSeconds = TimeInterval(durationHours * 3600 + durationMinutes * 60)
            
            updatedExercise = Exercise(
                id: exercise.id,
                type: .cardio,
                name: exerciseName,
                duration: totalSeconds,
                distance: distanceValue
            )
        } else {
            guard let weightValue = Double(weight),
                  let repsValue = Int(reps),
                  let setsValue = Int(sets) else {
                return
            }
            
            updatedExercise = Exercise(
                id: exercise.id,
                type: .lifting,
                name: exerciseName,
                weight: weightValue,
                reps: repsValue,
                sets: setsValue
            )
        }
        
        appState.updateExercise(updatedExercise, in: workout)
        isPresented = false
    }
}

struct AddExerciseView: View {
    @EnvironmentObject var appState: AppState
    @Binding var exercises: [Exercise]
    @Binding var isPresented: Bool
    
    @State private var exerciseType: ExerciseType = .cardio
    @State private var exerciseName = ""
    
    // Cardio fields
    @State private var durationHours = 0
    @State private var durationMinutes = 0
    @State private var distance = ""
    
    // Lifting fields
    @State private var weight = ""
    @State private var reps = ""
    @State private var sets = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Exercise Type")) {
                    Picker("Type", selection: $exerciseType) {
                        ForEach(ExerciseType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Exercise Name")) {
                    if exerciseType == .cardio {
                        TextField("e.g., Running, Cycling", text: $exerciseName)
                    } else {
                        TextField("e.g., Bench Press, Squats", text: $exerciseName)
                    }
                }
                
                if exerciseType == .cardio {
                    Section(header: Text("Cardio Details")) {
                        
                        HStack {
                            Text("Duration")
                            Spacer()
                            Picker("Hours", selection: $durationHours) {
                                ForEach(0..<24) { hour in
                                    Text("\(hour)h").tag(hour)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            Picker("Minutes", selection: $durationMinutes) {
                                ForEach(0..<60) { minute in
                                    Text("\(minute)m").tag(minute)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        TextField("Distance (miles)", text: $distance)
                            .keyboardType(.decimalPad)
                    }
                } else {
                    Section(header: Text("Lifting Details")) {
                        
                        TextField("Weight (lbs)", text: $weight)
                            .keyboardType(.decimalPad)
                        
                        TextField("Reps", text: $reps)
                            .keyboardType(.numberPad)
                        
                        TextField("Sets", text: $sets)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                        resetFields()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addExercise()
                    }
                    .disabled(!canAddExercise)
                }
            }
        }
    }
    
    private var canAddExercise: Bool {
        if exerciseType == .cardio {
            return !exerciseName.isEmpty && 
                   (durationHours > 0 || durationMinutes > 0) &&
                   !distance.isEmpty &&
                   Double(distance) != nil
        } else {
            return !exerciseName.isEmpty &&
                   !weight.isEmpty &&
                   !reps.isEmpty &&
                   !sets.isEmpty
        }
    }
    
    private func addExercise() {
        if exerciseType == .cardio {
            guard let distanceValue = Double(distance), distanceValue > 0 else {
                return
            }
            
            let totalSeconds = TimeInterval(durationHours * 3600 + durationMinutes * 60)
            
            let exercise = Exercise(
                type: .cardio,
                name: exerciseName,
                duration: totalSeconds,
                distance: distanceValue
            )
            exercises.append(exercise)
        } else {
            guard let weightValue = Double(weight),
                  let repsValue = Int(reps),
                  let setsValue = Int(sets) else {
                return
            }
            
            let exercise = Exercise(
                type: .lifting,
                name: exerciseName,
                weight: weightValue,
                reps: repsValue,
                sets: setsValue
            )
            exercises.append(exercise)
        }
        
        resetFields()
        isPresented = false
    }
    
    private func resetFields() {
        exerciseName = ""
        durationHours = 0
        durationMinutes = 0
        distance = ""
        weight = ""
        reps = ""
        sets = ""
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
