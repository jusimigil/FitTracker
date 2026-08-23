import SwiftUI
import Charts

struct MuscleVolumeView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var recompManager = RecompManager.shared
    
    private var muscleData: [(muscle: MuscleGroup, sets: Int)] {
        let counts = recompManager.weeklySetsByMuscle(
            dataManager: dataManager
        )
        
        return MuscleGroup.allCases.map { muscle in
            (
                muscle: muscle,
                sets: counts[muscle] ?? 0
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // MARK: Header
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Muscle Group Volume")
                    .font(.headline)
                
                Text("Completed sets • This week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // MARK: Chart
            
            Chart(muscleData, id: \.muscle) { item in
                BarMark(
                    x: .value("Sets", item.sets),
                    y: .value("Muscle", item.muscle.rawValue)
                )
                .foregroundStyle(
                    item.sets >= recompManager.weeklyTarget(for: item.muscle)
                    ? Color.green
                    : Color.blue
                )   .annotation(position: .trailing) {
                    if item.sets > 0 {
                        Text("\(item.sets)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                }
            }
            .chartXScale(
                domain: 0...max(
                    Double(
                        muscleData.map {
                            recompManager.weeklyTarget(for: $0.muscle)
                        }.max() ?? 0
                    ),
                    Double(muscleData.map(\.sets).max() ?? 0)
                )
            )            .chartXAxis {
                AxisMarks(position: .bottom)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 280)
            
            // MARK: Legend
            
            HStack(spacing: 16) {
                Label("On target", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                
                Label("Below target", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            
            // MARK: Insight
            
            if let weakest = muscleData.min(
                by: { $0.sets < $1.sets }
            ) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Training Insight")
                            .font(.caption)
                            .fontWeight(.bold)
                        
                        Text(
                            "\(weakest.muscle.rawValue) has the lowest volume this week at \(weakest.sets) sets."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(
                    Color.orange.opacity(0.08)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
        .shadow(radius: 1)
    }
}
