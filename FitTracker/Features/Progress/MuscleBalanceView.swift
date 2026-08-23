import SwiftUI

struct MuscleBalanceView: View {
    
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var recompManager = RecompManager.shared
    
    private struct MuscleBalanceItem: Identifiable {
        let id = UUID()
        let muscle: MuscleGroup
        let sets: Int
        let target: Int
        
        var progress: Double {
            guard target > 0 else {
                return 0
            }
            
            return min(
                Double(sets) / Double(target),
                1.0
            )
        }
        
        var percentage: Int {
            guard target > 0 else {
                return 0
            }
            
            return Int(
                (Double(sets) / Double(target)) * 100
            )
        }
    }
    
    private var balanceItems: [MuscleBalanceItem] {
        let weeklySets = recompManager.weeklySetsByMuscle(
            dataManager: dataManager
        )

        return MuscleGroup.allCases.map { muscle in
            MuscleBalanceItem(
                muscle: muscle,
                sets: weeklySets[muscle, default: 0],
                target: recompManager.weeklyTarget(for: muscle)
            )
        }
    }
    
    private var weakestItem: MuscleBalanceItem? {
        balanceItems.min {
            $0.progress < $1.progress
        }
    }
    
    private var onTargetCount: Int {
        balanceItems.filter {
            $0.sets >= $0.target
        }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // MARK: Header
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Muscle Balance")
                        .font(.headline)
                    
                    Text("Weekly training distribution")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(onTargetCount)/\(balanceItems.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("on target")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // MARK: Muscle Breakdown
            
            VStack(spacing: 14) {
                ForEach(balanceItems) { item in
                    VStack(spacing: 7) {
                        
                        HStack {
                            Text(item.muscle.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(item.sets)/\(item.target) sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(statusText(for: item))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(statusColor(for: item))
                                .frame(minWidth: 70, alignment: .trailing)
                        }
                        
                        ProgressView(value: item.progress)
                            .tint(statusColor(for: item))
                    }
                }
            }
            
            // MARK: Weakest Area
            
            if let weakestItem {
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        
                        Text("Weakest Training Area")
                            .font(.headline)
                    }
                    
                    Text(
                        "\(weakestItem.muscle.rawValue) — " +
                        "\(weakestItem.sets)/\(weakestItem.target) sets " +
                        "(\(weakestItem.percentage)% of target)"
                    )
                    .font(.subheadline)
                    
                    Text(
                        weakestItem.sets == 0
                        ? "No sets logged for this muscle this week."
                        : "Consider prioritizing this muscle in your next workout."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.orange.opacity(0.08)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )
            }
            
            // MARK: Explanation
            
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                
                Text(
                    "Balance reflects your logged weekly set distribution. " +
                    "It measures training volume, not physical muscle size."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(
            RoundedRectangle(cornerRadius: 14)
        )
        .shadow(
            color: .black.opacity(0.06),
            radius: 4,
            x: 0,
            y: 2
        )
    }
    
    private func statusText(
        for item: MuscleBalanceItem
    ) -> String {
        
        if item.sets == 0 {
            return "Neglected"
        }
        
        if item.progress < 0.5 {
            return "Behind"
        }
        
        if item.progress < 0.75 {
            return "Building"
        }
        
        if item.progress < 1.0 {
            return "Near Target"
        }
        
        return "On Target"
    }
    
    private func statusColor(
        for item: MuscleBalanceItem
    ) -> Color {
        
        if item.sets == 0 {
            return .red
        }
        
        if item.progress < 0.5 {
            return .orange
        }
        
        if item.progress < 0.75 {
            return .orange
        }
        
        if item.progress < 1.0 {
            return .blue
        }
        
        return .green
    }
}
