import SwiftUI
import UserNotifications
import Combine
import Charts

struct ExerciseDetailView: View {
    @Binding var exercise: Exercise
    var readOnly: Bool = false
    
    let workoutID: UUID
    
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var recompManager = RecompManager.shared
    @ObservedObject var healthManager = HealthManager.shared

    @AppStorage("dailyRecoveryScore")
    private var dailyRecoveryScore: Double = 8.0
    
    
    @State private var reps = 10
    @State private var weight = 0.0
    @State private var rpe = 8.0
    @State private var newPRs: [PersonalRecord] = []
    @State private var previousSets: [WorkoutSet] = []
    @State private var editingSetID: UUID?
    @State private var showEditSetSheet = false
    @State private var nextSetRecommendation: String = ""
    @State private var recommendedWeight: Double?
    @State private var recommendedReps: Int?
    @State private var recommendedRPE: Double?
    @State private var nextWorkoutGoal: String = ""
    @State private var nextWorkoutWeight: Double?
    @State private var nextWorkoutReps: Int?
    
    var currentSessionSets: [WorkoutSet] {
        exercise.sets
    }
    
    // Timer State
    @State private var timeRemaining = 0
    @State private var totalRestTime: Double = 90.0
    @State private var timerActive = false
    @State private var internalTimer: Timer?

    // Helpers for Units
    var isMetric: Bool { dataManager.weightUnit == .kg }
    var unitLabel: String { isMetric ? "kg" : "lbs" }
    var maxWeight: Double { isMetric ? 300 : 600 }
    
    // MARK: - Recovery Programming

    enum RecoveryProgrammingLevel {
        case normal
        case conservative
        case recovery
    }

    private var recoveryProgrammingLevel: RecoveryProgrammingLevel {
        if dailyRecoveryScore < 4 {
            return .recovery
        }
        
        if dailyRecoveryScore < 7 {
            return .conservative
        }
        
        if healthManager.lastNightSleepHours > 0 &&
            healthManager.lastNightSleepHours < 6 {
            return .conservative
        }
        
        return .normal
    }
    
    var personalBestSets: [WorkoutSet] {
        dataManager.completedWorkouts
            .flatMap { workout in
                workout.exercises
                    .filter {
                        $0.name.caseInsensitiveCompare(exercise.name) == .orderedSame
                    }
                    .flatMap {
                        $0.sets
                    }
            }
    }
    var heaviestSet: WorkoutSet? {
        personalBestSets.max {
            $0.weight < $1.weight
        }
    }

    var bestRepSet: WorkoutSet? {
        personalBestSets.max {
            if $0.reps == $1.reps {
                return $0.weight < $1.weight
            }
            return $0.reps < $1.reps
        }
    }

    var bestEstimatedOneRepMaxSet: WorkoutSet? {
        personalBestSets.max {
            PRManager.shared.estimatedOneRepMax(
                weight: $0.weight,
                reps: $0.reps
            )
            <
            PRManager.shared.estimatedOneRepMax(
                weight: $1.weight,
                reps: $1.reps
            )
        }
    }
    
    // MARK: - Exercise Progression

    struct ProgressionPoint: Identifiable {
        let id = UUID()
        let date: Date
        let estimated1RM: Double
    }

    var progressionHistory: [ProgressionPoint] {
        let history = dataManager.completedWorkouts
            .compactMap { workout -> ProgressionPoint? in
                
                guard let matchingExercise = workout.exercises.first(
                    where: {
                        $0.name.caseInsensitiveCompare(
                            exercise.name
                        ) == .orderedSame
                    }
                ) else {
                    return nil
                }
                
                guard let bestSet = matchingExercise.sets.max(
                    by: {
                        PRManager.shared.estimatedOneRepMax(
                            weight: $0.weight,
                            reps: $0.reps
                        )
                        <
                        PRManager.shared.estimatedOneRepMax(
                            weight: $1.weight,
                            reps: $1.reps
                        )
                    }
                ) else {
                    return nil
                }
                
                let estimated1RM =
                    PRManager.shared.estimatedOneRepMax(
                        weight: bestSet.weight,
                        reps: bestSet.reps
                    )
                
                return ProgressionPoint(
                    date: workout.date,
                    estimated1RM: estimated1RM
                )
            }
            .sorted { $0.date < $1.date }
        
        // Keep the view compact.
        return Array(history.suffix(8))
    }

