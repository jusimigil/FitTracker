import Foundation

struct PersonalRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var exerciseName: String
    var type: PRType
    var weight: Double
    var reps: Int
    var estimatedOneRepMax: Double
    var date: Date
    var workoutID: UUID?
}

enum PRType: String, Codable {
    case heaviestWeight = "Heaviest Weight"
    case repRecord = "Rep Record"
    case estimatedOneRepMax = "Estimated 1RM"
}

final class PRManager {
    
    static let shared = PRManager()
    
    private init() {}
    
    
    // MARK: - Estimated 1RM
    
    func estimatedOneRepMax(
        weight: Double,
        reps: Int
    ) -> Double {
        
        guard weight > 0, reps > 0 else {
            return 0
        }
        
        // Epley formula
        return weight * (1.0 + Double(reps) / 30.0)
    }
    
    
    // MARK: - Previous Sets
    
    private func previousSets(
        for exerciseName: String,
        in workouts: [WorkoutSession],
        excludingWorkoutID: UUID? = nil
    ) -> [WorkoutSet] {
        
        workouts
            .filter { workout in
                
                // PRs should only compare against
                // completed workouts.
                guard workout.isCompleted else {
                    return false
                }
                
                // When editing a completed workout,
                // don't compare the edited workout against itself.
                if let excludingWorkoutID,
                   workout.id == excludingWorkoutID {
                    return false
                }
                
                return true
            }
            .flatMap { workout in
                
                workout.exercises
                    .filter {
                        $0.name.caseInsensitiveCompare(
                            exerciseName
                        ) == .orderedSame
                    }
                    .flatMap {
                        $0.sets
                    }
            }
    }
    
    
    // MARK: - Check PR
    
    func checkForPR(
        exercise: Exercise,
        newSet: WorkoutSet,
        workouts: [WorkoutSession],
        workoutID: UUID,
        excludingWorkoutID: UUID? = nil
    ) -> [PersonalRecord] {
        
        var records: [PersonalRecord] = []
        
        let oldSets = previousSets(
            for: exercise.name,
            in: workouts,
            excludingWorkoutID: excludingWorkoutID
        )
        
        
        // MARK: Previous Bests
        
        let previousHeaviest =
            oldSets.map(\.weight).max() ?? 0
        
        let previousBest1RM =
            oldSets
                .map {
                    estimatedOneRepMax(
                        weight: $0.weight,
                        reps: $0.reps
                    )
                }
                .max() ?? 0
        
        
        // MARK: 1. Heaviest Weight
        
        if newSet.weight > previousHeaviest {
            
            records.append(
                PersonalRecord(
                    exerciseName: exercise.name,
                    type: .heaviestWeight,
                    weight: newSet.weight,
                    reps: newSet.reps,
                    estimatedOneRepMax: estimatedOneRepMax(
                        weight: newSet.weight,
                        reps: newSet.reps
                    ),
                    date: Date(),
                    workoutID: workoutID
                )
            )
        }
        
        
        // MARK: 2. Rep Record
        
        let sameWeightSets = oldSets.filter {
            abs($0.weight - newSet.weight) < 0.01
        }
        
        let previousBestReps =
            sameWeightSets
                .map(\.reps)
                .max() ?? 0
        
        /*
         A lower weight should not create a PR.
         
         Therefore, a Rep Record must also be
         performed at at least the previous
         heaviest weight.
        */
        let qualifiesForRepRecord =
            newSet.weight >= previousHeaviest &&
            newSet.reps > previousBestReps
        
        if qualifiesForRepRecord {
            
            records.append(
                PersonalRecord(
                    exerciseName: exercise.name,
                    type: .repRecord,
                    weight: newSet.weight,
                    reps: newSet.reps,
                    estimatedOneRepMax: estimatedOneRepMax(
                        weight: newSet.weight,
                        reps: newSet.reps
                    ),
                    date: Date(),
                    workoutID: workoutID
                )
            )
        }
        
        
        // MARK: 3. Estimated 1RM
        
        let new1RM = estimatedOneRepMax(
            weight: newSet.weight,
            reps: newSet.reps
        )
        
        if new1RM > previousBest1RM {
            
            records.append(
                PersonalRecord(
                    exerciseName: exercise.name,
                    type: .estimatedOneRepMax,
                    weight: newSet.weight,
                    reps: newSet.reps,
                    estimatedOneRepMax: new1RM,
                    date: Date(),
                    workoutID: workoutID
                )
            )
        }
        
        return records
    }
    
