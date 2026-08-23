import SwiftUI
import Charts

struct ChartsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedChart: ChartType = .volume
    @State private var showAchievements = false
    @State private var showPRHistory = false
    
    enum ChartType: String, CaseIterable, Identifiable {
        case volume = "Volume"
        case strength = "Strength"
        case recovery = "Recovery"
        
        var id: String { self.rawValue }
    }
    struct MuscleVolume: Identifiable {
        let id = UUID()
        let muscle: MuscleGroup
        let sets: Int
    }
    
    private var weeklyMuscleVolumes: [MuscleVolume] {
        let weeklySets = RecompManager.shared.weeklySetsByMuscle(
            dataManager: dataManager
        )

        return MuscleGroup.allCases.map { muscle in
            MuscleVolume(
                muscle: muscle,
                sets: weeklySets[muscle, default: 0]
            )
        }
    }
    
    private func formattedWeight(_ kilograms: Double) -> String {
        return dataManager.formatWeight(kilograms)
    }
    
    private func currentSets(for muscle: MuscleGroup) -> Int {
        weeklyMuscleVolumes.first {
            $0.muscle == muscle
        }?.sets ?? 0
    }
    
    private func volumeProgress(for muscle: MuscleGroup) -> Double {
        let current = currentSets(for: muscle)
        let target = RecompManager.shared.weeklyTarget(
            for: muscle
        )
        
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
        let target = RecompManager.shared.weeklyTarget(
            for: muscle
        )
        
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
        
        let performances = dataManager.completedWorkouts.flatMap { workout in
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
                    PRManager.shared.estimatedOneRepMax(
                        weight: $0.weight,
                        reps: $0.reps
                    )
                }
                .max() ?? 0
            
            // Best strength ever
            let best1RM = exercisePerformances
                .flatMap { performance in
                    performance.sets.map {
                        PRManager.shared.estimatedOneRepMax(
                            weight: $0.weight,
                            reps: $0.reps
                        )
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
                                VStack(spacing: 16) {
                                    VolumeTrendView()
                                    
                                    MuscleVolumeView()
                                        .environmentObject(dataManager)
                                    
                                    MuscleBalanceView()
                                        .environmentObject(dataManager)
                                }
                                
                            case .strength:
                                VStack(spacing: 16) {
                                    StrengthForecastChart()
                                        .environmentObject(dataManager)
                                    
                                    StrengthProgressSection(
                                        progress: strengthProgress()
                                    )
                                }
                                
                            case .recovery:
                                VStack(spacing: 16) {
                                    RecoveryTrendView()
                                        .environmentObject(dataManager)
                                    
                                    RecoveryPatternView()
                                        .environmentObject(dataManager)
                                    
                                    RecoveryPerformanceView()
                                        .environmentObject(dataManager)
                                }
                            }
                        }
                        
                        
                    }
                }
                .navigationTitle("Progress")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        
                        Button {
                            showPRHistory = true
                        } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(.orange)
                        }
                        .accessibilityLabel("Personal Record History")
                        
                        Button {
                            showAchievements = true
                        } label: {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.orange)
                        }
                        .accessibilityLabel("Achievements")
                    }
                }
                .sheet(isPresented: $showAchievements) {
                    NavigationStack {
                        AchievementsView()
                            .environmentObject(dataManager)
                            .navigationTitle("Achievements")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                } .sheet(isPresented: $showPRHistory) {
                    NavigationStack {
                        PRHistoryView()
                            .environmentObject(dataManager)
                            .navigationTitle("Personal Record History")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") {
                                        showPRHistory = false
                                    }
                                }
                            }
                    }
                }
            }
        }
    }
    
    
    
    // MARK: - 1. VOLUME CHART
    
    // MARK: - Volume Trend

    // MARK: - Volume Trend

    struct VolumeTrendView: View {
        @EnvironmentObject var dataManager: DataManager
        
        private struct WeeklyVolumePoint: Identifiable {
            let id = UUID()
            let date: Date
            let volume: Double
        }
        
        private var chartData: [WeeklyVolumePoint] {
            let calendar = Calendar.current
            let endDate = Date()
            
            guard let startDate = calendar.date(
                byAdding: .day,
                value: -90,
                to: endDate
            ) else {
                return []
            }
            
            let recentWorkouts = dataManager.completedWorkouts.filter {
                $0.date >= startDate &&
                $0.date <= endDate
            }
            
            let grouped = Dictionary(
                grouping: recentWorkouts
            ) { workout in
                calendar.dateInterval(
                    of: .weekOfYear,
                    for: workout.date
                )?.start ?? workout.date
            }
            
            return grouped
                .map { weekStart, workouts in
                    WeeklyVolumePoint(
                        date: weekStart,
                        volume: workouts.reduce(0) {
                            $0 + $1.totalVolume
                        }
                    )
                }
                .sorted {
                    $0.date < $1.date
                }
        }
        
        private var latestWeeklyVolume: Double? {
            chartData.last?.volume
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                
                // MARK: Header
                
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Volume")
                            .font(.headline)
                        
                        Text("Weekly · Last 90 days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if let latestWeeklyVolume {
                        Text(
                            dataManager.formatVolume(
                                latestWeeklyVolume
                            )
                        )
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    }
                }
                
                // MARK: Chart
                
                if chartData.isEmpty {
                    ContentUnavailableView(
                        "Not Enough Data",
                        systemImage: "chart.bar.xaxis",
                        description: Text(
                            "Complete a workout to start tracking your volume."
                        )
                    )
                    .frame(height: 180)
                    
                } else {
                    Chart(chartData) { point in
                        LineMark(
                            x: .value(
                                "Week",
                                point.date
                            ),
                            y: .value(
                                "Volume",
                                point.volume
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        
                        PointMark(
                            x: .value(
                                "Week",
                                point.date
                            ),
                            y: .value(
                                "Volume",
                                point.volume
                            )
                        )
                    }
                    .chartXAxis {
                        AxisMarks(
                            values: .stride(
                                by: .month
                            )
                        ) {
                            AxisValueLabel(
                                format: .dateTime.month(
                                    .abbreviated
                                )
                            )
                        }
                    }
                    .chartYAxis {
                        AxisMarks(
                            position: .leading
                        )
                    }
                    .frame(height: 190)
                }
            }
            .padding()
            .background(
                Color(.systemBackground)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 14
                )
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
    
    struct StrengthProgressSection: View {
        
        let progress: [(name: String, first: Double, best: Double)]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                
                HStack {
                    Text("Strength Progress")
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(
                        systemName:
                            "figure.strengthtraining.traditional"
                    )
                    .foregroundStyle(.secondary)
                }
                
                if progress.isEmpty {
                    Text(
                        "Complete more workouts to see your strength progression."
                    )
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
                                
                                Spacer()
                                
                                Text(
                                    dataManager.formatWeight(
                                        item.first,
                                        decimals: 0
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                
                                Image(
                                    systemName:
                                        item.best >= item.first
                                    ? "arrow.up"
                                    : "arrow.down"
                                )
                                .font(.caption)
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
        }
        
        @EnvironmentObject
        private var dataManager: DataManager
    }
}








