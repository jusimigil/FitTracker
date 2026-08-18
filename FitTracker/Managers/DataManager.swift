import Foundation
import Combine
import SwiftUI

// 1. NEW: Define Weight Unit Enum
enum WeightUnit: String, Codable, CaseIterable {
    case lbs = "lbs"
    case kg = "kg"
}

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var workouts: [WorkoutSession] = []
    @Published var bodyMetrics: [BodyMetric] = []
    @Published var personalRecords: [PersonalRecord] = []
    @Published var recoveryHistory: [RecoveryEntry] = []
    
    // 2. NEW: Global Settings for Units
    @AppStorage("weightUnit") var weightUnit: WeightUnit = .lbs
    
    // MARK: - Weight Conversion
    //
    // All workout and body-weight data is stored internally in kilograms.
    // These helpers convert between the user's preferred display unit
    // and the canonical kilogram value.

    func kilograms(fromDisplayedWeight weight: Double) -> Double {
        switch weightUnit {
        case .kg:
            return weight
        case .lbs:
            return weight * 0.45359237
        }
    }

    func displayedWeight(fromKilograms kilograms: Double) -> Double {
        switch weightUnit {
        case .kg:
            return kilograms
        case .lbs:
            return kilograms * 2.20462262
        }
    }

    func formatWeight(_ kilograms: Double, decimals: Int = 1) -> String {
        let value = displayedWeight(fromKilograms: kilograms)
        let unit = weightUnit.rawValue

        return String(format: "%.\(decimals)f %@", value, unit)
    }

    func formatVolume(_ kilogramVolume: Double) -> String {
        let value = displayedWeight(fromKilograms: kilogramVolume)
        let unit = weightUnit.rawValue

        if value >= 1_000_000 {
            return String(format: "%.1fM %@", value / 1_000_000, unit)
        }

        if value >= 1_000 {
            return String(format: "%.1fk %@", value / 1_000, unit)
        }

        return String(format: "%.0f %@", value, unit)
    }
    
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
            ExerciseTemplate(name: "Leg Press", muscleGroup: .legs),
            ExerciseTemplate(name: "Calf Raises", muscleGroup: .legs)
        ]),
        // 3. NEW ROUTINES ADDED
        Routine(name: "Core Focus", description: "Abs and Stability", exercises: [
            ExerciseTemplate(name: "Plank", muscleGroup: .core),
            ExerciseTemplate(name: "Hanging Leg Raise", muscleGroup: .core),
            ExerciseTemplate(name: "Cable Woodchoppers", muscleGroup: .core)
        ]),
        Routine(name: "Shoulders & Arms", description: "Upper Body Accessory", exercises: [
            ExerciseTemplate(name: "Lateral Raises", muscleGroup: .shoulders),
            ExerciseTemplate(name: "Hammer Curls", muscleGroup: .arms),
            ExerciseTemplate(name: "Skullcrushers", muscleGroup: .arms)
        ])
    ]
    
    private let workoutFile = "workouts.json"
    private let metricsFile = "metrics.json"
    private let personalRecordsFile = "personal_records.json"
    private let recoveryFile = "recovery_history.json"

    private let weightStorageVersionKey = "weightStorageVersion"
    private let currentWeightStorageVersion = 1
    
    init() {
        loadWorkouts()
        loadMetrics()
        loadPersonalRecords()
        loadRecoveryHistory()
        migrateWeightStorageIfNeeded()
    }
    
    // MARK: - Saving
    func save() {
        saveWorkouts()
        saveMetrics()
        savePersonalRecords()
        saveRecoveryHistory()
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
    
    private func savePersonalRecords() {
        if let encoded = try? JSONEncoder().encode(personalRecords) {
            let url = getDocumentsDirectory()
                .appendingPathComponent(personalRecordsFile)
            
            try? encoded.write(to: url)
        }
    }
    
    private func saveRecoveryHistory() {
        if let encoded = try? JSONEncoder().encode(recoveryHistory) {
            let url = getDocumentsDirectory()
                .appendingPathComponent(recoveryFile)
            
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
    
    private func loadRecoveryHistory() {
        let url = getDocumentsDirectory()
            .appendingPathComponent(recoveryFile)
        
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder()
                .decode([RecoveryEntry].self, from: data) {
            recoveryHistory = decoded
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
    
    private func loadPersonalRecords() {
        let url = getDocumentsDirectory()
            .appendingPathComponent(personalRecordsFile)
        
        if let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder()
                .decode([PersonalRecord].self, from: data) {
                
                personalRecords = decoded
                return
            }
        }
    }
    
    // MARK: - Helpers
    func addWorkout(_ session: WorkoutSession) {
        workouts.append(session)
        save()
    }
    
    func addMetric(weight: Double?, bodyFat: Double?) {
        let newMetric = BodyMetric(date: Date(), weight: weight, bodyFat: bodyFat)
        bodyMetrics.append(newMetric)
        save()
    }
    
    func restoreData(from url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            let backup = try JSONDecoder().decode(BackupData.self, from: data)
            DispatchQueue.main.async {
                self.workouts = backup.workouts
                self.bodyMetrics = backup.bodyMetrics
                self.save()
            }
            return true
        } catch {
            print("Restore error: \(error)")
            return false
        }
    }
    
    // MARK: - Data Migration

    private func migrateWeightStorageIfNeeded() {
        let storedVersion = UserDefaults.standard.integer(
            forKey: weightStorageVersionKey
        )
        
        guard storedVersion < currentWeightStorageVersion else {
            return
        }
        
        // Existing versions of FitTracker stored workout weights in lbs.
        // Convert them once to our new canonical kg storage format.
        for workoutIndex in workouts.indices {
            for exerciseIndex in workouts[workoutIndex].exercises.indices {
                for setIndex in workouts[workoutIndex].exercises[exerciseIndex].sets.indices {
                    
                    let oldWeightInLbs =
                        workouts[workoutIndex]
                            .exercises[exerciseIndex]
                            .sets[setIndex]
                            .weight
                    
                    workouts[workoutIndex]
                        .exercises[exerciseIndex]
                        .sets[setIndex]
                        .weight = oldWeightInLbs * 0.45359237
                }
            }
        }
        
        // Body metrics were also previously treated as lbs.
        for metricIndex in bodyMetrics.indices {
            if let oldWeightInLbs = bodyMetrics[metricIndex].weight {
                bodyMetrics[metricIndex].weight =
                    oldWeightInLbs * 0.45359237
            }
        }
        
        UserDefaults.standard.set(
            currentWeightStorageVersion,
            forKey: weightStorageVersionKey
        )
        
        save()
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func addPersonalRecords(_ records: [PersonalRecord]) {
        guard !records.isEmpty else {
            return
        }
        
        personalRecords.append(contentsOf: records)
        save()
    }


    // MARK: - Replace Exercise PRs

    func replacePersonalRecords(
        for workoutID: UUID,
        exerciseName: String,
        with records: [PersonalRecord]
    ) {
        personalRecords.removeAll { record in
            record.workoutID == workoutID &&
            record.exerciseName.caseInsensitiveCompare(exerciseName) == .orderedSame
        }
        
        personalRecords.append(contentsOf: records)
        
        save()
    }
}
