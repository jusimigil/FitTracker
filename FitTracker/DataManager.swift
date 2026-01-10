import Foundation
import SwiftUI
import Combine

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var workouts: [WorkoutSession] = []
    
    @Published var routines: [Routine] = [
            Routine(name: "Push Day", description: "Chest, Shoulders, Triceps", exerciseNames: ["Bench Press", "Overhead Press", "Incline Dumbbell Press", "Lateral Raises", "Tricep Pushdowns"]),
            Routine(name: "Pull Day", description: "Back, Biceps, Rear Delts", exerciseNames: ["Deadlift", "Pull Ups", "Barbell Rows", "Face Pulls", "Bicep Curls"]),
            Routine(name: "Leg Day", description: "Quads, Hamstrings, Calves", exerciseNames: ["Squats", "Leg Press", "Romanian Deadlifts", "Leg Extensions", "Calf Raises"]),
            Routine(name: "Full Body", description: "Compound Movements", exerciseNames: ["Squats", "Bench Press", "Deadlift", "Overhead Press", "Pull Ups"])
        ]
    
    private let fileName = "workouts.json"
    
    init() {
        load()
    }
    
    // Save to file
    func save() {
        do {
            let data = try JSONEncoder().encode(workouts)
            let url = getDocumentsDirectory().appendingPathComponent(fileName)
            try data.write(to: url)
        } catch {
            print("Failed to save data: \(error.localizedDescription)")
        }
    }
    
    // Load from file
    func load() {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            let data = try Data(contentsOf: url)
            workouts = try JSONDecoder().decode([WorkoutSession].self, from: data)
        } catch {
            print("No data found, starting fresh.")
            workouts = []
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // Helper to add a workout
    func addWorkout(_ session: WorkoutSession) {
        workouts.append(session)
        save()
    }
}
