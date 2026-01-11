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
    
    // MARK: - TARGETS
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

    // MARK: - FLEXIBILITY
    func getFlexibleTarget(recoveryScore: Int) -> String {
        if recoveryScore < 4 {
            let maintenanceSets = weeklySetTarget / 3
            return "⚠️ Low Recovery. Switch to 'Maintenance Mode': \(maintenanceSets) sets/muscle."
        } else {
            return "✅ Recovery Good. Aim for \(weeklySetTarget) hard sets/muscle."
        }
    }
    
    // MARK: - STATUS
    func analyzeStatus(dataManager: DataManager) -> (status: String, color: Color) {
        let oneWeekAgo = Date().addingTimeInterval(-604800)
        let recentWorkouts = dataManager.workouts.filter { $0.date > oneWeekAgo }
        
        var totalSets = 0
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                totalSets += exercise.sets.count
            }
        }
        
        let avgSetsPerMuscle = totalSets / 3
        
        if avgSetsPerMuscle >= weeklySetTarget {
            return ("Optimal Zone (\(avgSetsPerMuscle) sets)", .green)
        } else if avgSetsPerMuscle >= (weeklySetTarget - 3) {
            return ("Building Momentum (\(avgSetsPerMuscle)/\(weeklySetTarget))", .orange)
        } else {
            return ("Behind Target (\(avgSetsPerMuscle)/\(weeklySetTarget))", .red)
        }
    }
    
    // MARK: - EXISTING FEATURE: OVERLOAD
    func suggestProgressiveOverload(for exerciseName: String, dataManager: DataManager) -> String {
        let history = dataManager.workouts
            .sorted(by: { $0.date > $1.date })
            .flatMap { $0.exercises }
            .filter { $0.name.lowercased().contains(exerciseName.lowercased()) }
        
        guard let lastSession = history.first else { return "No data yet." }
        let maxWeight = lastSession.sets.map { $0.weight }.max() ?? 0
        
        if maxWeight == 0 { return "Track weight to get suggestions." }
        let targetWeight = round((maxWeight * 1.025) * 2) / 2
        
        return "Last: \(Int(maxWeight)) lbs → Target: \(targetWeight) lbs"
    }
    
    // MARK: - EXISTING FEATURE: SYMMETRY
    func analyzeSymmetry(dataManager: DataManager) -> String {
        let oneWeekAgo = Date().addingTimeInterval(-604800)
        let recentWorkouts = dataManager.workouts.filter { $0.date > oneWeekAgo }
        
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
            return "⚠️ Symmetry Alert: Only \(Int(lowerPercentage * 100))% Lower Body. Don't skip legs!"
        } else {
            return "✅ Symmetry Good: Balanced Upper/Lower split."
        }
    }
    
    // MARK: - NEW FEATURE: WEAK LINK DETECTOR
    // Scans specifically for the lowest volume muscle group to find what's lagging
    func findLaggingMuscle(dataManager: DataManager) -> String {
        let oneWeekAgo = Date().addingTimeInterval(-604800)
        let recentWorkouts = dataManager.workouts.filter { $0.date > oneWeekAgo }
        
        // Initialize all groups to 0 so we can find the neglected ones
        var volumeMap: [MuscleGroup: Int] = [
            .chest: 0, .back: 0, .legs: 0, .shoulders: 0, .arms: 0, .core: 0
        ]
        
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                volumeMap[exercise.muscleGroup, default: 0] += exercise.sets.count
            }
        }
        
        // Sort to find the lowest non-zero, or absolute zero
        let sortedMuscles = volumeMap.sorted { $0.value < $1.value }
        
        if let weakest = sortedMuscles.first {
            if weakest.value == 0 {
                return "⚠️ Neglected: \(weakest.key.rawValue). 0 sets this week."
            } else if weakest.value < (weeklySetTarget / 2) {
                return "⚠️ Lagging: \(weakest.key.rawValue). Only \(weakest.value) sets."
            }
        }
        
        return "✅ Balanced Physique. No weak links detected."
    }
}
