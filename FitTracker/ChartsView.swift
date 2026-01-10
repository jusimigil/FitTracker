import SwiftUI
import Charts

struct ChartsView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Chart 1: Volume Over Time
                    VStack(alignment: .leading) {
                        Text("Volume Progression")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        if dataManager.workouts.isEmpty {
                            ContentUnavailableView("No Data", systemImage: "chart.xyaxis.line", description: Text("Log a workout to see your progress"))
                                .frame(height: 200)
                        } else {
                            Chart {
                                ForEach(dataManager.workouts.sorted(by: { $0.date < $1.date })) { session in
                                    // The Line
                                    LineMark(
                                        x: .value("Date", session.date),
                                        y: .value("Volume", session.totalVolume)
                                    )
                                    .interpolationMethod(.catmullRom) // Smooth curves
                                    .foregroundStyle(.blue)
                                    .symbol(by: .value("Date", session.date))
                                    
                                    // The Gradient Area Underneath
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
                            .frame(height: 250)
                            // Format the X-Axis dates to look clean
                            .chartXAxis {
                                AxisMarks(format: .dateTime.month().day())
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Placeholder for future charts
                    Text("More stats coming soon...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                }
                .padding()
            }
            .navigationTitle("Analytics")
        }
    }
}
