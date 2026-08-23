import SwiftUI

struct RoutineSelectionView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showActiveWorkoutAlert = false
    
    var recommendedMuscle: MuscleGroup?
    var onWorkoutCreated: ((UUID) -> Void)?
    
    var routineNames: [String] {
        dataManager.routines.map(\.name)
    }
    var body: some View {
        NavigationStack {
            List {
                if let muscle = recommendedMuscle {
                    Section {
                        Button {
                            createRecommendedWorkout(for: muscle)
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.yellow)
                                    .font(.title2)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Recommended for You")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    Text("Focus on \(muscle.rawValue)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                Section(header: Text("Select Routine")) {
                    ForEach(routineNames, id: \.self) { name in
                        Button(action: { createWorkout(routineName: name) }) {
                            HStack(alignment: .center) {
                                Image(systemName: getIcon(for: name))
                                    .foregroundStyle(.blue)
                                    .frame(width: 30)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(name)
                                        .foregroundStyle(.primary)
                                        .font(.headline)
                                    
                                    if hasHistory(for: name) {
                                        Text(getLastExercises(for: name))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    } else {
                                        Text("New (Blank)")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                }
                                
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section(header: Text("Custom")) {
                    Button(action: { createWorkout(routineName: "New Routine") }) {
                        Label("Empty Workout", systemImage: "plus.square.dashed")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("Start Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        } .alert(
            "Workout Already in Progress",
            isPresented: $showActiveWorkoutAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            if let activeWorkout = dataManager.activeWorkout {
                Text(
                    "\(activeWorkout.workoutTitle ?? "Your current workout") is still in progress. Finish it before starting another workout."
                )
            } else {
                Text(
                    "Finish your current workout before starting another one."
                )
            }
        }
    }
    
    // MARK: - LOGIC
    
    func hasHistory(for name: String) -> Bool {
        // Checks both the new Title field AND the old Notes field for backward compatibility
        return dataManager.completedWorkouts.contains {
            $0.workoutTitle == name || $0.notes == name
        }
    }
    
    func getLastExercises(for routineName: String) -> String {
        let previousSessions = dataManager.completedWorkouts
            .filter {
                $0.workoutTitle == routineName ||
                $0.notes == routineName
            }
            .sorted {
                $0.date > $1.date
            }

        if let lastSession = previousSessions.first {
            let names = lastSession.exercises.map { $0.name }

            if names.isEmpty {
                return "No exercises recorded"
            }

            return names.joined(separator: ", ")
        }

        return ""
    }
    
    func createWorkout(routineName: String) {
        
        guard dataManager.activeWorkout == nil else {
                showActiveWorkoutAlert = true
                return
            }
        
        workoutStartHaptic()

        var newSession = WorkoutSession(
            date: Date(),
            type: .strength
        )

        newSession.workoutTitle = routineName

        // Prefer the user's previous version of this routine.
        let previousSessions = dataManager.completedWorkouts
            .filter {
                $0.workoutTitle == routineName ||
                $0.notes == routineName
            }
            .sorted {
                $0.date > $1.date
            }

        if let lastSession = previousSessions.first {
            for oldExercise in lastSession.exercises {
                var newExercise = Exercise(name: oldExercise.name)

                newExercise.muscleGroup =
                    oldExercise.resolvedMuscleGroup

                newSession.exercises.append(newExercise)
            }
        } else if let routine = dataManager.routines.first(
            where: { $0.name == routineName }
        ) {

            for template in routine.exercises {
                var newExercise = Exercise(
                    name: template.name
                )

                newExercise.muscleGroup =
                    ExerciseCatalog.muscle(
                        for: template.name
                    ) ?? template.muscleGroup

                newSession.exercises.append(newExercise)
            }
        }

        dataManager.workouts.append(newSession)
        dataManager.save()

        dismiss()

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.5
        ) {
            onWorkoutCreated?(newSession.id)
        }
    }
    
    func createRecommendedWorkout(
        for muscle: MuscleGroup
    ) {
        let routineName: String?

        switch muscle {
        case .chest:
            routineName = dataManager.routines.first {
                $0.name == "Push Day"
            }?.name

        case .back:
            routineName = dataManager.routines.first {
                $0.name == "Pull Day"
            }?.name

        case .legs:
            routineName = dataManager.routines.first {
                $0.name == "Leg Day"
            }?.name

        case .shoulders:
            routineName = dataManager.routines.first {
                $0.exercises.contains {
                    $0.muscleGroup == .shoulders
                }
            }?.name

        case .arms:
            routineName = dataManager.routines.first {
                $0.exercises.contains {
                    $0.muscleGroup == .arms
                }
            }?.name

        case .core:
            routineName = dataManager.routines.first {
                $0.exercises.contains {
                    $0.muscleGroup == .core
                }
            }?.name
        }

        guard let routineName else {
            return
        }

        createWorkout(routineName: routineName)
    }
    func getIcon(for name: String) -> String {
        if name.contains("Legs") || name.contains("Lower") { return "figure.walk" }
        if name.contains("Full") { return "figure.cross.training" }
        return "dumbbell.fill"
    }
    
    func workoutStartHaptic() {
        let generator = UIImpactFeedbackGenerator(
            style: .medium
        )
        generator.prepare()
        generator.impactOccurred()
    }
}
