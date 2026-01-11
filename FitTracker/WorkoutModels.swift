import Foundation

enum WorkoutType: String, Codable, Equatable {
    case strength, run, walk, cycle, swim
}

enum MuscleGroup: String, Codable, CaseIterable {
    case chest = "Chest", back = "Back", legs = "Legs", shoulders = "Shoulders", arms = "Arms", core = "Core"
}

// Replace the old UserGoal enum with this specific one
enum RecompFocus: String, Codable, CaseIterable, Identifiable {
    case standard = "Standard Recomp"   // Balanced (The default)
    case fatLoss = "Fat Loss Focus"     // Slight Deficit, Higher Steps
    case muscle = "Muscle Focus"        // Maintenance Calories, Higher Volume
    
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
    var weight: Double
    var rpe: Int
}

struct Exercise: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var sets: [WorkoutSet] = []
    var muscleGroup: MuscleGroup = .chest
}

struct WorkoutSession: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var exercises: [Exercise] = []
    var isCompleted = false
    var notes: String = ""
    var type: WorkoutType = .strength
    var distance: Double?
    var duration: TimeInterval?
    var averageHeartRate: Double?
    var latitude: Double?
    var longitude: Double?
    
    // Stores the calories burned
    var activeCalories: Double?
    
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

// RESTORED: This is required for your Settings Export to work
struct BackupData: Codable {
    let workouts: [WorkoutSession]
    let bodyMetrics: [BodyMetric]
}
