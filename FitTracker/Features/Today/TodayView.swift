import SwiftUI

struct TodayView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var recompManager = RecompManager.shared
    @ObservedObject var healthManager = HealthManager.shared
    
    @State private var path = NavigationPath()
    @State private var showRoutineSelection = false
    @State private var showDailyCheckIn = false
    
    @AppStorage("dailyRecoveryScore") var dailyRecoveryScore: Double = 8.0
    @AppStorage("lastCheckInDate") var lastCheckInDate: String = ""
    
    @State private var cachedStatus: (status: String, color: Color) = ("Loading...", .gray)
    @State private var cachedWeakLink: String = "Analyzing..."
    @State private var cachedOverload: String = "--"
    @State private var cachedSymmetry: String = "--"
    @State private var cachedFocus: String = "Analyzing..."
    @State private var deloadMessage: String?
    @State private var coachRecommendation =
        CoachRecommendation(
            headline: "Analyzing your training...",
            message: "Your training data is being evaluated.",
            focus: "Analyzing"
        )
    
    var todaysDate: String { Date().formatted(.dateTime.weekday(.wide).month().day()) }
    
    var recoveryColor: Color {
        if dailyRecoveryScore < 4 {
            return .red
        } else if dailyRecoveryScore < 7 {
            return .orange
        } else {
            return .green
        }
    }

    var recoveryDescription: String {
        if dailyRecoveryScore < 4 {
            return "Recovery is low"
        } else if dailyRecoveryScore < 7 {
            return "Moderate recovery"
        } else {
            return "You're ready"
        }
    }
    
    var coachView: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                
                Text("COACH")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(coachRecommendation.focus)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.purple)
            }
            
            Text(coachRecommendation.headline)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(coachRecommendation.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .padding()
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            Color(.systemBackground)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
        .shadow(
            color: .black.opacity(0.06),
            radius: 5,
            x: 0,
            y: 2
        )
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    coachView
                    trainerBriefingView
                    deloadView
                    startWorkoutButton
                    statusGridView
                    smartInsightsView
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .navigationTitle("Today")
            .onAppear {
                calculateStats()
                checkDailyLogin()
                healthManager.fetchTodaySteps() // Force update steps
            }
            .onChange(of: dataManager.workouts) { _, _ in
                calculateStats()
            }
            .onChange(of: dailyRecoveryScore) { _, _ in
                calculateStats()
            }
            .onChange(of: healthManager.lastNightSleepHours) { _, _ in
                calculateStats()
            }
            .sheet(isPresented: $showDailyCheckIn) {
                RecoveryCheckInView()
                    .environmentObject(dataManager)
            }
            .sheet(isPresented: $showRoutineSelection) {
                RoutineSelectionView(
                    recommendedMuscle: recommendedFocusMuscle()
                ) { newID in
                    path.append(newID)
                }
            }
            .navigationDestination(for: UUID.self) { workoutID in
                SessionDetailView(workoutID: workoutID)
            }
        }
    }
    
    // MARK: - Subviews
    var headerView: some View {
        HStack {
            Text(todaysDate.uppercased())
                .font(.subheadline).fontWeight(.bold).foregroundStyle(.secondary)
            Spacer()
        }.padding(.horizontal).padding(.top, 10)
    }
    
    var stepStatusText: String {
        let steps = healthManager.currentSteps
        
        if steps >= 10_000 {
            return "Daily goal reached"
        } else if steps >= 7_500 {
            return "Good activity"
        } else if steps >= 5_000 {
            return "Keep moving"
        } else {
            return "Room to move"
        }
    }
    
    var trainerBriefingView: some View {
        VStack(alignment: .leading, spacing: 18) {
            
            // MARK: Header
            
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("RECOVERY")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    
                    Text(recoveryDescription)
                        .font(.headline)
                }
                
                Spacer()
                
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(dailyRecoveryScore))")
                        .font(
                            .system(
                                size: 38,
                                weight: .heavy,
                                design: .rounded
                            )
                        )
                    
                    Text("/10")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // MARK: Recovery Progress
            
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(
                    value: dailyRecoveryScore,
                    total: 10
                )
                .tint(recoveryColor)
                .scaleEffect(
                    x: 1,
                    y: 1.5,
                    anchor: .center
                )
                
                HStack {
                    Text("Sore / Tired")
                    Spacer()
                    Text("Fresh / Strong")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // MARK: Trainer Recommendation
            
            HStack(
                alignment: .top,
                spacing: 12
            ) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.purple)
                
                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {
                    Text("Trainer's Plan")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.purple)
                    
                    Text(
                        recompManager.getFlexibleTarget(
                            recoveryScore: Int(dailyRecoveryScore),
                            sleepHours: healthManager.lastNightSleepHours > 0
                                ? healthManager.lastNightSleepHours
                                : nil
                        )
                    )
                    .font(.subheadline)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }
            }
            
            // MARK: Weak Link
            
            if cachedWeakLink.contains("⚠️") {
                HStack(spacing: 8) {
                    Image(
                        systemName:
                            "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                    
                    Text(cachedWeakLink)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.orange.opacity(0.08)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 10
                    )
                )
            }
        }
        .padding()
        .background(
            Color(.systemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
        .shadow(
            color: .black.opacity(0.06),
            radius: 6,
            x: 0,
            y: 3
        )
    }
    
    @ViewBuilder
    var deloadView: some View {
        if let deloadMessage {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "battery.25percent")
                    .foregroundStyle(.orange)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Recovery Check")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    
                    Text(deloadMessage)
                        .font(.subheadline)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
                
                Spacer()
            }
            .padding()
            .background(
                Color.orange.opacity(0.08)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 14)
            )
        }
    }

    
    var smartInsightsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            // MARK: Header
            
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                
                Text("SMART INSIGHTS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            // MARK: Progressive Overload
            
            HStack(
                alignment: .top,
                spacing: 12
            ) {
                Image(
                    systemName: "arrow.up.right.circle.fill"
                )
                .foregroundStyle(.green)
                .font(.title3)
                .frame(width: 28)
                
                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    Text("Progressive Overload")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(cachedOverload)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
            }
            
            Divider()
            
            // MARK: Muscle Balance
            
            HStack(
                alignment: .top,
                spacing: 12
            ) {
                Image(
                    systemName: "scalemass.fill"
                )
                .foregroundStyle(.blue)
                .font(.title3)
                .frame(width: 28)
                
                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    Text("Muscle Balance")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(cachedSymmetry)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
            }
            
            Divider()
            
            // MARK: Weak Link
            
            HStack(
                alignment: .top,
                spacing: 12
            ) {
                Image(
                    systemName:
                        "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
                .font(.title3)
                .frame(width: 28)
                
                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    Text("Weak Link Detector")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(cachedWeakLink)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
            }
        }
        .padding()
        .background(
            Color(.systemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
        .shadow(
            color: .black.opacity(0.06),
            radius: 6,
            x: 0,
            y: 3
        )
    }
    
    var statusGridView: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            // MARK: Header
            
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.purple)
                
                Text("TRAINING STATUS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                
                // MARK: Weekly Volume
                
                VStack(alignment: .leading, spacing: 8) {
                    
                    HStack {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(cachedStatus.color)
                        
                        Text("Volume")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    
                    Text(
                        cachedStatus.status
                            .components(separatedBy: " (")
                            .first ?? "Analyzing"
                    )
                    .font(.headline)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(cachedStatus.color)
                    
                    Text(
                        "Goal: \(recompManager.weeklySetTarget) sets/muscle"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(
                    Color.purple.opacity(0.07)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 12
                    )
                )
                
                // MARK: Steps
                
                VStack(alignment: .leading, spacing: 8) {
                    
                    HStack {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.green)
                        
                        Text("Activity")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    
                    Text(
                        healthManager.currentSteps.formatted()
                    )
                    .font(.headline)
                    .monospacedDigit()
                    
                    ProgressView(
                        value: Double(healthManager.currentSteps),
                        total: Double(recompManager.stepTarget)
                    )
                    .tint(.green)
                    
                    Text(
                        "Target: \(recompManager.stepTarget)"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(
                    Color.green.opacity(0.07)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 12
                    )
                )
            }
        }
        .padding()
        .background(
            Color(.systemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
        .shadow(
            color: .black.opacity(0.06),
            radius: 6,
            x: 0,
            y: 3
        )
    }
    
    var startWorkoutButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            
            showRoutineSelection = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Start Today's Workout")
                        .font(.headline)

                    if let muscle = recommendedFocusMuscle() {
                        Text("Prioritize \(muscle.rawValue)")
                            .font(.caption)
                            .opacity(0.85)
                    } else {
                        Text("Begin your recommended session")
                            .font(.caption)
                            .opacity(0.85)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 16)
            )
            .shadow(
                color: .blue.opacity(0.2),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
    }
    func checkDailyLogin() {
        let today = Date().formatted(date: .numeric, time: .omitted)
        if true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showDailyCheckIn = true }
        }
    }
    
    func calculateStats() {
        cachedStatus = recompManager.analyzeStatus(
            dataManager: dataManager
        )
        
        cachedWeakLink = recompManager.findLaggingMuscle(
            dataManager: dataManager
        )
        
        cachedSymmetry = recompManager.analyzeSymmetry(
            dataManager: dataManager
        )
        
        deloadMessage = recompManager.deloadRecommendation(
            dataManager: dataManager
        )
        
        if let latestExercise = mostRecentExercise() {
            cachedOverload = recompManager.suggestProgressiveOverload(
                for: latestExercise,
                dataManager: dataManager
            )
        } else {
            cachedOverload = "Complete a workout to receive a progression recommendation."
        }
        
        
        let coachContext =
            CoachContextBuilder().build(
                dataManager: dataManager,
                recoveryScore: dailyRecoveryScore,
                sleepHours: healthManager.lastNightSleepHours > 0
                        ? healthManager.lastNightSleepHours
                        : nil
            )

        coachRecommendation =
            CoachManager.shared.recommendation(
                from: coachContext
            )
        
        cachedFocus = coachRecommendation.headline
    }
    
    func mostRecentExercise() -> String? {
        let completedWorkouts = dataManager.completedWorkouts
            .sorted { $0.date > $1.date }
        
        for workout in completedWorkouts {
            if let exercise = workout.exercises.first {
                return exercise.name
            }
        }
        
        return nil
    }
    
    func recommendedExercise(
        for muscle: MuscleGroup
    ) -> Exercise? {
        
        // Only use completed workouts as training history.
        let completedWorkouts = dataManager.completedWorkouts
        
        // Get exercises from the catalog that train this muscle.
        let catalogExercises = ExerciseCatalog.exercises(
            for: muscle
        )
        
        guard !catalogExercises.isEmpty else {
            return nil
        }
        
        // MARK: - Rank exercises by established history
        
        struct ExerciseUsage {
            let definition: ExerciseDefinition
            let sessions: Int
            let totalSets: Int
            let mostRecentDate: Date?
        }
        
        let usage: [ExerciseUsage] = catalogExercises.map { definition in
            
            var sessionCount = 0
            var totalSets = 0
            var mostRecentDate: Date?
            
            for workout in completedWorkouts {
                
                let matchingExercises = workout.exercises.filter {
                    $0.name.caseInsensitiveCompare(
                        definition.name
                    ) == .orderedSame
                }
                
                if !matchingExercises.isEmpty {
                    sessionCount += 1
                    
                    totalSets += matchingExercises.reduce(0) {
                        $0 + $1.sets.count
                    }
                    
                    if mostRecentDate == nil ||
                        workout.date > mostRecentDate! {
                        mostRecentDate = workout.date
                    }
                }
            }
            
            return ExerciseUsage(
                definition: definition,
                sessions: sessionCount,
                totalSets: totalSets,
                mostRecentDate: mostRecentDate
            )
        }
        
        // Prefer the exercise you have established the most history with.
        // Total sets breaks ties between exercises with the same session count.
        // Recency is only a final tie-breaker.
        let best = usage.sorted { lhs, rhs in
            
            if lhs.sessions != rhs.sessions {
                return lhs.sessions > rhs.sessions
            }
            
            if lhs.totalSets != rhs.totalSets {
                return lhs.totalSets > rhs.totalSets
            }
            
            switch (lhs.mostRecentDate, rhs.mostRecentDate) {
            case let (left?, right?):
                return left > right
                
            case (_?, nil):
                return true
                
            case (nil, _?):
                return false
                
            case (nil, nil):
                return lhs.definition.name < rhs.definition.name
            }
        }.first
        
        guard let definition = best?.definition else {
            return nil
        }
        
        return Exercise(
            name: definition.name,
            muscleGroup: definition.primaryMuscle
        )
    }
    
    func recommendedFocusMuscle() -> MuscleGroup? {
        let weeklySets = recompManager.weeklySetsByMuscle(
            dataManager: dataManager
        )
        
        let target = recompManager.weeklySetTarget
        
        let priorityMuscle = MuscleGroup.allCases.min {
            let firstSets = weeklySets[$0] ?? 0
            let secondSets = weeklySets[$1] ?? 0
            
            let firstDeficit = max(target - firstSets, 0)
            let secondDeficit = max(target - secondSets, 0)
            
            return firstDeficit > secondDeficit
        }
        
        guard let muscle = priorityMuscle else {
            return nil
        }
        
        guard (weeklySets[muscle] ?? 0) < target else {
            return nil
        }
        
        return muscle
    }
}
