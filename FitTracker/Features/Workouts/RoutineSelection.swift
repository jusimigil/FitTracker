import SwiftUI

struct RoutineSelectionView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    var recommendedMuscle: MuscleGroup?
    var onWorkoutCreated: ((UUID) -> Void)?
    
    let routineNames = [
        "Pull",
        "Push",
        "Upper Body",
        "Lower Body",
        "Legs",
        "Posterior",
        "Anterior",
        "Full Body"
    ]
    
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
        }
    }
    
    // MARK: - LOGIC
    
    func hasHistory(for name: String) -> Bool {
        // Checks both the new Title field AND the old Notes field for backward compatibility
        return dataManager.workouts.contains(where: { ($0.workoutTitle == name || $0.notes == name) && $0.isCompleted })
    }
    
    func getLastExercises(for routineName: String) -> String {
        if let lastSession = dataManager.workouts
            .filter({ ($0.workoutTitle == routineName || $0.notes == routineName) && $0.isCompleted })
            .sorted(by: { $0.date > $1.date })
            .first {
            
            let names = lastSession.exercises.map { $0.name }
            if names.isEmpty { return "No exercises recorded" }
            return names.joined(separator: ", ")
        }
        return ""
    }
    
    func createWorkout(routineName: String) {
        workoutStartHaptic()
        
        var newSession = WorkoutSession(
            date: Date(),
            type: .strength
        )
        
        // NEW: Set the Title explicitly
        newSession.workoutTitle = routineName
        
        // MEMORY SYSTEM: If previous log exists, copy exercises (but clear sets)
        if let lastSession = dataManager.workouts
            .filter({ ($0.workoutTitle == routineName || $0.notes == routineName) && $0.isCompleted })
            .sorted(by: { $0.date > $1.date })
            .first {
            
            for oldEx in lastSession.exercises {
                var newEx = Exercise(name: oldEx.name)
                newEx.muscleGroup = oldEx.muscleGroup
                newSession.exercises.append(newEx)
            }
        }
        
        dataManager.workouts.append(newSession)
        dataManager.save()
        
        dismiss()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onWorkoutCreated?(newSession.id)
        }
    }
    
    func createRecommendedWorkout(for muscle: MuscleGroup) {
        
        let routineName: String
        
        switch muscle {
        case .chest:
            routineName = "Push"
            
        case .back:
            routineName = "Pull"
            
        case .legs:
            routineName = "Lower Body"
            
        case .shoulders:
            routineName = "Upper Body"
            
        case .arms:
            routineName = "Upper Body"
            
        case .core:
            routineName = "Full Body"
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
