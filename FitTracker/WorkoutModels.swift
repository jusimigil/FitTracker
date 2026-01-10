import Foundation

// Enum for workout types
enum WorkoutType: String, Codable, Equatable {
    case strength
    case run
    case walk
    case cycle
    case swim
}

struct Routine: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var description: String
    var exerciseNames: [String]
}

struct WorkoutSet: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var reps: Int
    var weight: Double
    var rpe: Int
}

struct Exercise: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var sets: [WorkoutSet] = []
}

struct WorkoutSession: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var exercises: [Exercise] = []
    
    // Status Flag
    var isCompleted: Bool = false  // <--- NEW FLAG
    
    var type: WorkoutType = .strength
    var distance: Double?
    var duration: TimeInterval?
    
    var averageHeartRate: Double?
    
    var latitude: Double?
    var longitude: Double?
    
    var totalVolume: Double {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
        }
    }
}
