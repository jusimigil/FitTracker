import SwiftUI

struct RoutineSelectionView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    var onWorkoutCreated: ((UUID) -> Void)?
    
    // UPDATED: Templates now include a list of default exercises
    let templates: [(name: String, type: WorkoutType, icon: String, exercises: [String])] = [
        ("Push Day", .strength, "dumbbell.fill", ["Bench Press", "Overhead Press", "Tricep Pushdown"]),
        ("Pull Day", .strength, "figure.strengthtraining.traditional", ["Lat Pulldown", "Barbell Row", "Bicep Curl"]),
        ("Leg Day", .strength, "figure.cross.training", ["Squat", "Leg Press", "Calf Raise"]),
        ("Full Body", .strength, "figure.mind.and.body", ["Squat", "Bench Press", "Barbell Row"]),
        ("Run / Cardio", .run, "figure.run", ["Outdoor Run"])
    ]
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Choose a Template")) {
                    ForEach(templates, id: \.name) { template in
                        Button(action: { createWorkout(template: template) }) {
                            HStack {
                                Image(systemName: template.icon)
                                    .foregroundStyle(.blue)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text(template.name).foregroundStyle(.primary)
                                    // Show a preview of exercises
                                    Text(template.exercises.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("Custom")) {
                    Button("Empty Workout") {
                        createWorkout(template: ("New Workout", .strength, "", []))
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
    
    // UPDATED: Now accepts the full template tuple
    func createWorkout(template: (name: String, type: WorkoutType, icon: String, exercises: [String])) {
        var newSession = WorkoutSession(date: Date(), type: template.type)
        newSession.notes = template.name
        
        // Populate predefined exercises
        for exerciseName in template.exercises {
            newSession.exercises.append(Exercise(name: exerciseName))
        }
        
        dataManager.workouts.append(newSession)
        dataManager.save()
        
        dismiss()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onWorkoutCreated?(newSession.id)
        }
    }
}
