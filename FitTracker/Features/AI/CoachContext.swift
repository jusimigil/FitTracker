import Foundation

// MARK: - Coaching Context

struct CoachContext {
    let recoveryScore: Double
    let recoveryTrend: String
    
    let workoutsThisWeek: Int
    let averageRPE: Double?
    
    let weakestMuscle: MuscleGroup?
    let weakestMuscleSets: Int?
    let weakestMuscleTarget: Int?
    
    let recentPRCount: Int
    let sleepHours: Double?
    
    let trainingLoad: TrainingLoadLevel
}

// MARK: - Training Load

enum TrainingLoadLevel {
    case low
    case moderate
    case high
    
    var description: String {
        switch self {
        case .low:
            return "Light"
        case .moderate:
            return "Moderate"
        case .high:
            return "High"
        }
    }
}

// MARK: - Coach Context Builder

struct CoachContextBuilder {
    
    func build(
        dataManager: DataManager,
        recoveryScore: Double,
        sleepHours: Double?
    ) -> CoachContext {
        
        let calendar = Calendar.current
        let now = Date()
        
        // MARK: Workouts This Week
        
        let weekStart =
            calendar.date(
                from: calendar.dateComponents(
                    [.yearForWeekOfYear, .weekOfYear],
                    from: now
                )
            ) ?? now
        
        let weeklyWorkouts = dataManager.completedWorkouts.filter {
            $0.date >= weekStart
        }
        // MARK: Average RPE
        
        let weeklySets = weeklyWorkouts.flatMap {
            workout in
            workout.exercises.flatMap {
                exercise in
                exercise.sets
            }
        }
        
        let averageRPE: Double?
        
        if weeklySets.isEmpty {
            averageRPE = nil
        } else {
            averageRPE =
                weeklySets
                    .map { Double($0.rpe) }
                    .reduce(0, +)
                / Double(weeklySets.count)
        }
        
        // MARK: Muscle Balance
        
        // MARK: Muscle Balance

        let muscleVolumes =
            RecompManager.shared.weeklySetsByMuscle(
                dataManager: dataManager
            )

        let weakestMuscle =
            MuscleGroup.allCases.min { lhs, rhs in
                let lhsSets = muscleVolumes[lhs, default: 0]
                let rhsSets = muscleVolumes[rhs, default: 0]

                let lhsTarget =
                    RecompManager.shared.weeklyTarget(for: lhs)

                let rhsTarget =
                    RecompManager.shared.weeklyTarget(for: rhs)

                let lhsProgress =
                    lhsTarget > 0
                    ? Double(lhsSets) / Double(lhsTarget)
                    : 0

                let rhsProgress =
                    rhsTarget > 0
                    ? Double(rhsSets) / Double(rhsTarget)
                    : 0

                if lhsProgress != rhsProgress {
                    return lhsProgress < rhsProgress
                }

                // Keep the same tie-breaker used elsewhere.
                if lhs == .legs && rhs != .legs {
                    return true
                }

                if rhs == .legs && lhs != .legs {
                    return false
                }

                return lhs.rawValue < rhs.rawValue
            }

        let weakestMuscleSets =
            weakestMuscle.map {
                muscleVolumes[$0, default: 0]
            }

        let weakestMuscleTarget =
            weakestMuscle.map {
                RecompManager.shared.weeklyTarget(for: $0)
            }
        
        // MARK: Recent PRs
        
        let sevenDaysAgo =
            calendar.date(
                byAdding: .day,
                value: -7,
                to: now
            ) ?? now
        
        let recentPRCount =
            dataManager.personalRecords.filter {
                $0.date >= sevenDaysAgo
            }.count
        
        // MARK: Training Load
        
        let trainingLoad =
            determineTrainingLoad(
                workoutCount: weeklyWorkouts.count,
                averageRPE: averageRPE
            )
        
        // MARK: Recovery Trend
        
        let recoveryTrend =
            determineRecoveryTrend(
                dataManager.recoveryHistory
            )
        
        return CoachContext(
            recoveryScore: recoveryScore,
            recoveryTrend: recoveryTrend,
            workoutsThisWeek: weeklyWorkouts.count,
            averageRPE: averageRPE,
            weakestMuscle: weakestMuscle,
            weakestMuscleSets: weakestMuscleSets,
            weakestMuscleTarget: weakestMuscleTarget,
            recentPRCount: recentPRCount,
            sleepHours: sleepHours,
            trainingLoad: trainingLoad
        )
    }
    
    // MARK: Training Load
    
    private func determineTrainingLoad(
        workoutCount: Int,
        averageRPE: Double?
    ) -> TrainingLoadLevel {
        
        let rpe = averageRPE ?? 0
        
        if workoutCount >= 5 || rpe >= 8.5 {
            return .high
        }
        
        if workoutCount >= 3 || rpe >= 7 {
            return .moderate
        }
        
        return .low
    }
    
    // MARK: Recovery Trend
    
    private func determineRecoveryTrend(
        _ entries: [RecoveryEntry]
    ) -> String {
        
        let sorted =
            entries
                .sorted { $0.date < $1.date }
                .suffix(7)
        
        guard sorted.count >= 4 else {
            return "Not enough data"
        }
        
        let midpoint =
            sorted.count / 2
        
        let firstHalf =
            sorted.prefix(midpoint)
        
        let secondHalf =
            sorted.suffix(sorted.count - midpoint)
        
        let firstAverage =
            firstHalf
                .map(\.score)
                .reduce(0, +)
            / Double(firstHalf.count)
        
        let secondAverage =
            secondHalf
                .map(\.score)
                .reduce(0, +)
            / Double(secondHalf.count)
        
        let difference =
            secondAverage - firstAverage
        
        if difference >= 0.75 {
            return "Improving"
        }
        
        if difference <= -0.75 {
            return "Declining"
        }
        
        return "Stable"
    }
}
