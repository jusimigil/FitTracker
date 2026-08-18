import SwiftUI
import Charts

struct RecoveryTrendView: View {
    @EnvironmentObject var dataManager: DataManager
    
    private var recentEntries: [RecoveryEntry] {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -6,
            to: Date()
        ) ?? Date()
        
        return dataManager.recoveryHistory
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }
    
    private var averageScore: Double {
        guard !recentEntries.isEmpty else {
            return 0
        }
        
        return recentEntries.reduce(0) {
            $0 + $1.score
        } / Double(recentEntries.count)
    }
    
    private var highestScore: Double {
        recentEntries.map(\.score).max() ?? 0
    }
    
    private var lowestScore: Double {
        recentEntries.map(\.score).min() ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // MARK: - Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery Trend")
                        .font(.headline)
                    
                    Text("Last 7 days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if !recentEntries.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f", averageScore))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(scoreColor(averageScore))
                        
                        Text("7-day avg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if recentEntries.isEmpty {
                EmptyStateView(
                    icon: "heart.text.square.fill",
                    title: "No Recovery Data Yet",
                    message: "Complete your daily recovery check-in to start tracking how your readiness changes over time."
                )
                .frame(minHeight: 220)
            } else {
                
                // MARK: - Chart
                Chart {
                    ForEach(recentEntries) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Recovery", entry.score)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.pink)
                        
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Recovery", entry.score)
                        )
                        .foregroundStyle(scoreColor(entry.score))
                    }
                    
                    RuleMark(y: .value("Average", averageScore))
                        .foregroundStyle(.secondary)
                        .lineStyle(
                            StrokeStyle(
                                lineWidth: 1,
                                dash: [5, 5]
                            )
                        )
                }
                .chartYScale(domain: 1...10)
                .chartYAxis {
                    AxisMarks(values: [1, 3, 5, 7, 9, 10])
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 7)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .frame(height: 220)
                
                // MARK: - Summary Stats
                HStack(spacing: 12) {
                    RecoveryStat(
                        title: "Highest",
                        value: String(format: "%.0f", highestScore),
                        icon: "arrow.up.circle.fill"
                    )
                    
                    RecoveryStat(
                        title: "Average",
                        value: String(format: "%.1f", averageScore),
                        icon: "chart.line.uptrend.xyaxis"
                    )
                    
                    RecoveryStat(
                        title: "Lowest",
                        value: String(format: "%.0f", lowestScore),
                        icon: "arrow.down.circle.fill"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 1)
    }
    
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

struct RecoveryStat: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.pink)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}


