import SwiftUI

struct RoutineSelectionView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    var onWorkoutCreated: ((UUID) -> Void)?
    
    // 1. The Specific Routines
    let routineNames = [
        "Back / Bi",
        "Chest / Tri",
        "Upper Body",
        "Lower Body",
        "Legs (Hamstring)",
        "Legs (Quads)",
        "Full Body"
    ]
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Select Routine")) {
                    ForEach(routineNames, id: \.self) { name in
                        Button(action: { createWorkout(routineName: name) }) {
                            HStack(alignment: .center) { // Align center so icon stays centered
                                Image(systemName: getIcon(for: name))
                                    .foregroundStyle(.blue)
                                    .frame(width: 30)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(name)
                                        .foregroundStyle(.primary)
                                        .font(.headline)
                                    
                                    // 2. SHOW EXERCISES INSTEAD OF "RESUME"
                                    if hasHistory(for: name) {
                                        Text(getLastExercises(for: name))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2) // Limit to 2 lines to keep UI clean
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
        return dataManager.workouts.contains(where: { $0.notes == name && $0.isCompleted })
    }
    
    // NEW FUNCTION: Fetch the list of exercises as a string
    func getLastExercises(for routineName: String) -> String {
        // Find the most recent completed session with this routine name
        if let lastSession = dataManager.workouts
            .filter({ $0.notes == routineName && $0.isCompleted })
            .sorted(by: { $0.date > $1.date }) // Newest first
            .first {
            
            let names = lastSession.exercises.map { $0.name }
            if names.isEmpty { return "No exercises recorded" }
            return names.joined(separator: ", ")
        }
        return ""
    }
    
    func createWorkout(routineName: String) {
        var newSession = WorkoutSession(date: Date(), type: .strength)
        newSession.notes = routineName // Save Routine Name in notes for next time
        
        // MEMORY SYSTEM
        if let lastSession = dataManager.workouts
            .filter({ $0.notes == routineName && $0.isCompleted })
            .sorted(by: { $0.date > $1.date })
            .first {
            
            // Copy exercises (Names + Muscle Group) but clear sets
            for oldEx in lastSession.exercises {
                var newEx = Exercise(name: oldEx.name)
                newEx.muscleGroup = oldEx.muscleGroup
                newSession.exercises.append(newEx)
            }
        }
        
        dataManager.workouts.append(newSession)
        dataManager.save()
        
        dismiss()
        
        // Delay navigation slightly to allow sheet to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onWorkoutCreated?(newSession.id)
        }
    }
    
    func getIcon(for name: String) -> String {
        if name.contains("Legs") || name.contains("Lower") { return "figure.walk" }
        if name.contains("Full") { return "figure.cross.training" }
        return "dumbbell.fill"
    }
}
