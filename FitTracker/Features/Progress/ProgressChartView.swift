import SwiftUI
import Charts

struct ProgressChartView: View {
    let workouts: [WorkoutSession]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Volume Progress")
                .font(.headline)
                .padding(.bottom, 5)
            
            if workouts.isEmpty {
                // Empty State
                VStack {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Log your first workout to see charts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                // The Graph
                Chart {
                    ForEach(workouts.sorted(by: { $0.date < $1.date })) { session in
                        // The Line
                        LineMark(
                            x: .value("Date", session.date),
                            y: .value("Volume", session.totalVolume)
                        )
                        .interpolationMethod(.catmullRom) // Makes it smooth/curvy
                        .symbol(by: .value("Date", session.date))
                        .foregroundStyle(.blue)
                        
                        // The Shaded Area Underneath
                        AreaMark(
                            x: .value("Date", session.date),
                            y: .value("Volume", session.totalVolume)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .blue.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .frame(height: 150)
                // Format the X-Axis dates
                .chartXAxis {
                    AxisMarks(format: .dateTime.month().day())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
