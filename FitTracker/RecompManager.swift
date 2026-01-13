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
    
    // MARK: - MATH ENGINE (Linear Regression)
    /// Calculates the slope and intercept of the user's strength curve
    private func linearRegression(_ points: [(x: Double, y: Double)]) -> (slope: Double, intercept: Double) {
        guard points.count > 1 else { return (0, 0) }
        
        let n = Double(points.count)
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        let sumXY = points.reduce(0) { $0 + ($1.x * $1.y) }
        let sumXX = points.reduce(0) { $0 + ($1.x * $1.x) }
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n
        
        return (slope, intercept)
    }
    
    // Epley Formula for 1 Rep Max
    private func estimate1RM(weight: Double, reps: Int) -> Double {
        if reps == 1 { return weight }
        return weight * (1 + (Double(reps) / 30.0))
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

    // MARK: - FEATURE 1: ADVANCED OVERLOAD (Regression-Based)
    func suggestProgressiveOverload(for exerciseName: String, dataManager: DataManager) -> String {
        // 1. Gather Data Points (Date vs Estimated 1RM)
        let history = dataManager.workouts
            .filter { $0.isCompleted }
            .sorted(by: { $0.date < $1.date }) // Oldest first for regression
        
        var points: [(x: Double, y: Double)] = []
        var lastDate: Date = Date()
        var lastMax: Double = 0
        
        for (index, session) in history.enumerated() {
            if let exercise = session.exercises.first(where: { $0.name == exerciseName }),
               let bestSet = exercise.sets.max(by: { $0.weight < $1.weight }) {
                
                let e1rm = estimate1RM(weight: bestSet.weight, reps: bestSet.reps)
                // x = index (session number), y = 1RM
                points.append((x: Double(index), y: e1rm))
                
                lastDate = session.date
                lastMax = e1rm
            }
        }
        
        guard points.count >= 3 else {
            return "Gathering Data... Log at least 3 sessions to unlock trend analysis."
        }
        
        // 2. Calculate Trend
        let (slope, _) = linearRegression(points)
        
        // 3. AI Analysis
        let daysSinceLast = Date().timeIntervalSince(lastDate) / 86400
        
        if daysSinceLast > 14 {
            return "⚠️ Detraining Risk. Your trend was \(slope > 0 ? "positive" : "flat"), but it's been 2 weeks. Deload 10%."
        }
        
        // Slope Interpretation
        if slope > 2.5 {
            // Gaining > 2.5 lbs per session (Newbie Gains / Peaking)
            let projected = Int(lastMax + slope)
            return "🚀 High Velocity! You're gaining strength fast. Attempt \(projected) lbs next."
        } else if slope > 0.5 {
            // Steady Progress
            return "📈 Steady Climb. Trend is positive (+\(String(format: "%.1f", slope)) lbs/session). Add 2.5-5 lbs."
        } else if slope > -1.0 {
            // Plateau (Flat line)
            return "🚧 Plateau Detected. Strength is stagnant. Recommendation: Change rep range or increase rest times."
        } else {
            // Regression (Getting weaker)
            return "📉 Fatigue Detected. Your strength is trending down. Recommendation: Take a deload week immediately."
        }
    }
    
    // MARK: - FEATURE 2: TRAINING DENSITY (Work Capacity)
    // Measures "Junk Volume". High density = efficient workout.
    func analyzeTrainingDensity(dataManager: DataManager) -> String {
        let recent = dataManager.workouts
            .filter { $0.isCompleted && $0.duration ?? 0 > 0 }
            .sorted(by: { $0.date > $1.date })
            .prefix(5)
        
        guard !recent.isEmpty else { return "--" }
        
        var densities: [Double] = []
        
        for session in recent {
            // Volume (lbs) / Duration (minutes)
            let minutes = (session.duration ?? 1) / 60
            let density = session.totalVolume / minutes
            densities.append(density)
        }
        
        let avgDensity = densities.reduce(0, +) / Double(densities.count)
        let lastDensity = densities.first ?? 0
        
        if lastDensity > (avgDensity * 1.1) {
            return "🔥 High Intensity. You moved \(Int(lastDensity)) lbs/min (10% above average)."
        } else if lastDensity < (avgDensity * 0.9) {
            return "💤 Low Intensity. Rest times may be too long (\(Int(lastDensity)) lbs/min)."
        } else {
            return "✅ Consistent Pace. (\(Int(lastDensity)) lbs/min)."
        }
    }

    // MARK: - EXISTING LOGIC (Kept for compatibility)
    func getFlexibleTarget(recoveryScore: Int) -> String {
        if recoveryScore < 4 {
            return "⚠️ Low Recovery (\(recoveryScore)/10). Recommendation: Active recovery, stretching, or a complete rest day."
        } else if recoveryScore < 7 {
            let dailyGoal = max(3, weeklySetTarget / 4)
            return "⚖️ Feeling okay. Aim for a standard session: ~\(dailyGoal) hard sets per muscle group."
        } else {
            let dailyGoal = max(4, weeklySetTarget / 3)
            return "🔥 You are Fresh! Push for hypertrophy: ~\(dailyGoal) hard sets per muscle group today."
        }
    }
    
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
    
    func analyzeSymmetry(dataManager: DataManager) -> String {
        let oneWeekAgo = Date().addingTimeInterval(-604800)
        let recentWorkouts = dataManager.workouts.filter { $0.date > oneWeekAgo && $0.isCompleted }
        
        var upperSets = 0
        var lowerSets = 0
        
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                switch exercise.muscleGroup {
                case .legs: lowerSets += exercise.sets.count
                default: upperSets += exercise.sets.count
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
    
    func findLaggingMuscle(dataManager: DataManager) -> String {
        let oneWeekAgo = Date().addingTimeInterval(-604800)
        let recentWorkouts = dataManager.workouts.filter { $0.date > oneWeekAgo && $0.isCompleted }
        
        var volumeMap: [MuscleGroup: Int] = [.chest: 0, .back: 0, .legs: 0, .shoulders: 0, .arms: 0, .core: 0]
        
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
