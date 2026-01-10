import Foundation
import Combine
import SwiftUI

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var workouts: [WorkoutSession] = []
    @Published var bodyMetrics: [BodyMetric] = [] // <--- NEW LIST
    
    // Predefined Routines
    @Published var routines: [Routine] = [
        Routine(name: "Push Day", description: "Chest, Shoulders, Triceps", exercises: [
            ExerciseTemplate(name: "Bench Press", muscleGroup: .chest),
            ExerciseTemplate(name: "Overhead Press", muscleGroup: .shoulders),
            ExerciseTemplate(name: "Tricep Pushdowns", muscleGroup: .arms)
        ]),
        Routine(name: "Pull Day", description: "Back and Biceps", exercises: [
            ExerciseTemplate(name: "Deadlift", muscleGroup: .back),
            ExerciseTemplate(name: "Pull Ups", muscleGroup: .back),
            ExerciseTemplate(name: "Bicep Curls", muscleGroup: .arms)
        ]),
        Routine(name: "Leg Day", description: "Lower Body", exercises: [
            ExerciseTemplate(name: "Squats", muscleGroup: .legs),
            ExerciseTemplate(name: "Leg Press", muscleGroup: .legs)
        ])
    ]
    
    private let workoutFile = "workouts.json"
    private let metricsFile = "metrics.json" // <--- NEW FILE
    
    init() {
        loadWorkouts()
        loadMetrics()
    }
    
    // MARK: - Saving
    func save() {
        saveWorkouts()
        saveMetrics()
    }
    
    private func saveWorkouts() {
        if let encoded = try? JSONEncoder().encode(workouts) {
            let url = getDocumentsDirectory().appendingPathComponent(workoutFile)
            try? encoded.write(to: url)
        }
    }
    
    private func saveMetrics() {
        if let encoded = try? JSONEncoder().encode(bodyMetrics) {
            let url = getDocumentsDirectory().appendingPathComponent(metricsFile)
            try? encoded.write(to: url)
        }
    }
    
    // MARK: - Loading
    private func loadWorkouts() {
        let url = getDocumentsDirectory().appendingPathComponent(workoutFile)
        if let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: data) {
                workouts = decoded
                return
            }
        }
    }
    
    private func loadMetrics() {
        let url = getDocumentsDirectory().appendingPathComponent(metricsFile)
        if let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder().decode([BodyMetric].self, from: data) {
                bodyMetrics = decoded
                return
            }
        }
    }
    
    // MARK: - Helpers
    func addWorkout(_ session: WorkoutSession) {
        workouts.append(session)
        save()
    }
    
    // Inside DataManager class
        
        // Updated to accept optional weight
    func addMetric(weight: Double?, bodyFat: Double?) {
            let newMetric = BodyMetric(date: Date(), weight: weight, bodyFat: bodyFat)
            bodyMetrics.append(newMetric)
            save()
        }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // Add this inside DataManager class

    func restoreData(from url: URL) -> Bool {
            // We must access security scoped resources to read external files
            guard url.startAccessingSecurityScopedResource() else { return false }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                let backup = try JSONDecoder().decode(BackupData.self, from: data)
                
                // Overwrite current data
                DispatchQueue.main.async {
                    self.workouts = backup.workouts
                    self.bodyMetrics = backup.bodyMetrics
                    self.save() // Save immediately
                }
                return true
            } catch {
                print("Restore error: \(error)")
                return false
            }
        }
}
