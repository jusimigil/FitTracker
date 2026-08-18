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
    
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    trainerBriefingView
                    todaysFocusView
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
            .onChange(of: dataManager.workouts) { _, _ in calculateStats() }
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
                            recoveryScore:
                                Int(dailyRecoveryScore)
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
    
    var todaysFocusView: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // MARK: Header
            
            HStack(spacing: 10) {
                Image(systemName: "target")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("TODAY'S PLAN")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    
                    Text("Today's Focus")
                        .font(.headline)
                }
                
                Spacer()
            }
            
            // MARK: Focus
            
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "scope")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 34, height: 34)
                    .background(
                        Color.blue.opacity(0.1)
                    )
                    .clipShape(Circle())
                
                Text(cachedFocus)
                    .font(.subheadline)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
            
            // MARK: Recommended Muscle
            
            if let muscle = recommendedFocusMuscle() {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(.blue)
                    
                    Text("Recommended focus:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(muscle.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(
                    Color.blue.opacity(0.07)
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
                    
                    Text("Begin your recommended session")
                        .font(.caption)
                        .opacity(0.85)
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
        if lastCheckInDate != today {
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
        
        if let latestExercise = mostRecentExercise() {
            cachedOverload = recompManager.suggestProgressiveOverload(
                for: latestExercise,
                dataManager: dataManager
            )
        } else {
            cachedOverload = "Complete a workout to receive a progression recommendation."
        }
        
        cachedFocus = generateTodaysFocus()
    }
    
    func mostRecentExercise() -> String? {
        let completedWorkouts = dataManager.workouts
            .filter { $0.isCompleted }
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
        
        let completedWorkouts = dataManager.workouts
            .filter { $0.isCompleted }
            .sorted { $0.date > $1.date }
        
        for workout in completedWorkouts {
            if let exercise = workout.exercises.first(
                where: { $0.muscleGroup == muscle }
            ) {
                return exercise
            }
        }
        
        return nil
    }
    
    func generateTodaysFocus() -> String {
        
        guard !dataManager.workouts.isEmpty else {
            return """
            Start with a simple workout and focus on establishing your baseline.
            Log your sets, reps, weight, and RPE so FitTracker can personalize your recommendations.
            """
        }
        
        
        // MARK: Recovery
        
        if dailyRecoveryScore <= 4 {
            return """
            Recovery is low today (\(Int(dailyRecoveryScore))/10).
            Consider a lighter session, reduce the weight, and prioritize good form and recovery.
            """
        }
        
        
        // MARK: Weekly Muscle Volume
        
        let weeklySets = recompManager.weeklySetsByMuscle(
            dataManager: dataManager
        )
        
        let target = recompManager.weeklySetTarget
        
        
        // Find the muscle furthest below its target
        
        let priorityMuscle = MuscleGroup.allCases.min {
            let firstSets = weeklySets[$0] ?? 0
            let secondSets = weeklySets[$1] ?? 0
            
            return firstSets < secondSets
        }
        
        guard let muscle = priorityMuscle else {
            return """
            Your training data is still being analyzed.
            Follow your normal training plan and use RPE to guide today's intensity.
            """
        }
        
        
        let completedSets = weeklySets[muscle] ?? 0
        
        
        // MARK: Priority Recommendation
        
        if completedSets < target {
            
            let remainingSets = target - completedSets
            
            if let exercise = recommendedExercise(for: muscle) {
                
                let recommendation =
                    recompManager.suggestProgressiveOverload(
                        for: exercise.name,
                        dataManager: dataManager
                    )
                
                return """
                🎯 Prioritize \(muscle.rawValue) today.
                
                You've completed \(completedSets) of \(target) weekly sets.
                That's \(remainingSets) sets below your current target.
                
                Recommended:
                \(exercise.name)
                
                \(recommendation)
                """
                
            } else {
                
                return """
                🎯 Prioritize \(muscle.rawValue) today.
                
                You've completed \(completedSets) of \(target) weekly sets.
                That's \(remainingSets) sets below your current target.
                
                Consider adding a \(muscle.rawValue) exercise to your next workout.
                """
            }
        }
        
        // MARK: Already On Target
        
        if completedSets >= target {
            
            if !cachedWeakLink.isEmpty &&
                !cachedWeakLink.contains("No significant") &&
                !cachedWeakLink.contains("Analyzing") {
                
                return """
                \(muscle.rawValue) is already at your weekly target with \(completedSets) sets.
                
                Your current analysis suggests:
                
                \(cachedWeakLink)
                
                Consider prioritizing your lagging area instead.
                """
            }
            
            return """
            Your weekly \(muscle.rawValue) volume is on target at \(completedSets) sets.
            
            Recovery is \(Int(dailyRecoveryScore))/10.
            Follow your normal training plan and focus on progressive overload.
            """
        }
        
        
        // MARK: Default
        
        return """
        Recovery is \(Int(dailyRecoveryScore))/10.
        Follow your normal training plan and adjust intensity using RPE.
        """
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
