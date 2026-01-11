import SwiftUI
internal import _LocationEssentials

struct RoutineSelectionView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager()
    
    // Alert State
    @State private var showingActiveWorkoutAlert = false
    @State private var pendingRoutine: Routine? // Stores the routine you wanted to start
    
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
            // MARK: - UPDATED ALERT LOGIC
            .alert("Active Workout Found", isPresented: $showingActiveWorkoutAlert) {
                Button("Discard Old & Start New", role: .destructive) {
                    // 1. Delete the "stuck" workout
                    dataManager.workouts.removeAll(where: { !$0.isCompleted })
                    dataManager.save()
                    
                    // 2. Start the one the user actually wanted
                    startRoutine(pendingRoutine)
                }
                Button("Cancel", role: .cancel) {
                    pendingRoutine = nil
                }
            } message: {
                Text("You have an unfinished workout in progress. Do you want to discard it and start this new one?")
            }
        }
    }
    
    // Logic: Check for active workouts first
    func attemptStart(_ routine: Routine?) {
        // If there is a "Zombie" workout (not completed), stop and ask
        if dataManager.workouts.contains(where: { !$0.isCompleted }) {
            pendingRoutine = routine // Remember what they clicked
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
