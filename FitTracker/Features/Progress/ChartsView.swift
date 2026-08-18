import SwiftUI
import Charts

struct ChartsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedChart: ChartType = .volume
    
    enum ChartType: String, CaseIterable, Identifiable {
        case volume = "Volume"
        case forecast = "Strength AI"
        case balance = "Balance"
        case recovery = "Recovery"
        case recoveryPerformance = "Recovery vs Performance"
        var id: String { self.rawValue }
    }
    
    struct MuscleVolume: Identifiable {
        let id = UUID()
        let muscle: MuscleGroup
        let sets: Int
    }
    
    private var weeklyMuscleVolumes: [MuscleVolume] {
        let calendar = Calendar.current
        let now = Date()

        guard let weekStart = calendar.date(
            from: calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: now
            )
        ) else {
            return []
        }

        var counts: [MuscleGroup: Int] = [:]

        for muscle in MuscleGroup.allCases {
            counts[muscle] = 0
        }

        for workout in dataManager.workouts {
            guard workout.date >= weekStart else {
                continue
            }

            for exercise in workout.exercises {
                counts[exercise.muscleGroup, default: 0] += exercise.sets.count
            }
        }

        return MuscleGroup.allCases.map { muscle in
            MuscleVolume(
                muscle: muscle,
                sets: counts[muscle, default: 0]
            )
        }
    }
    
    private func formattedWeight(_ kilograms: Double) -> String {
        return dataManager.formatWeight(kilograms)
    }

    private func targetSets(for muscle: MuscleGroup) -> Int {
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

    private func currentSets(for muscle: MuscleGroup) -> Int {
        weeklyMuscleVolumes.first {
            $0.muscle == muscle
        }?.sets ?? 0
    }

    private func volumeProgress(for muscle: MuscleGroup) -> Double {
        let current = currentSets(for: muscle)
        let target = targetSets(for: muscle)
        
        guard target > 0 else {
            return 0
        }
        
        // Allow the progress bar to show up to 125% of target.
        // This lets the user see when volume is becoming excessive.
        return min(
            Double(current) / Double(target),
            1.25
        )
    }

    private func volumeStatus(for muscle: MuscleGroup) -> String {
        let current = currentSets(for: muscle)
        let target = targetSets(for: muscle)

        if current == 0 {
            return "No training"
        }

        if current < Int(Double(target) * 0.5) {
            return "Low"
        }

        if current < target {
            return "Building"
        }

        if current <= Int(Double(target) * 1.25) {
            return "On target"
        }

        return "High"
    }
    
    private func estimatedOneRepMax(
        weight: Double,
        reps: Int
    ) -> Double {
        guard weight > 0, reps > 0 else {
            return 0
        }
        
        return weight * (1.0 + Double(reps) / 30.0)
    }
    
    private func strengthProgress() -> [(name: String, first: Double, best: Double)] {
        
        var result: [(name: String, first: Double, best: Double)] = []
        
        let performances = dataManager.workouts.flatMap { workout in
            workout.exercises.map { exercise in
                (
                    name: exercise.name,
                    date: workout.date,
                    sets: exercise.sets
                )
            }
        }
        
        let grouped = Dictionary(
            grouping: performances,
            by: { $0.name }
        )
        
        for (name, exercisePerformances) in grouped {
            
            let sorted = exercisePerformances.sorted {
                $0.date < $1.date
            }
            
            guard let firstPerformance = sorted.first else {
                continue
            }
            
            // Starting strength
            let first1RM = firstPerformance.sets
                .map {
                    $0.weight * (1.0 + Double($0.reps) / 30.0)
                }
                .max() ?? 0
            
            // Best strength ever
            let best1RM = exercisePerformances
                .flatMap { performance in
                    performance.sets.map {
                        $0.weight * (1.0 + Double($0.reps) / 30.0)
                    }
                }
                .max() ?? 0
            
            guard first1RM > 0, best1RM > 0 else {
                continue
            }
            
            result.append(
                (
                    name: name,
                    first: first1RM,
                    best: best1RM
                )
            )
        }
        
        return result.sorted {
            $0.best > $1.best
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // MARK: - Chart Selector
                
                Picker("Chart Type", selection: $selectedChart) {
                    ForEach(ChartType.allCases) { type in
                        Text(type.rawValue)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 10)
                
                
                // MARK: - Progress Content
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // MARK: Selected Chart
                        
                        Group {
                            switch selectedChart {
                            case .volume:
                                VolumeTrendView()
                                
                            case .forecast:
                                StrengthForecastChart()
                                
                            case .balance:
                                MuscleRadarChart()
                                
                            case .recovery:
                                    RecoveryTrendView()
                                
                            case .recoveryPerformance:
                                    RecoveryPerformanceView()
                            }
                        }
                        
                        MuscleVolumeView()
                            .environmentObject(dataManager)
                        
                        NavigationLink {
                            PRHistoryView()
                                .environmentObject(dataManager)
                        } label: {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.orange)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Personal Record History")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    Text("View your PR progression by exercise")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(
                                RoundedRectangle(cornerRadius: 12)
                            )
                            .shadow(radius: 1)
                        }
                        .buttonStyle(.plain)
                        // MARK: Strength Progress

                        VStack(alignment: .leading, spacing: 12) {
                            
                            HStack {
                                Text("Strength Progress")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .foregroundStyle(.secondary)
                            }
                            
                            let progress = strengthProgress()
                            
                            if progress.isEmpty {
                                
                                Text("Complete more workouts to see your strength progression.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                                
                            } else {
                                
                                ForEach(
                                    Array(progress.prefix(5)),
                                    id: \.name
                                ) { item in
                                    
                                    VStack(spacing: 8) {
                                        
                                        HStack {
                                            Text(item.name)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            
                                            Spacer()
                                            
                                            let percentage =
                                                ((item.best - item.first) / item.first) * 100
                                            
                                            Text(
                                                "\(percentage >= 0 ? "+" : "")\(percentage, specifier: "%.1f")%"
                                            )
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        }
                                        
                                        HStack {
                                            Text(
                                                "\(dataManager.formatWeight(item.first)) → \(dataManager.formatWeight(item.best))"
                                            )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            
                                            Spacer()
                                            
                                            Image(
                                                systemName:
                                                    item.best >= item.first
                                                    ? "arrow.up"
                                                    : "arrow.down"
                                            )
                                            .font(.caption)
                                        }
                                    }
                                    
                                    if item.name != progress.prefix(5).last?.name {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 16)
                        )
                        
                        // MARK: Weekly Summary
                        
                        VStack(spacing: 16) {
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("This Week")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Text(
                                        "\(weeklyMuscleVolumes.reduce(0) { $0 + $1.sets }) sets"
                                    )
                                    .font(.title3)
                                    .fontWeight(.bold)
                                }
                                
                                Spacer()
                                
                                let musclesOnTarget = MuscleGroup.allCases.filter {
                                    volumeStatus(for: $0) == "On target"
                                }.count
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("On Target")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Text(
                                        "\(musclesOnTarget)/\(MuscleGroup.allCases.count)"
                                    )
                                    .font(.title3)
                                    .fontWeight(.bold)
                                }
                            }
                            
                            VStack(spacing: 16) {
                                ForEach(
                                    MuscleGroup.allCases,
                                    id: \.self
                                ) { muscle in
                                    
                                    VStack(spacing: 8) {
                                        
                                        HStack {
                                            Text(muscle.rawValue)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Spacer()
                                            
                                            Text(
                                                "\(currentSets(for: muscle)) / \(targetSets(for: muscle)) sets"
                                            )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            
                                            Text(volumeStatus(for: muscle))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        
                                        ProgressView(
                                            value: volumeProgress(for: muscle)
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        
                        // MARK: Personal Records
                        
                        VStack(alignment: .leading, spacing: 12) {
                            
                            HStack {
                                Text("Personal Records")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text(
                                    "\(dataManager.personalRecords.count)"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            
                            if dataManager.personalRecords.isEmpty {
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "trophy")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("No Personal Records Yet")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text(
                                            "Keep training and your achievements will appear here."
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                
                            } else {
                                
                                VStack(spacing: 12) {
                                    ForEach(
                                        dataManager.personalRecords
                                            .sorted { $0.date > $1.date }
                                            .prefix(5)
                                    ) { record in
                                        
                                        HStack(spacing: 12) {
                                            
                                            Image(systemName: "trophy.fill")
                                                .font(.title3)
                                            
                                            VStack(
                                                alignment: .leading,
                                                spacing: 3
                                            ) {
                                                Text(record.exerciseName)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                
                                                Text(record.type.rawValue)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            VStack(
                                                alignment: .trailing,
                                                spacing: 3
                                            ) {
                                                Text(
                                                    "\(formattedWeight(record.weight)) × \(record.reps)"
                                                )
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                
                                                Text(
                                                    record.date.formatted(
                                                        date: .abbreviated,
                                                        time: .omitted
                                                    )
                                                )
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 16)
                        )
                        
                        
                        // MARK: Areas to Prioritize
                        
                        let lowMuscles = MuscleGroup.allCases.filter {
                            let status = volumeStatus(for: $0)
                            return status == "Low" || status == "No training"
                        }
                        
                        if !lowMuscles.isEmpty {
                            
                            HStack(
                                alignment: .top,
                                spacing: 10
                            ) {
                                Image(
                                    systemName:
                                        "exclamationmark.triangle.fill"
                                )
                                
                                VStack(
                                    alignment: .leading,
                                    spacing: 4
                                ) {
                                    Text("Areas to Prioritize")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text(
                                        lowMuscles
                                            .map { $0.rawValue }
                                            .joined(separator: ", ")
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 16)
                            )
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Progress")
        } 
    } 
}



// MARK: - 1. VOLUME CHART

struct VolumeTrendView: View {
    @EnvironmentObject var dataManager: DataManager
    
    private var completedWorkouts: [WorkoutSession] {
        dataManager.workouts
            .filter { $0.isCompleted }
            .sorted { $0.date < $1.date }
    }
    
    private var chartData: [DatePoint] {
        let calendar = Calendar.current
        let endDate = Date()
        
        guard let startDate = calendar.date(
            byAdding: .day,
            value: -90,
            to: endDate
        ) else {
            return []
        }
        
        return completedWorkouts
            .filter {
                $0.date >= startDate &&
                $0.date <= endDate
            }
            .map {
                DatePoint(
                    date: $0.date,
                    value: Double($0.totalVolume)
                )
            }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            HStack {
                Text("Total Volume")
                    .font(.headline)
                
                Spacer()
                
                Text("Last 90 Days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            if chartData.isEmpty {
                ContentUnavailableView(
                    "Not Enough Data",
                    systemImage: "chart.bar.xaxis",
                    description: Text(
                        "Complete a workout to start tracking your volume trend."
                    )
                )
                .frame(height: 250)
            } else {
                Chart {
                    ForEach(chartData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Volume", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Volume", point.value)
                        )
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(
                            format: .dateTime.month(.abbreviated)
                        )
                    }
                }
                .chartYAxis {
                    AxisMarks()
                }
                .frame(height: 250)
                .padding()
                .background(
                    Color(.systemBackground)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )
            }
        }
        .padding(.vertical)
        .background(
            Color(.systemBackground)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
    }
}

// MARK: - 2. STRENGTH FORECAST (AI)
struct StrengthForecastChart: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var recompManager = RecompManager.shared
    
    @State private var selectedExercise = ""
    
    private var defaultExercise: String {
        if availableExercises.contains("Bench Press") {
            return "Bench Press"
        }
        
        return availableExercises.first ?? ""
    }
    
    private var availableExercises: [String] {
        let names = dataManager.workouts
            .flatMap { $0.exercises }
            .map { $0.name }
        
        return Array(Set(names)).sorted()
    }
    
    var data: (history: [DatePoint], prediction: [DatePoint]) {
        recompManager.getStrengthPrediction(
            for: selectedExercise,
            dataManager: dataManager
        )
    }
    
    var currentStrength: Double {
        data.history.last?.value ?? 0
    }
    
    var predictedStrength: Double {
        data.prediction.last?.value ?? currentStrength
    }
    
    var projectedChange: Double {
        guard currentStrength > 0 else {
            return 0
        }
        
        return (
            (predictedStrength - currentStrength) /
            currentStrength
        ) * 100
    }
    
    var startingStrength: Double {
        data.history.first?.value ?? 0
    }

    var overallChange: Double {
        guard startingStrength > 0 else {
            return 0
        }
        
        return (
            (currentStrength - startingStrength) /
            startingStrength
        ) * 100
    }

    var trendDirection: String {
        if overallChange > 2 {
            return "Improving"
        } else if overallChange < -2 {
            return "Declining"
        } else {
            return "Stable"
        }
    }

    var trendIcon: String {
        if overallChange > 2 {
            return "arrow.up.right"
        } else if overallChange < -2 {
            return "arrow.down.right"
        } else {
            return "arrow.right"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // MARK: - Header
            
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.purple)
                
                Text("Strength AI")
                    .font(.headline)
                
                Spacer()
                
                Menu {
                    ForEach(availableExercises, id: \.self) { exercise in
                        Button {
                            selectedExercise = exercise
                        } label: {
                            HStack {
                                Text(exercise)
                                
                                if exercise == selectedExercise {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedExercise)
                        
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                }
            }
            
            
            if selectedExercise.isEmpty || data.history.count < 3 {
                
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    Text(
                        selectedExercise.isEmpty
                        ? "Complete a workout to unlock Strength AI."
                        : "Log at least 3 \(selectedExercise) sessions to unlock AI predictions."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                
            } else {
                
                // MARK: - AI Summary
                
                VStack(spacing: 12) {
                    
                
                    HStack(spacing: 12) {
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(
                                dataManager.formatWeight(
                                    currentStrength,
                                    decimals: 1
                                )
                            )
                            .font(.title3)
                            .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("30-Day Projection")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(
                                dataManager.formatWeight(
                                    predictedStrength,
                                    decimals: 1
                                )
                            )
                            .font(.title3)
                            .fontWeight(.bold)
                        }
                    }
                    
                    
                    Divider()
                    
                    
                    HStack {
                        
                        if projectedChange > 0 {
                            Image(systemName: "arrow.up")
                            
                            Text(
                                "+\(projectedChange, specifier: "%.1f")% projected improvement"
                            )
                            
                        } else if projectedChange < 0 {
                            Image(systemName: "arrow.down")
                            
                            Text(
                                "\(projectedChange, specifier: "%.1f")% projected change"
                            )
                            
                        } else {
                            Image(systemName: "arrow.right")
                            
                            Text("Stable projected strength")
                        }
                        
                        Spacer()
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(
                        projectedChange > 0
                        ? .green
                        : projectedChange < 0
                            ? .red
                            : .secondary
                    )
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )
                
                // MARK: - Strength Trend Summary

                HStack(spacing: 12) {
                    
                    StrengthMetric(
                        title: "Starting",
                        value: dataManager.formatWeight(
                            startingStrength,
                            decimals: 1
                        )
                    )
                    
                    StrengthMetric(
                        title: "Current",
                        value: dataManager.formatWeight(
                            currentStrength,
                            decimals: 1
                        )
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Overall")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: trendIcon)
                            
                            Text(
                                "\(overallChange >= 0 ? "+" : "")\(overallChange, specifier: "%.1f")%"
                            )
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            overallChange > 2
                            ? .green
                            : overallChange < -2
                                ? .red
                                : .secondary
                        )
                        
                        Text(trendDirection)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )
                
                // MARK: - Chart
                
                Chart {
                    
                    ForEach(data.history) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("1RM", point.value)
                        )
                        .foregroundStyle(.blue)
                        .symbol(Circle())
                    }
                    
                    ForEach(data.prediction) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Predicted", point.value)
                        )
                        .lineStyle(
                            StrokeStyle(
                                lineWidth: 2,
                                dash: [5, 5]
                            )
                        )
                        .foregroundStyle(.purple)
                    }
                }
                .frame(height: 250)
                .padding()
                .background(
                    Color(.systemBackground)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )
                
                
                // MARK: - Explanation
                
                HStack(
                    alignment: .top,
                    spacing: 8
                ) {
                    Image(systemName: "info.circle")
                    
                    Text(
                        "The projection is based on your historical estimated 1RM trend. It is an estimate, not a guarantee."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } 
        } .onAppear {
            if selectedExercise.isEmpty {
                selectedExercise = defaultExercise
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }
}

struct StrengthMetric: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
        }
    }
}

// MARK: - 3. MUSCLE RADAR CHART
struct MuscleRadarChart: View {
    @EnvironmentObject var dataManager: DataManager
    
    struct MuscleData { let muscle: String; let sets: Int }
    
    var radarData: [MuscleData] {
        var map = ["Chest":0,"Back":0,"Legs":0,"Shoulders":0,"Arms":0,"Core":0]
        dataManager.workouts.filter{$0.isCompleted}.forEach { w in
            w.exercises.forEach { e in map[e.muscleGroup.rawValue, default:0] += e.sets.count }
        }
        let order = ["Chest","Back","Legs","Shoulders","Arms","Core"]
        return order.map { MuscleData(muscle: $0, sets: map[$0] ?? 0) }
    }
    
    var maxVol: Double { Double(radarData.map{$0.sets}.max() ?? 10) }
    
    var body: some View {
        VStack {
            Text("Weekly Balance").font(.headline)
            RadarChartView(data: radarData, maxVolume: maxVol)
                .frame(height: 300)
                .padding()
                .background(Color(.systemBackground)).cornerRadius(12)
        }
        .padding()
        .shadow(radius: 2)
    }
}

// MARK: - HELPERS
struct ChartCard: View {
    let title: String
    let data: [DatePoint]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary).padding(.leading)
            Chart {
                ForEach(data) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Val", point.value))
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 250)
            .padding()
        }
        .background(Color(.systemBackground)).cornerRadius(12).padding().shadow(radius: 2)
    }
}

// Radar Chart Shapes
struct RadarChartView: View {
    let data: [MuscleRadarChart.MuscleData]; let maxVolume: Double
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
            let radius = min(geo.size.width, geo.size.height)/2 * 0.8
            ZStack {
                ForEach(1...4, id: \.self) { i in
                    RadarWebShape(sides: data.count, value: Double(i)/4.0)
                        .stroke(Color.gray.opacity(0.3))
                }
                RadarDataShape(data: data, maxVolume: maxVolume).fill(Color.purple.opacity(0.3))
                RadarDataShape(data: data, maxVolume: maxVolume).stroke(Color.purple, lineWidth: 2)
                ForEach(0..<data.count, id:\.self) { i in
                    RadarLabel(i: i, count: data.count, radius: radius, center: center, text: data[i].muscle)
                }
            }
        }
    }
}

struct RadarLabel: View {
    let i: Int; let count: Int; let radius: CGFloat; let center: CGPoint; let text: String
    var body: some View {
        let angleDeg = Double(i) * (360.0/Double(count)) - 90.0
        let angleRad = angleDeg * .pi/180.0
        let x = center.x + (radius + 20) * cos(angleRad)
        let y = center.y + (radius + 20) * sin(angleRad)
        return Text(text).font(.caption2).position(x: x, y: y)
    }
}

struct RadarWebShape: Shape {
    let sides: Int; let value: Double
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height)/2 * value
        for i in 0..<sides {
            let angleDeg = Double(i) * (360.0/Double(sides)) - 90.0
            let angleRad = angleDeg * .pi/180.0
            let pt = CGPoint(x: center.x + radius * cos(angleRad), y: center.y + radius * sin(angleRad))
            if i==0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath(); return path
    }
}

struct RadarDataShape: Shape {
    let data: [MuscleRadarChart.MuscleData]; let maxVolume: Double
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxR = min(rect.width, rect.height)/2
        for (i, entry) in data.enumerated() {
            let r = maxR * (Double(entry.sets)/maxVolume)
            let angleDeg = Double(i) * (360.0/Double(data.count)) - 90.0
            let angleRad = angleDeg * .pi/180.0
            let pt = CGPoint(x: center.x + r * cos(angleRad), y: center.y + r * sin(angleRad))
            if i==0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath(); return path
    }
}





