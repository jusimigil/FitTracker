import Foundation
import SwiftUI
import Combine

class RecompManager: ObservableObject {
    static let shared = RecompManager()
    
    @Published var currentFocus: RecompFocus {
        didSet { UserDefaults.standard.set(currentFocus.rawValue, forKey: "recompFocus") }
    }
    
    private init() {
        let savedFocus = UserDefaults.standard.string(forKey: "recompFocus") ?? ""
        self.currentFocus = RecompFocus(rawValue: savedFocus) ?? .standard
    }
    
    // MARK: - WEEKLY TARGETS
    var weeklySetTarget: Int {
        switch currentFocus {
        case .fatLoss: return 12
        case .standard: return 15
        case .muscle: return 18
        }
    }
    
    var stepTarget: Int {
        return currentFocus == .fatLoss ? 10_000 : 8_000
    }

    // MARK: - FLEXIBILITY / DAILY ADVICE (FIXED)
    func getFlexibleTarget(recoveryScore: Int) -> String {
        // We calculate a "Daily Slice" of the weekly volume.
        // Assuming you hit a muscle 2-3 times a week, a heavy day is roughly 1/3 of the weekly target.
        
        if recoveryScore < 4 {
            // LOW RECOVERY: Do NOT train hard.
            return "⚠️ Low Recovery (\(recoveryScore)/10). Recommendation: Active recovery, stretching, or a complete rest day."
            
        } else if recoveryScore < 7 {
            // MODERATE RECOVERY: Maintenance volume.
            // Target roughly 25% of weekly volume (e.g., 15 / 4 = ~3-4 sets)
            let dailyGoal = max(3, weeklySetTarget / 4)
            return "⚖️ Feeling okay. Aim for a standard session: ~\(dailyGoal) hard sets per muscle group."
            
        } else {
            // HIGH RECOVERY: Overload volume.
            // Target roughly 33% of weekly volume (e.g., 15 / 3 = 5 sets)
            let dailyGoal = max(4, weeklySetTarget / 3)
            return "🔥 You are Fresh! Push for hypertrophy: ~\(dailyGoal) hard sets per muscle group today."
        }
    }
    
    // MARK: - STATUS (Volume Analysis)
    func analyzeStatus(dataManager: DataManager) -> (status: String, color: Color) {
        let oneWeekAgo = Date().addingTimeInterval(-604800)
        let recentWorkouts = dataManager.workouts.filter { $0.date > oneWeekAgo && $0.isCompleted }
        
        var totalSets = 0
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                totalSets += exercise.sets.count
            }
        }
        
        // Approximate average sets per major muscle group
        let avgSetsPerMuscle = totalSets / 6
        
        if avgSetsPerMuscle >= weeklySetTarget {
            return ("Optimal Volume (\(avgSetsPerMuscle) sets/wk)", .green)
        } else if avgSetsPerMuscle >= (weeklySetTarget - 5) {
            return ("Building Momentum (\(avgSetsPerMuscle)/\(weeklySetTarget) sets/wk)", .orange)
        } else {
            return ("Behind Target (\(avgSetsPerMuscle)/\(weeklySetTarget) sets/wk)", .red)
        }
    }
    
    // MARK: - MACHINE LEARNING: RPE AUTOREGULATION
    func suggestProgressiveOverload(for exerciseName: String, dataManager: DataManager) -> String {
        let history = dataManager.workouts
            .filter { $0.isCompleted }
            .sorted(by: { $0.date > $1.date })
        
        guard let lastSession = history.first(where: { session in
            session.exercises.contains(where: { $0.name == exerciseName })
        }) else {
            return "New Exercise! Start with a weight you can lift for 10-12 reps."
        }
        
        guard let lastExercise = lastSession.exercises.first(where: { $0.name == exerciseName }),
              let bestSet = lastExercise.sets.max(by: { $0.weight < $1.weight })
        else {
            return "Track weight to get suggestions."
        }
        
        // ALGORITHM
        let lastWeight = bestSet.weight
        let lastReps = bestSet.reps
        let rpeValue = Double(bestSet.rpe > 0 ? bestSet.rpe : 8)
        
        let oneRepMax = lastWeight * (1 + (Double(lastReps) / 30.0))
        let formattedMax = String(format: "%.0f", oneRepMax)
        
        if rpeValue <= 6 {
            let newWeight = Int(lastWeight + 10)
            return "Too easy (RPE \(Int(rpeValue))). \n🚀 Jump to \(newWeight) lbs. (Est 1RM: \(formattedMax))"
        } else if rpeValue >= 9 {
            return "Grinding (RPE \(Int(rpeValue))). \n🛡️ Stay at \(Int(lastWeight)) lbs. (Est 1RM: \(formattedMax))"
        } else {
            let newWeight = Int(lastWeight + 5)
            return "Optimal (RPE \(Int(rpeValue))). \n📈 Add weight: \(newWeight) lbs. (Est 1RM: \(formattedMax))"
        }
    }
    
    // MARK: - SYMMETRY
    func analyzeSymmetry(dataManager: DataManager) -> String {
        let oneWeekAgo = Date().addingTimeInterval(-604800)
        let recentWorkouts = dataManager.workouts.filter { $0.date > oneWeekAgo && $0.isCompleted }
        
        var upperSets = 0
        var lowerSets = 0
        
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                switch exercise.muscleGroup {
                case .legs:
                    lowerSets += exercise.sets.count
                default:
                    upperSets += exercise.sets.count
                }
            }
        }
        
        let total = upperSets + lowerSets
        if total == 0 { return "No recent data." }
        
        let lowerPercentage = Double(lowerSets) / Double(total)
        if lowerPercentage < 0.25 {
            return "⚠️ Symmetry Alert: Only \(Int(lowerPercentage * 100))% Lower Body."
        } else {
            return "✅ Symmetry Good: Balanced Upper/Lower split."
        }
    }
    
    // MARK: - WEAK LINK DETECTOR
    func findLaggingMuscle(dataManager: DataManager) -> String {
        let oneWeekAgo = Date().addingTimeInterval(-604800)
        let recentWorkouts = dataManager.workouts.filter { $0.date > oneWeekAgo && $0.isCompleted }
        
        var volumeMap: [MuscleGroup: Int] = [
            .chest: 0, .back: 0, .legs: 0, .shoulders: 0, .arms: 0, .core: 0
        ]
        
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                volumeMap[exercise.muscleGroup, default: 0] += exercise.sets.count
            }
        }
        
        let sortedMuscles = volumeMap.sorted { $0.value < $1.value }
        
        if let weakest = sortedMuscles.first {
            if weakest.value == 0 {
                return "⚠️ Neglected: \(weakest.key.rawValue). 0 sets this week."
            } else if weakest.value < (weeklySetTarget / 2) {
                return "⚠️ Lagging: \(weakest.key.rawValue). Only \(weakest.value) sets/week."
            }
        }
        
        return "✅ Balanced Physique. No weak links detected."
    }
}
