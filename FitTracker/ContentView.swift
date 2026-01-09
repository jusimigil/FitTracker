import SwiftUI
import Combine
import Foundation

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationStack {
            List {
                Button(action: startNewSession) {
                    Label("Start Workout", systemImage: "plus")
                        .font(.headline)
                        .padding()
                }
                .listRowBackground(Color.blue)
                .foregroundStyle(.white)
                
                Section(header: Text("History")) {
                    if dataManager.workouts.isEmpty {
                        Text("No workouts yet")
                    } else {
                        // Sort by date (newest first)
                        ForEach(dataManager.workouts.sorted(by: { $0.date > $1.date })) { session in
                            NavigationLink(destination: SessionDetailView(workoutID: session.id)) {
                                VStack(alignment: .leading) {
                                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.headline)
                                    Text("\(Int(session.totalVolume)) lbs total")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteWorkout)
                    }
                }
            }
            .navigationTitle("FitTracker")
        }
    }
    
    func startNewSession() {
        let newSession = WorkoutSession(date: Date())
        dataManager.addWorkout(newSession)
    }
    
    func deleteWorkout(at offsets: IndexSet) {
        // Find the actual item to delete since the list is sorted
        let sortedList = dataManager.workouts.sorted(by: { $0.date > $1.date })
        offsets.forEach { index in
            let sessionToDelete = sortedList[index]
            if let indexInMain = dataManager.workouts.firstIndex(where: { $0.id == sessionToDelete.id }) {
                dataManager.workouts.remove(at: indexInMain)
            }
        }
        dataManager.save()
    }
}