    // MARK: - Recalculate Exercise PRs

    // MARK: - Recalculate Exercise PRs

    func recalculatePRs(
        exercise: Exercise,
        workouts: [WorkoutSession],
        workoutID: UUID
    ) -> [PersonalRecord] {
        
        var records: [PersonalRecord] = []
        
        // Only compare against completed workouts
        // other than the workout currently being edited.
        let historicalSets = previousSets(
            for: exercise.name,
            in: workouts,
            excludingWorkoutID: workoutID
        )
        
        // MARK: Historical Bests
        
        let historicalBestWeight =
            historicalSets.map(\.weight).max() ?? 0
        
        let historicalBest1RM =
            historicalSets
                .map {
                    estimatedOneRepMax(
                        weight: $0.weight,
                        reps: $0.reps
                    )
                }
                .max() ?? 0
        
        
        // MARK: Best Set in Current Workout
        
        guard !exercise.sets.isEmpty else {
            return []
        }
        
        
        // Best weight achieved in this workout.
        let bestWeightSet =
            exercise.sets.max {
                $0.weight < $1.weight
            }
        
        
        // Best 1RM achieved in this workout.
        let best1RMSet =
            exercise.sets.max {
                estimatedOneRepMax(
                    weight: $0.weight,
                    reps: $0.reps
                )
                <
                estimatedOneRepMax(
                    weight: $1.weight,
                    reps: $1.reps
                )
            }
        
        
        // MARK: 1. Heaviest Weight
        
        if let bestWeightSet,
           bestWeightSet.weight > historicalBestWeight {
            
            records.append(
                PersonalRecord(
                    exerciseName: exercise.name,
                    type: .heaviestWeight,
                    weight: bestWeightSet.weight,
                    reps: bestWeightSet.reps,
                    estimatedOneRepMax: estimatedOneRepMax(
                        weight: bestWeightSet.weight,
                        reps: bestWeightSet.reps
                    ),
                    date: Date(),
                    workoutID: workoutID
                )
            )
        }
        
        
        // MARK: 2. Rep Record
        
        /*
         A Rep Record must NOT come from a lower
         weight than the previous best weight.
         
         Example:
         
         Previous best:
         70 kg × 10
         
         Current workout:
         52 kg × 14
         70 kg × 16
         
         Only 70 kg × 16 can be a Rep Record.
         */
        
        let minimumRepRecordWeight = historicalBestWeight
        
        let eligibleRepSets = exercise.sets.filter {
            $0.weight >= minimumRepRecordWeight
        }
        
        let bestRepSet = eligibleRepSets.max {
            
            if $0.reps != $1.reps {
                return $0.reps < $1.reps
            }
            
            return $0.weight < $1.weight
        }
        
        
        if let bestRepSet {
            
            let previousBestRepsAtWeight =
                historicalSets
                    .filter {
                        abs($0.weight - bestRepSet.weight) < 0.01
                    }
                    .map(\.reps)
                    .max() ?? 0
            
            if bestRepSet.reps > previousBestRepsAtWeight {
                
                records.append(
                    PersonalRecord(
                        exerciseName: exercise.name,
                        type: .repRecord,
                        weight: bestRepSet.weight,
                        reps: bestRepSet.reps,
                        estimatedOneRepMax: estimatedOneRepMax(
                            weight: bestRepSet.weight,
                            reps: bestRepSet.reps
                        ),
                        date: Date(),
                        workoutID: workoutID
                    )
                )
            }
        }
        
        
        // MARK: 3. Estimated 1RM
        
        if let best1RMSet {
            
            let new1RM = estimatedOneRepMax(
                weight: best1RMSet.weight,
                reps: best1RMSet.reps
            )
            
            if new1RM > historicalBest1RM {
                
                records.append(
                    PersonalRecord(
                        exerciseName: exercise.name,
                        type: .estimatedOneRepMax,
                        weight: best1RMSet.weight,
                        reps: best1RMSet.reps,
                        estimatedOneRepMax: new1RM,
                        date: Date(),
                        workoutID: workoutID
                    )
                )
            }
        }
        
        return records
    }
}
