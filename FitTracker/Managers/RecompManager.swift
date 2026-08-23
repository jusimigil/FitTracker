import Foundation
import SwiftUI
import Combine

// Global DatePoint for Charts
struct DatePoint: Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var value: Double
}

class RecompManager: ObservableObject {
    static let shared = RecompManager()
    
    @Published var currentFocus: RecompFocus {
        didSet { UserDefaults.standard.set(currentFocus.rawValue, forKey: "recompFocus") }
    }
    
    private init() {
        let savedFocus = UserDefaults.standard.string(forKey: "recompFocus") ?? ""
        self.currentFocus = RecompFocus(rawValue: savedFocus) ?? .standard
    }
    
    // Helper for Units
    var isMetric: Bool { DataManager.shared.weightUnit == .kg }
    var unitLabel: String { isMetric ? "kg" : "lbs" }
    
    // MARK: - WEEKLY TARGETS
    var weeklySetTarget: Int {
        switch currentFocus {
        case .fatLoss: return 12
        case .standard: return 15
        case .muscle: return 18
        }
    }
    
    func weeklyTarget(for muscle: MuscleGroup) -> Int {
        switch muscle {
        case .chest:
            return 12
        case .back:
            return 14
        case .legs:
            return 14
        case .shoulders:
            return 10
        case .arms:
            return 10
        case .core:
            return 8
        }
    }
    
    var stepTarget: Int {
        return currentFocus == .fatLoss ? 10_000 : 8_000
    }

    // MARK: - DAILY ADVICE
    // MARK: - DAILY ADVICE

    func getFlexibleTarget(
        recoveryScore: Int,
        sleepHours: Double? = nil
    ) -> String {
        
        // Low self-reported recovery always takes priority.
        if recoveryScore < 4 {
            return """
            ⚠️ Low Recovery. Recommendation: Active recovery, stretching, \
            or a complete rest day.
            """
        }
        
        // MARK: - Moderate Recovery
        
        if recoveryScore < 7 {
            
            let dailyGoal = max(
                3,
                weeklySetTarget / 4
            )
            
            // Short sleep adds a recovery caution.
            if let sleepHours,
               sleepHours > 0,
               sleepHours < 6 {
                
                return """
                ⚠️ Your recovery feels moderate and you slept only \
                \(String(format: "%.1f", sleepHours)) hours. \
                Keep training controlled today and aim for about \
                \(dailyGoal) hard sets per muscle group.
                """
            }
            
            return """
            ⚖️ Feeling okay. Aim for a standard session: \
            ~\(dailyGoal) hard sets per muscle group.
            """
        }
        
        // MARK: - High Recovery
        
        let dailyGoal = max(
            4,
            weeklySetTarget / 3
        )
        
        // High recovery + short sleep should not automatically mean
        // a high-volume day.
        if let sleepHours,
           sleepHours > 0,
           sleepHours < 6 {
            
            let reducedGoal = max(
                3,
                weeklySetTarget / 4
            )
            
            return """
            😴 You feel fresh, but you slept only \
            \(String(format: "%.1f", sleepHours)) hours. \
            Keep training moderate today with about \
            \(reducedGoal) hard sets per muscle group.
            """
        }
        
        return """
        🔥 You are Fresh! Push for hypertrophy: \
        ~\(dailyGoal) hard sets per muscle group today.
        """
    }
    
