import SwiftUI
internal import _LocationEssentials

struct RoutineSelection: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager()
    
    // Alert State
    @State private var showingActiveWorkoutAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Empty Workout") { attemptStart(nil) }
                }
                
                Section(header: Text("Routines")) {
                    ForEach(dataManager.routines) { routine in
                        Button(routine.name) { attemptStart(routine) }
                    }
                }
            }
            .navigationTitle("Choose Routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Active Workout Found", isPresented: $showingActiveWorkoutAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You already have an unfinished workout. Please finish it before starting a new one.")
            }
        }
    }
    
    // New Logic: Check for active workouts first
    func attemptStart(_ routine: Routine?) {
        // Check if ANY workout in history is NOT completed
        if dataManager.workouts.contains(where: { !$0.isCompleted }) {
            showingActiveWorkoutAlert = true
        } else {
            startRoutine(routine)
        }
    }
    
    func startRoutine(_ routine: Routine?) {
        var newSession = WorkoutSession(date: Date(), type: .strength)
        
        if let routine = routine {
            for template in routine.exercises {
                let exercise = Exercise(name: template.name, muscleGroup: template.muscleGroup)
                newSession.exercises.append(exercise)
            }
        }
        
        if let loc = locationManager.userLocation {
            newSession.latitude = loc.latitude
            newSession.longitude = loc.longitude
        }
        
        dataManager.addWorkout(newSession)
        dismiss()
    }
}
