import Foundation

enum WorkoutType: String, Codable, Equatable {
    case strength, run, walk, cycle, swim
}

enum MuscleGroup: String, Codable, CaseIterable {
    case chest = "Chest", back = "Back", legs = "Legs", shoulders = "Shoulders", arms = "Arms", core = "Core"
}

enum RecompFocus: String, Codable, CaseIterable, Identifiable {
    case standard = "Standard Recomp"
    case fatLoss = "Fat Loss Focus"
    case muscle = "Muscle Focus"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .standard: return "Simultaneous fat loss & muscle gain. 12-15 sets/week."
        case .fatLoss: return "Prioritizes fat burn. Higher step count, 10-12 sets/week."
        case .muscle: return "Prioritizes size. Maintenance calories, 15-18 sets/week."
        }
    }
}

struct Routine: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var description: String
    var exercises: [ExerciseTemplate]
}

struct ExerciseTemplate: Codable, Hashable {
    var name: String
    var muscleGroup: MuscleGroup
}

struct WorkoutSet: Identifiable, Codable, Equatable {
    var id = UUID()
    var reps: Int
    
    /// Weight is ALWAYS stored in kilograms.
    /// The UI converts this value to the user's preferred unit.
    var weight: Double
    
    var rpe: Int
}

struct Exercise: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var sets: [WorkoutSet] = []
    var muscleGroup: MuscleGroup = .chest
    
    var resolvedMuscleGroup: MuscleGroup {
        ExerciseCatalog.muscle(for: name) ?? muscleGroup
    }
}

struct WorkoutSession: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var exercises: [Exercise] = []
    var isCompleted = false
    var notes: String = ""
    var type: WorkoutType = .strength
    
    // NEW: Dedicated Title Field
    var workoutTitle: String?
    
    var distance: Double?
    var duration: TimeInterval?
    var averageHeartRate: Double?
    var latitude: Double?
    var longitude: Double?
    var activeCalories: Double?
    
    var imageID: String?
    
    var workoutSongTitle: String?
    var workoutSongArtist: String?
    var workoutSongCoverURL: String?
    
    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) } }
    }
}

struct BodyMetric: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var weight: Double?
    var bodyFat: Double?
}

struct BackupData: Codable {
    let workouts: [WorkoutSession]
    let bodyMetrics: [BodyMetric]
}