    // MARK: - STATUS (Volume Analysis)
    func analyzeStatus(dataManager: DataManager) -> (status: String, color: Color) {
        let oneWeekAgo = Date().addingTimeInterval(-604800)
        let recentWorkouts = dataManager.completedWorkouts.filter {
            $0.date > oneWeekAgo
        }
        
        var totalSets = 0
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                totalSets += exercise.sets.count
            }
        }
        
        let avgSetsPerMuscle = totalSets / MuscleGroup.allCases.count
        
        if avgSetsPerMuscle >= weeklySetTarget {
            return ("Optimal Volume (\(avgSetsPerMuscle) sets/wk)", .green)
        } else if avgSetsPerMuscle >= (weeklySetTarget - 5) {
            return ("Building Momentum (\(avgSetsPerMuscle)/\(weeklySetTarget) sets/wk)", .orange)
        } else {
            return ("Behind Target (\(avgSetsPerMuscle)/\(weeklySetTarget) sets/wk)", .red)
        }
    }
    
    func weeklySetsByMuscle(
        dataManager: DataManager
    ) -> [MuscleGroup: Int] {
        var counts: [MuscleGroup: Int] = [:]

        for muscle in MuscleGroup.allCases {
            counts[muscle] = 0
        }

        let calendar = Calendar.current
        let now = Date()

        guard let weekStart = calendar.date(
            from: calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: now
            )
        ) else {
            return counts
        }

        for workout in dataManager.completedWorkouts {
            guard workout.date >= weekStart else {
                continue
            }

            for exercise in workout.exercises {
                counts[exercise.resolvedMuscleGroup, default: 0] += exercise.sets.count
            }
        }

        return counts
    }
    
    // MARK: - SMART PROGRESSION (Unit Aware)
    func suggestProgressiveOverload(
        for exerciseName: String,
        dataManager: DataManager
    ) -> String {
        
        let history = dataManager.completedWorkouts
            .sorted { $0.date > $1.date }
        
        let sessionsWithExercise = history.filter { session in
            session.exercises.contains {
                $0.name == exerciseName
            }
        }
        
        guard
            let lastSession = sessionsWithExercise.first,
            let lastExercise = lastSession.exercises.first(
                where: { $0.name == exerciseName }
            ),
            !lastExercise.sets.isEmpty
        else {
            return "New exercise! Start light and aim for 8–12 reps while focusing on good form."
        }
        
        let sets = lastExercise.sets.filter {
            $0.weight > 0 && $0.reps > 0
        }
        
        guard !sets.isEmpty else {
            return "Complete a few working sets and FitTracker will suggest your next progression."
        }
        
        
        // MARK: Best Performance
        
        let bestSet = sets.max {
            ($0.weight * (1.0 + Double($0.reps) / 30.0)) <
            ($1.weight * (1.0 + Double($1.reps) / 30.0))
        }!
        
        let best1RM =
            bestSet.weight * (
                1.0 + Double(bestSet.reps) / 30.0
            )
        
        
        // MARK: Average RPE
        
        let rpeSets = sets.filter {
            $0.rpe > 0
        }
        
        let averageRPE: Double
        
        if rpeSets.isEmpty {
            averageRPE = 8
        } else {
            averageRPE = Double(
                rpeSets.reduce(0) { $0 + $1.rpe }
            ) / Double(rpeSets.count)
        }
        
        
        // MARK: Rep Drop-Off
        
        let firstReps = sets.first?.reps ?? bestSet.reps
        let lastReps = sets.last?.reps ?? bestSet.reps
        
        let repDropOff: Double
        
        if firstReps > 0 {
            repDropOff =
                Double(firstReps - lastReps) /
                Double(firstReps)
        } else {
            repDropOff = 0
        }
        
        
        // MARK: Weight Formatting
        
        let currentWeight = dataManager.formatWeight(
            bestSet.weight,
            decimals: 1
        )
        
        let formattedMax = dataManager.formatWeight(
            best1RM,
            decimals: 1
        )
        
        
        // MARK: Weight Increments
        
        let smallJump = isMetric ? 1.25 : 2.5
        let mediumJump = isMetric ? 2.5 : 5.0
        
        
        // MARK: - Recovery Adjustment

        let todayRecovery = dataManager.recoveryHistory
            .first(where: {
                Calendar.current.isDateInToday($0.date)
            })?.score

        let recentRecoveryEntries = dataManager.recoveryHistory
            .filter {
                guard let cutoff = Calendar.current.date(
                    byAdding: .day,
                    value: -6,
                    to: Date()
                ) else {
                    return false
                }
                
                return $0.date >= cutoff
            }

        let recoveryAverage: Double? = {
            guard !recentRecoveryEntries.isEmpty else {
                return nil
            }
            
            return recentRecoveryEntries.reduce(0) {
                $0 + $1.score
            } / Double(recentRecoveryEntries.count)
        }()
        
        // Low recovery overrides progression.
        if let todayRecovery, todayRecovery < 4 {
            return """
            🛌 Recovery is low.
            Today's score: \(Int(todayRecovery))/10.
            Skip progressive overload today and focus on quality reps.
            Hold \(currentWeight) and avoid pushing to failure.
            Est 1RM: \(formattedMax)
            """
        }
        
        if let todayRecovery, todayRecovery < 7 {
            
            let recoveryText: String
            
            if let recoveryAverage {
                recoveryText = """
                Today's recovery: \(Int(todayRecovery))/10.
                7-day average: \(String(format: "%.1f", recoveryAverage))/10.
                """
            } else {
                recoveryText = """
                Today's recovery: \(Int(todayRecovery))/10.
                """
            }
            
            return """
            ⚖️ Conservative session.
            \(recoveryText)
            Keep \(currentWeight) today and prioritize consistent reps.
            Resume progression when recovery improves.
            Est 1RM: \(formattedMax)
            """
        }
        
        // Very difficult workout OR significant rep drop-off
        if averageRPE >= 9 || repDropOff >= 0.25 {
            
            return """
            🛡️ Hold the weight.
            Average RPE: \(String(format: "%.1f", averageRPE)).
            Your reps dropped significantly across the sets.
            Repeat \(currentWeight) next session and aim for more consistent reps.
            Est 1RM: \(formattedMax)
            """
        }
        
        
        // Hard but controlled
        if averageRPE >= 8 {
            
            return """
            💪 Solid work.
            Average RPE: \(String(format: "%.1f", averageRPE)).
            Keep \(currentWeight) and aim for 1–2 more total reps before increasing.
            Est 1RM: \(formattedMax)
            """
        }
        
        
        // Moderate effort
        if averageRPE >= 7 {
            
            let suggestedWeight =
                bestSet.weight + smallJump
            
            return """
            📈 Good progression opportunity.
            Average RPE: \(String(format: "%.1f", averageRPE)).
            Try \(dataManager.formatWeight(suggestedWeight, decimals: 1)) next session and aim for 8–10 reps.
            Last best set: \(currentWeight) × \(bestSet.reps).
            Est 1RM: \(formattedMax)
            """
        }
        
        
        // Easy workout
        let suggestedWeight =
            bestSet.weight + mediumJump
        
        return """
        🚀 This looks comfortable.
        Average RPE: \(String(format: "%.1f", averageRPE)).
        Try \(dataManager.formatWeight(suggestedWeight, decimals: 1)) next session for 8–10 reps.
        Last best set: \(currentWeight) × \(bestSet.reps).
        Est 1RM: \(formattedMax)
        """
    }
    
    
    // MARK: - PREDICTION ENGINE
    func getStrengthPrediction(for exerciseName: String, dataManager: DataManager) -> (history: [DatePoint], prediction: [DatePoint]) {
        let historySessions = dataManager.completedWorkouts
            .sorted(by: { $0.date < $1.date })

        var historyPoints: [DatePoint] = []
        var regressionPoints: [(x: Double, y: Double)] = []

        for (index, session) in historySessions.enumerated() {
            if let exercise = session.exercises.first(where: { $0.name == exerciseName }),
               let bestSet = exercise.sets.max(by: {
                   PRManager.shared.estimatedOneRepMax(
                       weight: $0.weight,
                       reps: $0.reps
                   ) <
                   PRManager.shared.estimatedOneRepMax(
                       weight: $1.weight,
                       reps: $1.reps
                   )
               }) {

                let e1rm = PRManager.shared.estimatedOneRepMax(
                    weight: bestSet.weight,
                    reps: bestSet.reps
                )
                historyPoints.append(DatePoint(date: session.date, value: e1rm))
                regressionPoints.append((x: Double(index), y: e1rm))
            }
        }
        
        guard regressionPoints.count >= 3 else { return (historyPoints, []) }
        
        // Linear Regression
        let n = Double(regressionPoints.count)
        let sumX = regressionPoints.reduce(0) { $0 + $1.x }
        let sumY = regressionPoints.reduce(0) { $0 + $1.y }
        let sumXY = regressionPoints.reduce(0) { $0 + ($1.x * $1.y) }
        let sumXX = regressionPoints.reduce(0) { $0 + ($1.x * $1.x) }
        
        let denominator = n * sumXX - sumX * sumX
        if denominator == 0 { return (historyPoints, []) }
        
        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n
        
        let lastIndex = Double(regressionPoints.count - 1)
        let predictedMax = (slope * (lastIndex + 8.0)) + intercept
        
        let lastDate = historyPoints.last?.date ?? Date()
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: lastDate)!
        
        let predictionPoints = [
            DatePoint(date: lastDate, value: historyPoints.last?.value ?? 0),
            DatePoint(date: futureDate, value: predictedMax)
        ]
        
        return (historyPoints, predictionPoints)
    }

    // MARK: - SYMMETRY
    func analyzeSymmetry(dataManager: DataManager) -> String {
        let oneWeekAgo = Date().addingTimeInterval(-604800)
        let recentWorkouts = dataManager.completedWorkouts.filter {
            $0.date > oneWeekAgo
        }
        
        var upperSets = 0
        var lowerSets = 0
        
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                switch exercise.resolvedMuscleGroup {
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
        let volumeMap = weeklySetsByMuscle(
            dataManager: dataManager
        )

        let target = weeklySetTarget

        guard target > 0 else {
            return "No training target available."
        }

        let weakest = volumeMap.min { lhs, rhs in
            let lhsProgress = Double(lhs.value) / Double(target)
            let rhsProgress = Double(rhs.value) / Double(target)

            if lhsProgress != rhsProgress {
                return lhsProgress < rhsProgress
            }

            // Tie-breaker: prioritize lower-body training.
            if lhs.key == .legs && rhs.key != .legs {
                return true
            }

            if rhs.key == .legs && lhs.key != .legs {
                return false
            }

            return lhs.key.rawValue < rhs.key.rawValue
        }

        guard let weakest else {
            return "No recent training data."
        }

        let completedSets = weakest.value
        let progress = Double(completedSets) / Double(target)
        let percentage = Int(progress * 100)

        if completedSets == 0 {
            return """
            ⚠️ Neglected: \(weakest.key.rawValue).

            No sets completed this week.
            """
        }

        if progress < 0.5 {
            return """
            ⚠️ Weak Link: \(weakest.key.rawValue).

            \(completedSets)/\(target) sets this week (\(percentage)% of target).
            """
        }

        if progress < 0.75 {
            return """
            ⚖️ Behind: \(weakest.key.rawValue).

            \(completedSets)/\(target) sets this week (\(percentage)% of target).
            """
        }

        if progress < 1.0 {
            return """
            📈 Building: \(weakest.key.rawValue).

            \(completedSets)/\(target) sets this week (\(percentage)% of target).
            """
        }

        return """
        ✅ Training distribution is balanced.

        All major muscle groups are near their current targets.
        """
    }
    
    // MARK: - DELOAD DETECTION

    func deloadRecommendation(
        dataManager: DataManager
    ) -> String? {
        
        let calendar = Calendar.current
        let now = Date()
        
        guard
            let currentWeekStart = calendar.date(
                byAdding: .day,
                value: -7,
                to: now
            ),
            let previousWeekStart = calendar.date(
                byAdding: .day,
                value: -14,
                to: now
            )
        else {
            return nil
        }
        
        // Only completed strength workouts count.
        let currentWeekWorkouts = dataManager.completedWorkouts.filter {
            $0.type == .strength &&
            $0.date >= currentWeekStart
        }

        let previousWeekWorkouts = dataManager.completedWorkouts.filter {
            $0.type == .strength &&
            $0.date >= previousWeekStart &&
            $0.date < currentWeekStart
        }
        
        // We need enough data before making a deload recommendation.
        guard currentWeekWorkouts.count >= 3 else {
            return nil
        }
        
        // MARK: 1. Training Frequency
        
        let highFrequency =
            currentWeekWorkouts.count >= 4
        
        // MARK: 2. Average RPE
        
        let allCurrentWeekSets = currentWeekWorkouts.flatMap {
            workout in
            workout.exercises.flatMap {
                exercise in
                exercise.sets
            }
        }
        
        let averageRPE: Double
        
        if allCurrentWeekSets.isEmpty {
            averageRPE = 0
        } else {
            averageRPE =
                allCurrentWeekSets
                    .map { Double($0.rpe) }
                    .reduce(0, +)
                / Double(allCurrentWeekSets.count)
        }
        
        let highEffort =
            averageRPE >= 8.5
        
        // MARK: 3. Volume Increase
        
        let currentVolume =
            currentWeekWorkouts.reduce(0.0) {
                $0 + $1.totalVolume
            }
        
        let previousVolume =
            previousWeekWorkouts.reduce(0.0) {
                $0 + $1.totalVolume
            }
        
        let volumeIncrease: Double
        
        if previousVolume > 0 {
            volumeIncrease =
                currentVolume / previousVolume
        } else {
            volumeIncrease = 1.0
        }
        
        let highWorkload =
            previousVolume > 0 &&
            volumeIncrease >= 1.15
        
        // MARK: Decision
        
        let fatigueSignals = [
            highFrequency,
            highEffort,
            highWorkload
        ]
        
        let signalCount =
            fatigueSignals.filter { $0 }.count
        
        guard signalCount >= 2 else {
            return nil
        }
        
        let formattedRPE =
            String(format: "%.1f", averageRPE)
        
        let volumeChange =
            Int((volumeIncrease - 1.0) * 100)
        
        if highFrequency && highEffort && highWorkload {
            return """
            ⚠️ Deload Recommended
            
            You've accumulated a high training load this week:
            \(currentWeekWorkouts.count) strength sessions, \
            average RPE \(formattedRPE), and \
            approximately \(volumeChange)% more volume than last week.
            
            Consider reducing training volume for your next few sessions \
            while maintaining lighter, controlled sets.
            """
        }
        
        if highEffort && highWorkload {
            return """
            ⚠️ Deload Recommended
            
            Your training intensity and volume have both been elevated.
            Average RPE is \(formattedRPE) with approximately \
            \(volumeChange)% more volume than last week.
            
            Consider reducing your training volume temporarily.
            """
        }
        
        if highFrequency && highEffort {
            return """
            ⚠️ Deload Recommended
            
            You've completed \(currentWeekWorkouts.count) strength sessions \
            this week with an average RPE of \(formattedRPE).
            
            Consider reducing training volume temporarily to allow recovery.
            """
        }
        
        return """
        ⚠️ Deload Recommended
        
        Your recent training load has increased significantly.
        Consider reducing training volume temporarily.
        """
    }
}
