import SwiftUI
import CoreLocation

struct RoutineSelectionView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    // We use a local LocationManager here to tag the workout
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        NavigationStack {
            List {
                // Option 1: Start Empty
                Section {
                    Button(action: { startRoutine(nil) }) {
                        Label("Empty Workout", systemImage: "plus.square.dashed")
                            .font(.headline)
                            .padding(.vertical, 5)
                    }
                }
                
                // Option 2: Predefined Routines
                Section(header: Text("My Routines")) {
                    ForEach(dataManager.routines) { routine in
                        Button(action: { startRoutine(routine) }) {
                            VStack(alignment: .leading) {
                                Text(routine.name)
                                    .font(.headline)
                                Text(routine.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
            }
            .navigationTitle("Choose Routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    func startRoutine(_ routine: Routine?) {
        var newSession = WorkoutSession(date: Date(), type: .strength)
        
        // 1. Pre-fill exercises if a routine was picked
        if let routine = routine {
            for name in routine.exerciseNames {
                let exercise = Exercise(name: name)
                newSession.exercises.append(exercise)
            }
        }
        
        // 2. Tag Location (if found)
        if let location = locationManager.userLocation {
            newSession.latitude = location.latitude
            newSession.longitude = location.longitude
        }
        
        // 3. Save & Close
        dataManager.addWorkout(newSession)
        dismiss()
    }
}
