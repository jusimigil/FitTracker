import SwiftUI
import Charts

struct RecoveryPerformanceView: View {
    @EnvironmentObject var dataManager: DataManager
    
    // MARK: - Daily Data
    
    struct PerformancePoint: Identifiable {
        let id = UUID()
        let date: Date
        let recovery: Double
        let volume: Double
    }
    
    private var points: [PerformancePoint] {
        let calendar = Calendar.current
        
        // Group completed workouts by calendar day.
        let completedWorkouts = dataManager.completedWorkouts
        
        let groupedWorkouts = Dictionary(
            grouping: completedWorkouts
        ) {
            calendar.startOfDay(for: $0.date)
        }
        
        return groupedWorkouts.compactMap { date, workouts in
            
            // Find the recovery score for that same day.
            guard let recovery = dataManager.recoveryHistory.first(
                where: {
                    calendar.isDate($0.date, inSameDayAs: date)
                }
            ) else {
                return nil
            }
            
            let volume = workouts.reduce(0.0) {
                $0 + $1.totalVolume
            }
            
            guard volume > 0 else {
                return nil
            }
            
            return PerformancePoint(
                date: date,
                recovery: recovery.score,
                volume: volume
            )
        }
        .sorted { $0.date < $1.date }
    }
    
    // MARK: - Correlation
    
    private var correlation: Double? {
        guard points.count >= 3 else {
            return nil
        }
        
        let recoveryValues = points.map(\.recovery)
        let volumeValues = points.map(\.volume)
        
        let meanRecovery =
            recoveryValues.reduce(0, +) /
            Double(recoveryValues.count)
        
        let meanVolume =
            volumeValues.reduce(0, +) /
            Double(volumeValues.count)
        
        var numerator = 0.0
        var recoveryVariance = 0.0
        var volumeVariance = 0.0
        
        for index in points.indices {
            let recoveryDifference =
                recoveryValues[index] - meanRecovery
            
            let volumeDifference =
                volumeValues[index] - meanVolume
            
            numerator += recoveryDifference * volumeDifference
            recoveryVariance += recoveryDifference * recoveryDifference
            volumeVariance += volumeDifference * volumeDifference
        }
        
        let denominator =
            sqrt(recoveryVariance * volumeVariance)
        
        guard denominator > 0 else {
            return nil
        }
        
        return numerator / denominator
    }
    
    // MARK: - Interpretation
    
    private var interpretation: String {
        guard let correlation else {
            return "Log at least 3 days with both a recovery check-in and a completed workout to see a relationship."
        }
        
        let absoluteCorrelation = abs(correlation)
        
        if absoluteCorrelation >= 0.7 {
            if correlation > 0 {
                return "Strong positive relationship. Your higher-recovery days tend to coincide with higher training volume."
            } else {
                return "Strong inverse relationship. Higher recovery scores currently tend to coincide with lower training volume."
            }
        }
        
        if absoluteCorrelation >= 0.4 {
            if correlation > 0 {
                return "Moderate positive relationship. Better recovery generally coincides with higher training volume."
            } else {
                return "Moderate inverse relationship. Higher recovery currently tends to coincide with lower training volume."
            }
        }
        
        return "Weak relationship so far. Your recovery score does not strongly predict training volume yet."
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // MARK: Header
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery vs Performance")
                        .font(.headline)
                    
                    Text("Recovery compared with daily training volume")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let correlation {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(
                            String(
                                format: "%.2f",
                                correlation
                            )
                        )
                        .font(.title2)
                        .fontWeight(.bold)
                        
                        Text("correlation")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // MARK: Chart
            
            if points.count < 3 {
                EmptyStateView(
                    icon: "chart.xyaxis.line",
                    title: "Not Enough Performance Data",
                    message: "Log at least 3 days with both a recovery check-in and a completed workout. We'll then analyze whether your recovery is related to your training performance."
                )
                .frame(minHeight: 260)
            } else {
                Chart {
                    ForEach(points) { point in
                        PointMark(
                            x: .value(
                                "Recovery",
                                point.recovery
                            ),
                            y: .value(
                                "Volume",
                                point.volume
                            )
                        )
                        .foregroundStyle(
                            scoreColor(point.recovery)
                        )
                        .symbolSize(70)
                    }
                }
                .chartXScale(domain: 1...10)
                .chartXAxis {
                    AxisMarks(values: [1, 3, 5, 7, 9, 10])
                }
                .chartYAxis {
                    AxisMarks()
                }
                .frame(height: 240)
            }
            
            // MARK: Relationship
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.purple)
                    
                    Text("What the data says")
                        .font(.headline)
                }
                
                Text(interpretation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
            .padding()
            .background(
                Color.purple.opacity(0.08)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 12)
            )
            
            // MARK: Data Explanation
            
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                
                Text(
                    "Each dot represents one day with both a recovery score and completed workout."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
        .shadow(radius: 1)
    }
    
    // MARK: - Helpers
    
    private func scoreColor(_ score: Double) -> Color {
        if score < 4 {
            return .red
        } else if score < 7 {
            return .orange
        } else {
            return .green
        }
    }
}
