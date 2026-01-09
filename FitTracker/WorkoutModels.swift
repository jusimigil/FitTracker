import Foundation

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
    
    // Helper to calculate total volume (weight x reps)
    var totalVolume: Double {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
        }
    }
}
