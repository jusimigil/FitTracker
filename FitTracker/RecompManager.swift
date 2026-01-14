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

    // MARK: - DAILY ADVICE
    func getFlexibleTarget(recoveryScore: Int) -> String {
        if recoveryScore < 4 {
            return "⚠️ Low Recovery. Recommendation: Active recovery, stretching, or a complete rest day."
        } else if recoveryScore < 7 {
            let dailyGoal = max(3, weeklySetTarget / 4)
            return "⚖️ Feeling okay. Aim for a standard session: ~\(dailyGoal) hard sets per muscle group."
        } else {
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
        
        let avgSetsPerMuscle = totalSets / 6
        
        if avgSetsPerMuscle >= weeklySetTarget {
            return ("Optimal Volume (\(avgSetsPerMuscle) sets/wk)", .green)
        } else if avgSetsPerMuscle >= (weeklySetTarget - 5) {
            return ("Building Momentum (\(avgSetsPerMuscle)/\(weeklySetTarget) sets/wk)", .orange)
        } else {
            return ("Behind Target (\(avgSetsPerMuscle)/\(weeklySetTarget) sets/wk)", .red)
        }
    }
    
    // MARK: - SMART PROGRESSION (Machine Learning)
    func suggestProgressiveOverload(for exerciseName: String, dataManager: DataManager) -> String {
        let history = dataManager.workouts.filter { $0.isCompleted }.sorted(by: { $0.date > $1.date })
        
        let sessionsWithExercise = history.filter { session in
            session.exercises.contains(where: { $0.name == exerciseName })
        }
        
        guard let lastSession = sessionsWithExercise.first,
              let lastExercise = lastSession.exercises.first(where: { $0.name == exerciseName }),
              let bestSet = lastExercise.sets.max(by: { $0.weight < $1.weight })
        else {
            return "New Exercise! Start light (10-12 reps) to learn the form."
        }
        
        // 1. "Rust" Detector (Consistency Check)
        let daysSinceLast = Date().timeIntervalSince(lastSession.date) / 86400
        if daysSinceLast > 14 {
            let deloadWeight = Int(bestSet.weight * 0.9)
            return "It's been over 2 weeks. 📉 Deload to \(deloadWeight) lbs to prevent injury."
        }
        
        // 2. Plateau Breaker
        if sessionsWithExercise.count >= 3 {
            let recentWeights = sessionsWithExercise.prefix(3).compactMap { s in
                s.exercises.first(where: { $0.name == exerciseName })?.sets.map { $0.weight }.max()
            }
            if recentWeights.count == 3 {
                let w1 = recentWeights[0]; let w2 = recentWeights[1]; let w3 = recentWeights[2]
                // If weight stuck (within 2 lbs) AND RPE is high
                if abs(w1 - w2) < 2 && abs(w2 - w3) < 2 && bestSet.rpe >= 9 {
                    return "🚧 Plateau Detected (Stuck at \(Int(w1)) lbs). Strategy: Drop weight by 10% and do 2 extra reps."
                }
            }
        }
        
        // 3. Standard RPE Algorithm
        let lastWeight = bestSet.weight
        let rpeValue = Double(bestSet.rpe > 0 ? bestSet.rpe : 8)
        let oneRepMax = lastWeight * (1 + (Double(bestSet.reps) / 30.0))
        let formattedMax = String(format: "%.0f", oneRepMax)
        
        if rpeValue <= 6 {
            return "Too easy (RPE \(Int(rpeValue))). 🚀 Jump to \(Int(lastWeight + 10)) lbs. (Est 1RM: \(formattedMax))"
        } else if rpeValue >= 9 {
            return "Grinding (RPE \(Int(rpeValue))). 🛡️ Stay at \(Int(lastWeight)) lbs. (Est 1RM: \(formattedMax))"
        } else {
            return "Optimal (RPE \(Int(rpeValue))). 📈 Add weight: \(Int(lastWeight + 5)) lbs. (Est 1RM: \(formattedMax))"
        }
    }
    
    // MARK: - SYMMETRY (Fixed Case Error)
    func analyzeSymmetry(dataManager: DataManager) -> String {
        let oneWeekAgo = Date().addingTimeInterval(-604800)
        let recentWorkouts = dataManager.workouts.filter { $0.date > oneWeekAgo && $0.isCompleted }
        
        var upperSets = 0
        var lowerSets = 0
        
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                switch exercise.muscleGroup {
                case .legs: // Fixed: Removed .glutes/.calves to prevent crash
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
        
        // Find lowest non-zero, or zero if neglected
        if let weakest = volumeMap.sorted(by: { $0.value < $1.value }).first {
            if weakest.value == 0 {
                return "⚠️ Neglected: \(weakest.key.rawValue). 0 sets this week."
            } else if weakest.value < (weeklySetTarget / 2) {
                return "⚠️ Lagging: \(weakest.key.rawValue). Only \(weakest.value) sets/week."
            }
        }
        
        return "✅ Balanced Physique. No weak links detected."
    }
}
