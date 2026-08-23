import SwiftUI

struct WorkoutHistoryCard: View {
    
    let session: WorkoutSession
    let dataManager: DataManager
    let displayTitle: String
    let personalRecords: [PersonalRecord]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            // MARK: - Header
            
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    
                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(
                        session.date.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if session.isCompleted {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                } else if hasStartedWorkout {
                    Label("In Progress", systemImage: "play.circle.fill")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Color.orange.opacity(0.1)
                        )
                        .clipShape(Capsule())
                }
            }
            
            
            // MARK: - Workout Statistics
            
            if session.type == .strength {
                HStack(spacing: 0) {
                    
                    WorkoutStat(
                        value: "\(exerciseCount)",
                        label: "Exercises",
                        icon: "dumbbell.fill"
                    )
                    
                    Spacer()
                    
                    WorkoutStat(
                        value: "\(setCount)",
                        label: "Sets",
                        icon: "square.stack.3d.up.fill"
                    )
                    
                    Spacer()
                    
                    WorkoutStat(
                        value: dataManager.formatVolume(
                            session.totalVolume
                        ),
                        label: "Volume",
                        icon: "chart.bar.fill"
                    )
                    
                    if let duration = durationText {
                        Spacer()
                        
                        WorkoutStat(
                            value: duration,
                            label: "Duration",
                            icon: "clock.fill"
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            
            
            // MARK: - Personal Records
            
            if !personalRecords.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    
                    Divider()
                    
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        
                        Text("Personal Records")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        
                        Spacer()
                        
                        Text("\(personalRecords.count)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    
                    
                    // Group PRs by exercise instead of
                    // displaying every record individually.
                    ForEach(groupedPersonalRecords, id: \.exerciseName) { group in
                        
                        HStack(alignment: .top, spacing: 10) {
                            
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .frame(width: 18)
                            
                            VStack(
                                alignment: .leading,
                                spacing: 3
                            ) {
                                
                                Text(group.exerciseName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                
                                Text(
                                    group.records
                                        .map {
                                            shortPRType($0.type)
                                        }
                                        .joined(separator: " • ")
                                )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if group.records.count == 1,
                               let record = group.records.first {
                                
                                Text(prDisplayValue(record))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.orange)
                                
                            } else {
                                
                                Text(
                                    "\(group.records.count) PRs"
                                )
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                            }
                        }
                    }
                }
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
    
    
    // MARK: - Computed Properties
    private var hasStartedWorkout: Bool {
        session.exercises.contains {
            !$0.sets.isEmpty
        }
    }
    
    private var exerciseCount: Int {
        session.exercises.count
    }
    
    private var setCount: Int {
        session.exercises.reduce(0) { total, exercise in
            total + exercise.sets.count
        }
    }
    
    private var durationText: String? {
        guard let duration = session.duration else {
            return nil
        }
        
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        
        return "\(minutes)m"
    }
    
    
    // MARK: - Grouped PRs
    
    private var groupedPersonalRecords:
        [(exerciseName: String, records: [PersonalRecord])] {
        
        let grouped = Dictionary(
            grouping: personalRecords,
            by: { $0.exerciseName }
        )
        
        return grouped
            .map {
                (
                    exerciseName: $0.key,
                    records: $0.value.sorted {
                        $0.type.rawValue < $1.type.rawValue
                    }
                )
            }
            .sorted {
                $0.exerciseName < $1.exerciseName
            }
    }
    
    
    // MARK: - Short PR Labels
    
    private func shortPRType(
        _ type: PRType
    ) -> String {
        
        switch type {
        case .heaviestWeight:
            return "Weight"
            
        case .repRecord:
            return "Reps"
            
        case .estimatedOneRepMax:
            return "1RM"
        }
    }
    
    
    // MARK: - PR Display Value
    
    private func prDisplayValue(
        _ record: PersonalRecord
    ) -> String {
        
        switch record.type {
        case .heaviestWeight:
            return dataManager.formatWeight(record.weight)
            
        case .repRecord:
            return "\(record.reps) reps"
            
        case .estimatedOneRepMax:
            return dataManager.formatWeight(
                record.estimatedOneRepMax
            )
        }
    }
}
