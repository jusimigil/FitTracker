import Foundation

struct ExerciseDefinition: Identifiable {
    let id: String
    let name: String
    let primaryMuscle: MuscleGroup
}

enum ExerciseCatalog {
    
    static let all: [ExerciseDefinition] = [
        
        // Chest
        ExerciseDefinition(
            id: "bench_press",
            name: "Bench Press",
            primaryMuscle: .chest
        ),
        ExerciseDefinition(
            id: "incline_bench_press",
            name: "Incline Bench Press",
            primaryMuscle: .chest
        ),
        ExerciseDefinition(
            id: "chest_fly",
            name: "Chest Fly",
            primaryMuscle: .chest
        ),
        
        // Back
        ExerciseDefinition(
            id: "deadlift",
            name: "Deadlift",
            primaryMuscle: .back
        ),
        ExerciseDefinition(
            id: "pull_ups",
            name: "Pull Ups",
            primaryMuscle: .back
        ),
        ExerciseDefinition(
            id: "barbell_row",
            name: "Barbell Row",
            primaryMuscle: .back
        ),
        ExerciseDefinition(
            id: "lat_pulldown",
            name: "Lat Pulldown",
            primaryMuscle: .back
        ),
        
        // Legs
        ExerciseDefinition(
            id: "squat",
            name: "Squats",
            primaryMuscle: .legs
        ),
        ExerciseDefinition(
            id: "leg_press",
            name: "Leg Press",
            primaryMuscle: .legs
        ),
        ExerciseDefinition(
            id: "romanian_deadlift",
            name: "Romanian Deadlift",
            primaryMuscle: .legs
        ),
        ExerciseDefinition(
            id: "calf_raise",
            name: "Calf Raises",
            primaryMuscle: .legs
        ),
        
        // Shoulders
        ExerciseDefinition(
            id: "overhead_press",
            name: "Overhead Press",
            primaryMuscle: .shoulders
        ),
        ExerciseDefinition(
            id: "lateral_raise",
            name: "Lateral Raises",
            primaryMuscle: .shoulders
        ),
        ExerciseDefinition(
            id: "rear_delt_fly",
            name: "Rear Delt Fly",
            primaryMuscle: .shoulders
        ),
        
        // Arms
        ExerciseDefinition(
            id: "bicep_curl",
            name: "Bicep Curls",
            primaryMuscle: .arms
        ),
        ExerciseDefinition(
            id: "hammer_curl",
            name: "Hammer Curls",
            primaryMuscle: .arms
        ),
        ExerciseDefinition(
            id: "tricep_pushdown",
            name: "Tricep Pushdowns",
            primaryMuscle: .arms
        ),
        ExerciseDefinition(
            id: "skullcrusher",
            name: "Skullcrushers",
            primaryMuscle: .arms
        ),
        
        // Core
        ExerciseDefinition(
            id: "plank",
            name: "Plank",
            primaryMuscle: .core
        ),
        ExerciseDefinition(
            id: "hanging_leg_raise",
            name: "Hanging Leg Raise",
            primaryMuscle: .core
        ),
        ExerciseDefinition(
            id: "cable_woodchopper",
            name: "Cable Woodchoppers",
            primaryMuscle: .core
        )
    ]
    
    static func definition(
        for name: String
    ) -> ExerciseDefinition? {
        all.first {
            $0.name.caseInsensitiveCompare(name)
                == .orderedSame
        }
    }
    
    static func muscle(
        for name: String
    ) -> MuscleGroup? {
        definition(for: name)?.primaryMuscle
    }
    
    static func exercises(
        for muscle: MuscleGroup
    ) -> [ExerciseDefinition] {
        all.filter {
            $0.primaryMuscle == muscle
        }
    }
}
