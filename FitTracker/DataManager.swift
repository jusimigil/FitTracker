import Foundation
import SwiftUI
import Combine

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var workouts: [WorkoutSession] = []
    
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