    var progressionTrend: String {
        guard progressionHistory.count >= 2,
              let first = progressionHistory.first,
              let last = progressionHistory.last
        else {
            return "Not enough data"
        }
        
        let difference =
            last.estimated1RM - first.estimated1RM
        
        if difference > 0 {
            return "Improving"
        }
        
        if difference < 0 {
            return "Declining"
        }
        
        return "Stable"
    }

    var progressionTrendIcon: String {
        switch progressionTrend {
        case "Improving":
            return "arrow.up.right"
        case "Declining":
            return "arrow.down.right"
        default:
            return "arrow.right"
        }
    }

    var progressionTrendColor: Color {
        switch progressionTrend {
        case "Improving":
            return .green
        case "Declining":
            return .red
        default:
            return .secondary
        }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 25) {
                    
                    // MARK: - 0. MUSCLE SELECTOR
                    if let muscle = ExerciseCatalog.muscle(
                        for: exercise.name
                    ) {
                        HStack {
                            Text("Primary Muscle")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text(muscle.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                        .padding()
                        .background(
                            Color(.secondarySystemBackground)
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    
                    // MARK: - PERSONAL BEST
                    if !personalBestSets.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                                
                                Text("Personal Best")
                                    .font(.headline)
                                
                                Spacer()
                            }
                            
                            if let best = heaviestSet {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Heaviest Weight")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        
                                        Text(
                                            "\(Int(dataManager.displayedWeight(fromKilograms: best.weight))) \(unitLabel)"
                                        )
                                        .font(.title3)
                                        .bold()
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(best.reps) reps")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Divider()
                            
                            if let best = bestRepSet {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Best Rep Set")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        
                                        Text("\(best.reps) reps")
                                            .font(.title3)
                                            .bold()
                                    }
                                    
                                    Spacer()
                                    
                                    Text(
                                        "\(Int(dataManager.displayedWeight(fromKilograms: best.weight))) \(unitLabel)"
                                    )
                                    .font(.subheadline)
                                    .bold()
                                }
                            }
                            
                            Divider()
                            
                            if let best = bestEstimatedOneRepMaxSet {
                                let estimated1RM = PRManager.shared.estimatedOneRepMax(
                                    weight: best.weight,
                                    reps: best.reps
                                )
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Estimated 1RM")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        
                                        Text(
                                            "\(Int(dataManager.displayedWeight(fromKilograms: estimated1RM))) \(unitLabel)"
                                        )
                                        .font(.title3)
                                        .bold()
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(best.reps) reps")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    
                    // MARK: - PREVIOUS WORKOUT
                    if !previousSets.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.blue)
                                
                                Text("Previous Workout")
                                    .font(.headline)
                                
                                Spacer()
                            }
                            
                            ForEach(previousSets) { set in
                                HStack {
                                    Text("\(set.reps) reps")
                                        .fontWeight(.medium)
                                    
                                    Text("×")
                                        .foregroundStyle(.secondary)
                                    
                                    Text(
                                        "\(Int(dataManager.displayedWeight(fromKilograms: set.weight))) \(unitLabel)"
                                    )
                                    .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Text("RPE \(set.rpe)")
                                        .font(.caption)
                                        .padding(6)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    // MARK: - PROGRESSION

                    if progressionHistory.count >= 2 {
                        VStack(alignment: .leading, spacing: 12) {
                            
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundStyle(progressionTrendColor)
                                
                                Text("Progression")
                                    .font(.headline)
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Image(systemName: progressionTrendIcon)
                                    Text(progressionTrend)
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(progressionTrendColor)
                            }
                            
                            Chart(progressionHistory) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("1RM", dataManager.displayedWeight(
                                        fromKilograms: point.estimated1RM
                                    ))
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(.blue)
                                
                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("1RM", dataManager.displayedWeight(
                                        fromKilograms: point.estimated1RM
                                    ))
                                )
                                .foregroundStyle(.blue)
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 4)) {
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .frame(height: 150)
                            
                            if let first = progressionHistory.first,
                               let last = progressionHistory.last {
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Previous")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        
                                        Text(
                                            dataManager.formatWeight(
                                                first.estimated1RM,
                                                decimals: 0
                                            )
                                        )
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Current")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        
                                        Text(
                                            dataManager.formatWeight(
                                                last.estimated1RM,
                                                decimals: 0
                                            )
                                        )
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    // MARK: - Input Controls
                    if !readOnly {
                        VStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Weight").fontWeight(.medium)
                                    Spacer()
                                    Text(formatWeightValue(weight) + " " + unitLabel).bold().foregroundStyle(.blue)
                                }
                                Slider(value: $weight, in: 0...maxWeight, step: isMetric ? 0.5 : 1)
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("RPE")
                                    
                                    Spacer()
                                    
                                    Text("\(Int(rpe)) / 10")
                                        .bold()
                                        .foregroundStyle(
                                            rpeColor(rpe: rpe)
                                        )
                                }
                                
                                Slider(
                                    value: $rpe,
                                    in: 1...10,
                                    step: 1
                                )
                                
                                Text(rpeDescription(rpe: rpe))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .animation(
                                        .easeInOut(duration: 0.15),
                                        value: rpe
                                    )
                            }
                            Divider()
                            HStack { Text("Reps").fontWeight(.medium); Spacer(); Stepper("\(reps)", value: $reps, in: 1...100).fixedSize() }
                        }
                        .padding().background(Color(.secondarySystemBackground)).cornerRadius(15)
                        
                        // MARK: - Action Buttons
                        HStack(spacing: 15) {
                            Button(action: {
                                let newID = logSet()
                                withAnimation { proxy.scrollTo(newID, anchor: .bottom) }
                            }) {
                                Text("Log Set")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(weight == 0 ? Color.gray : Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .disabled(weight == 0)
                            
                            // Rest Timer
                            if timerActive {
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.orange.opacity(0.1))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange, lineWidth: 2))
                                    GeometryReader { geo in
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.orange)
                                            .padding(4)
                                            .frame(width: max(0, (geo.size.width - 8) * (Double(timeRemaining) / totalRestTime)))
                                            .animation(.linear(duration: 1.0), value: timeRemaining)
                                    }
                                    Text("\(timeRemaining)s")
                                        .font(.headline).monospacedDigit().foregroundColor(.primary)
                                        .frame(maxWidth: .infinity)
                                        .animation(nil, value: timeRemaining)
                                }
                                .frame(height: 50).frame(maxWidth: .infinity)
                                .onTapGesture { cancelTimer() }
                            } else {
                                Button(action: { startRest(seconds: 90) }) {
                                    Text("Rest 90s")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Color(.systemGray5))
                                        .foregroundColor(.primary)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        
                        if !nextSetRecommendation.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .foregroundStyle(.green)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Next Set")
                                            .font(.caption)
                                            .bold()
                                            .foregroundStyle(.green)
                                        
                                        Text(nextSetRecommendation)
                                            .font(.subheadline)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    
                                    Spacer()
                                }
                                
                                if recommendedWeight != nil &&
                                   recommendedReps != nil {
                                    
                                    Button {
                                        applyNextSetRecommendation()
                                    } label: {
                                        Label(
                                            "Apply Recommendation",
                                            systemImage: "checkmark.circle.fill"
                                        )
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        if !nextWorkoutGoal.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Next Workout Goal")
                                            .font(.caption)
                                            .bold()
                                            .foregroundStyle(.blue)
                                        
                                        Text(nextWorkoutGoal)
                                            .font(.subheadline)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    
                    // MARK: - History List (Editable)
                    VStack(alignment: .leading, spacing: 12) {
                        if !exercise.sets.isEmpty {
                            HStack {
                                Text("Sets Completed").font(.headline)
                                Spacer()
                                Text("Tap to Edit").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.leading, 5)
                        }
                        
                        ForEach(exercise.sets) { set in
                            HStack {
                                Text("\(set.reps) reps").bold()
                                Text("×").foregroundStyle(.secondary)
                                Text("\(Int(dataManager.displayedWeight(fromKilograms: set.weight))) \(unitLabel)")
                                    .bold()
                                Spacer()
                                if set.rpe > 0 {
                                    Text("RPE \(set.rpe)").font(.caption).padding(6).background(Color(.systemGray6)).cornerRadius(6)
                                }
                            }
                            .padding().background(Color(.systemBackground)).cornerRadius(10).shadow(radius: 1)
                            .id(set.id)
                            .onTapGesture {
                                editingSetID = set.id
                                
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                
                                showEditSetSheet = true
                            }
                        }
                        .onDelete { indices in
                            exercise.sets.remove(atOffsets: indices)
                            dataManager.save()
                        }
                    }
                    Spacer().frame(height: 50).id("bottom")
                }
                .padding()
            }
        }
        .navigationTitle(exercise.name)
        
        .onAppear {
            
            let loadedPreviousSets = loadPreviousSets()
            
            previousSets = loadedPreviousSets
            
            if !exercise.sets.isEmpty && !readOnly {
                if let lastSet = exercise.sets.last {
                    nextSetRecommendation = generateNextSetRecommendation(
                        set: lastSet
                    )
                }
            }
            
            if !readOnly {
                generateNextWorkoutGoal(
                    from: loadedPreviousSets
                )
            }
            
            if weight == 0 {
                if let lastSet = loadedPreviousSets.last {
                    weight = dataManager.displayedWeight(
                        fromKilograms: lastSet.weight
                    )
                    
                    reps = lastSet.reps
                    rpe = Double(lastSet.rpe)
                } else {
                    weight = dataManager.weightUnit == .kg
                        ? 20.0
                        : 45.0
                }
            }
        }
        .onDisappear {
            internalTimer?.invalidate()
            dataManager.save()
        }
        .sheet(isPresented: $showEditSetSheet) {
            if let editingSetID = editingSetID,
               let setIndex = exercise.sets.firstIndex(
                    where: { $0.id == editingSetID }
               ) {
                EditWorkoutSetView(
                    set: $exercise.sets[setIndex],
                    weightUnit: unitLabel,
                    displayedWeight: {
                        dataManager.displayedWeight(
                            fromKilograms: exercise.sets[setIndex].weight
                        )
                    },
                    kilogramsFromDisplayedWeight: {
                        dataManager.kilograms(
                            fromDisplayedWeight: $0
                        )
                    },
                    onSave: {
                        recalculateEditedExercisePRs()
                    }
                )
            }
        }
        .alert(
            "🏆 New Personal Record!",
            isPresented: Binding(
                get: { !newPRs.isEmpty },
                set: { if !$0 { newPRs.removeAll() } }
            )
        ) {
            Button("Awesome!") {
                newPRs.removeAll()
            }
        } message: {
            if !newPRs.isEmpty {
                let achievements = newPRs
                    .map { "• \($0.type.rawValue)" }
                    .joined(separator: "\n")
                
                let best = newPRs[0]
                
                Text(
                    "\(achievements)\n\n" +
                    "\(Int(dataManager.displayedWeight(fromKilograms: best.weight))) \(unitLabel) × \(best.reps)\n" +
                    "Estimated 1RM: \(Int(dataManager.displayedWeight(fromKilograms: best.estimatedOneRepMax))) \(unitLabel)"
                )
            }
        }
    }
    
    func loadPreviousSets() -> [WorkoutSet] {
        
        let currentWorkoutID = findCurrentWorkoutID()
        
        let previousExercises = dataManager.completedWorkouts
            .filter {
                $0.id != currentWorkoutID
            }
            .sorted {
                $0.date > $1.date
            }
        
        for workout in previousExercises {
            if let previousExercise = workout.exercises.first(
                where: {
                    $0.name.caseInsensitiveCompare(exercise.name) == .orderedSame
                }
            ) {
                return previousExercise.sets
            }
        }
        
        return []
    }
    
    func findCurrentWorkoutID() -> UUID? {
        dataManager.workouts.first {
            $0.exercises.contains(where: {
                $0.id == exercise.id
            })
        }?.id
    }
    
    func generateNextSetRecommendation(
        set: WorkoutSet
    ) -> String {
        
        let currentWeight = dataManager.displayedWeight(
            fromKilograms: set.weight
        )
        
        let currentRPE = Double(set.rpe)
        let currentReps = set.reps
        let recoveryLevel = recoveryProgrammingLevel
        
        let sessionSets = currentSessionSets
        
        let averageRPE: Double
        
        if sessionSets.isEmpty {
            averageRPE = currentRPE
        } else {
            averageRPE = sessionSets
                .map { Double($0.rpe) }
                .reduce(0, +)
                / Double(sessionSets.count)
        }
        
        // MARK: - Recovery Adjustment

        if recoveryLevel == .recovery {
            let recoveryWeight = max(
                0,
                currentWeight - (isMetric ? 2.5 : 5.0)
            )
            
            recommendedWeight = recoveryWeight
            recommendedReps = currentReps
            recommendedRPE = 7
            
            return """
            Recovery is low today.
            Keep the next set controlled at \(formatWeightValue(recoveryWeight)) \(unitLabel) and avoid pushing to failure.
            """
        }

        if recoveryLevel == .conservative {
            
            // Recovery limits progression but does not stop training.
            recommendedWeight = currentWeight
            recommendedReps = currentReps
            recommendedRPE = 7
            
            return """
            Recovery suggests a conservative session today.
            Keep \(formatWeightValue(currentWeight)) \(unitLabel) and focus on consistent reps.
            """
        }
        
        let increase = isMetric ? 2.5 : 5.0
        let decrease = isMetric ? 2.5 : 5.0
        
        // MARK: - Very Easy
        
        if averageRPE <= 6.5 {
            let nextWeight = currentWeight + increase
            
            recommendedWeight = nextWeight
            recommendedReps = currentReps
            recommendedRPE = 8
            
            return """
            Your sets are moving easily at an average RPE of \(String(format: "%.1f", averageRPE)).
            Increase to \(formatWeightValue(nextWeight)) \(unitLabel) for the next set.
            """
        }
        
        // MARK: - Easy / Productive
        
        if averageRPE <= 7.5 {
            let nextWeight = currentWeight + increase
            
            recommendedWeight = nextWeight
            recommendedReps = currentReps
            recommendedRPE = 8
            
            return """
            Strong set at an average RPE of \(String(format: "%.1f", averageRPE)).
            Try \(formatWeightValue(nextWeight)) \(unitLabel) for the next set.
            """
        }
        
        // MARK: - Productive
        
        if averageRPE <= 8.5 {
            recommendedWeight = currentWeight
            recommendedReps = min(currentReps + 1, 15)
            recommendedRPE = 8
            
            return """
            You're in a productive range at an average RPE of \(String(format: "%.1f", averageRPE)).
            Keep \(formatWeightValue(currentWeight)) \(unitLabel) and aim for \(currentReps + 1) reps.
            """
        }
        
        // MARK: - Hard
        
        if averageRPE < 9.5 {
            recommendedWeight = currentWeight
            recommendedReps = currentReps
            recommendedRPE = 8
            
            return """
            This exercise is getting challenging at an average RPE of \(String(format: "%.1f", averageRPE)).
            Keep \(formatWeightValue(currentWeight)) \(unitLabel) and match your performance.
            """
        }
        
        // MARK: - Very Hard / Maximum Effort
        
        let nextWeight = max(
            0,
            currentWeight - decrease
        )
        
        recommendedWeight = nextWeight
        recommendedReps = currentReps
        recommendedRPE = 8
        
        return """
        High fatigue detected at an average RPE of \(String(format: "%.1f", averageRPE)).
        Reduce to \(formatWeightValue(nextWeight)) \(unitLabel) for the next set.
        """
    }
    
    func generateNextWorkoutGoal(from sets: [WorkoutSet]) {
        
        guard !sets.isEmpty else {
            nextWorkoutGoal = ""
            nextWorkoutWeight = nil
            nextWorkoutReps = nil
            return
        }
        
        let recoveryLevel = recoveryProgrammingLevel
        
        let averageRPE = sets
            .map { Double($0.rpe) }
            .reduce(0, +) / Double(sets.count)
        
        // Use the best-performing set as the basis for progression.
        let bestSet = sets.max {
            let lhs1RM = PRManager.shared.estimatedOneRepMax(
                weight: $0.weight,
                reps: $0.reps
            )
            
            let rhs1RM = PRManager.shared.estimatedOneRepMax(
                weight: $1.weight,
                reps: $1.reps
            )
            
            return lhs1RM < rhs1RM
        }
        
        guard let bestSet else {
            return
        }
        
        let currentWeight = dataManager.displayedWeight(
            fromKilograms: bestSet.weight
        )
        
        let currentReps = bestSet.reps
        
        // MARK: - Recovery Adjustment

        if recoveryLevel == .recovery {
            let recoveryWeight = max(
                0,
                currentWeight - (isMetric ? 2.5 : 5.0)
            )
            
            nextWorkoutWeight = recoveryWeight
            nextWorkoutReps = currentReps
            
            nextWorkoutGoal = """
            Recovery is low today.
            Do not increase load next workout. Rebuild with about \(formatWeightValue(recoveryWeight)) \(unitLabel) and focus on consistent, high-quality reps.
            """
            
            return
        }

        if recoveryLevel == .conservative {
            nextWorkoutWeight = currentWeight
            nextWorkoutReps = currentReps
            
            nextWorkoutGoal = """
            Recovery suggests a conservative progression.
            Keep \(formatWeightValue(currentWeight)) \(unitLabel) next workout and aim to match your current performance before increasing weight.
            """
            
            return
        }
        
        let minimumUsefulReps = 6
        
        // MARK: - Very Easy
        
        if averageRPE <= 6.5 {
            
            // If the user stopped very early, build reps first.
            if currentReps < minimumUsefulReps {
                
                nextWorkoutWeight = currentWeight
                nextWorkoutReps = min(
                    currentReps + 2,
                    12
                )
                
                nextWorkoutGoal = """
                Your average RPE was \(String(format: "%.1f", averageRPE)), \
                but you only reached \(currentReps) reps.
                
                Keep \(formatWeightValue(currentWeight)) \(unitLabel) next workout \
                and build toward \(minimumUsefulReps)–12 reps before increasing weight.
                """
                
                return
            }
            
            let increase = isMetric ? 2.5 : 5.0
            let nextWeight = currentWeight + increase
            
            nextWorkoutWeight = nextWeight
            nextWorkoutReps = currentReps
            
            nextWorkoutGoal = """
            Progression ready. Your average RPE was \
            \(String(format: "%.1f", averageRPE)).
            
            Next workout, try \(formatWeightValue(nextWeight)) \(unitLabel) \
            for \(currentReps) reps.
            """
            
            return
        }
        
        // MARK: - Good / Productive
        
        if averageRPE <= 7.5 {
            
            let increase = isMetric ? 2.5 : 5.0
            let nextWeight = currentWeight + increase
            
            nextWorkoutWeight = nextWeight
            nextWorkoutReps = currentReps
            
            nextWorkoutGoal = """
            Good performance at an average RPE of \
            \(String(format: "%.1f", averageRPE)).
            
            Next workout, try \(formatWeightValue(nextWeight)) \(unitLabel) \
            for \(currentReps) reps.
            """
            
            return
        }
        
        // MARK: - Productive
        
        if averageRPE <= 8.5 {
            
            nextWorkoutWeight = currentWeight
            nextWorkoutReps = min(
                currentReps + 1,
                15
            )
            
            nextWorkoutGoal = """
            Solid session at an average RPE of \
            \(String(format: "%.1f", averageRPE)).
            
            Keep \(formatWeightValue(currentWeight)) \(unitLabel) next workout \
            and aim for \(currentReps + 1) reps.
            """
            
            return
        }
        
        // MARK: - Hard
        
        if averageRPE < 9.5 {
            
            nextWorkoutWeight = currentWeight
            nextWorkoutReps = currentReps
            
            nextWorkoutGoal = """
            Challenging session at an average RPE of \
            \(String(format: "%.1f", averageRPE)).
            
            Keep \(formatWeightValue(currentWeight)) \(unitLabel) next workout \
            and focus on matching your performance.
            """
            
            return
        }
        
        // MARK: - Maximum Effort
        
        let decrease = isMetric ? 2.5 : 5.0
        let nextWeight = max(
            0,
            currentWeight - decrease
        )
        
        nextWorkoutWeight = nextWeight
        nextWorkoutReps = currentReps
        
        nextWorkoutGoal = """
        Maximum effort detected.
        
        Reduce to \(formatWeightValue(nextWeight)) \(unitLabel) \
        next workout and rebuild from there.
        """
    }
    
    func applyNextSetRecommendation() {
        
        guard let recommendedWeight,
              let recommendedReps,
              let recommendedRPE
        else {
            return
        }
        
        weight = recommendedWeight
        reps = recommendedReps
        rpe = recommendedRPE
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func formatWeightValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    // MARK: - Logic
    func startRest(seconds: Int) {
        totalRestTime = Double(seconds)
        timeRemaining = seconds
        timerActive = true
        internalTimer?.invalidate()

        // Start the Live Activity rest countdown.
        let restEndTime = Date().addingTimeInterval(
            Double(seconds)
        )

        LiveActivityManager.shared.startRest(
            until: restEndTime,
            currentExercise: exercise.name,
            currentSet: exercise.sets.count,
            totalSets: exercise.sets.count
        )

        internalTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { _ in
            if timeRemaining > 0 {
                withAnimation(.linear(duration: 1.0)) {
                    timeRemaining -= 1
                }
            } else {
                cancelTimer()

                let generator =
                    UINotificationFeedbackGenerator()

                generator.notificationOccurred(.success)
            }
        }
    }
    
    func cancelTimer() {
        timerActive = false
        internalTimer?.invalidate()

        LiveActivityManager.shared.endRest(
            currentExercise: exercise.name,
            currentSet: exercise.sets.count,
            totalSets: exercise.sets.count
        )
    }
    func recalculateEditedExercisePRs() {
        let records = PRManager.shared.recalculatePRs(
            exercise: exercise,
            workouts: dataManager.workouts,
            workoutID: workoutID
        )
        
        dataManager.replacePersonalRecords(
            for: workoutID,
            exerciseName: exercise.name,
            with: records
        )
        
        dataManager.save()
        
        // Trigger the existing PR alert.
        newPRs = records
    }
    
    func logSet() -> UUID {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Convert the user's displayed weight to kilograms.
        let weightInKilograms =
            dataManager.kilograms(fromDisplayedWeight: weight)
        
        let newSet = WorkoutSet(
            reps: reps,
            weight: weightInKilograms,
            rpe: Int(rpe)
        )
        
        // Check PR BEFORE adding the new set.
        newPRs = PRManager.shared.checkForPR(
            exercise: exercise,
            newSet: newSet,
            workouts: dataManager.workouts,
            workoutID: workoutID
        )
        
        if !newPRs.isEmpty {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        
        dataManager.addPersonalRecords(newPRs)
        
        // Now add the set.
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            exercise.sets.append(newSet)
        }

        // Save the updated workout.
        dataManager.save()
        


        nextSetRecommendation = generateNextSetRecommendation(
            set: newSet
        )
        
        let workoutSession = dataManager.workouts.first {
            $0.id == workoutID
        }

        if let workoutSession {
            let workoutName: String

            if let title = workoutSession.workoutTitle,
               !title.isEmpty {
                workoutName = title
            } else if !workoutSession.notes.isEmpty,
                      workoutSession.notes.count < 30 {
                workoutName = workoutSession.notes
            } else {
                workoutName =
                    workoutSession.type.rawValue.capitalized
            }

            let totalWorkoutSets =
                workoutSession.exercises
                    .flatMap(\.sets)
                    .count

            if totalWorkoutSets == 1 {
                LiveActivityManager.shared.startWorkout(
                    workoutName: workoutName,
                    startedAt: workoutSession.date,
                    currentExercise: exercise.name,
                    currentSet: exercise.sets.count,
                    totalSets: totalWorkoutSets
                )
            } else {
                LiveActivityManager.shared.updateWorkout(
                    currentExercise: exercise.name,
                    currentSet: exercise.sets.count,
                    totalSets: totalWorkoutSets
                )
            }
        }

        return newSet.id

    }
    
    func rpeColor(rpe: Double) -> Color {
        switch rpe {
        case 1...4: return .green; case 5...7: return .orange; default: return .red
        }
    }
    
    func rpeDescription(rpe: Double) -> String {
        switch Int(rpe) {
        case 1...4:
            return "Very easy — you could do 6+ more reps"
            
        case 5:
            return "Easy — you could do about 5 more reps"
            
        case 6:
            return "Moderate — you could do about 4 more reps"
            
        case 7:
            return "Challenging — you could do about 3 more reps"
            
        case 8:
            return "Hard — you could do about 2 more reps"
            
        case 9:
            return "Very hard — you could do about 1 more rep"
            
        case 10:
            return "Maximum effort — no reps left"
            
        default:
            return ""
        }
    }
    
    struct EditWorkoutSetView: View {
        @Binding var set: WorkoutSet
        
        let weightUnit: String
        let displayedWeight: () -> Double
        let kilogramsFromDisplayedWeight: (Double) -> Double
        let onSave: () -> Void
        
        @Environment(\.dismiss) var dismiss
        
        @State private var weight: Double = 0
        @State private var reps: Int = 1
        @State private var rpe: Int = 8
        
        var body: some View {
            NavigationStack {
                Form {
                    
                    Section("Weight") {
                        HStack {
                            Text("Weight")
                            
                            Spacer()
                            
                            TextField(
                                "Weight",
                                value: $weight,
                                format: .number
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            
                            Text(weightUnit)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Section("Reps") {
                        Stepper(
                            "\(reps) reps",
                            value: $reps,
                            in: 1...100
                        )
                    }
                    
                    Section("RPE") {
                        Stepper(
                            "RPE \(rpe)",
                            value: $rpe,
                            in: 1...10
                        )
                    }
                }
                .navigationTitle("Edit Set")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveChanges()
                        }
                    }
                }
                .onAppear {
                    weight = displayedWeight()
                    reps = set.reps
                    rpe = set.rpe
                }
            }
        }
        
        func saveChanges() {
            set.weight = kilogramsFromDisplayedWeight(weight)
            set.reps = reps
            set.rpe = rpe
            
            onSave()
            
            dismiss()
        }    }
}
