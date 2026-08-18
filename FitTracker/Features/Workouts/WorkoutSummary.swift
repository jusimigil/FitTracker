import SwiftUI

struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let personalRecords: [PersonalRecord]
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - Header
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        
                        Text("Workout Complete!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(displayTitle)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text(session.date.formatted(
                            date: .abbreviated,
                            time: .shortened
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // MARK: - Main Stats
                    HStack(spacing: 12) {
                        SummaryStatCard(
                            value: "\(session.exercises.count)",
                            label: "Exercises",
                            icon: "dumbbell.fill"
                        )
                        
                        SummaryStatCard(
                            value: "\(totalSets)",
                            label: "Sets",
                            icon: "square.stack.3d.up.fill"
                        )
                        
                        SummaryStatCard(
                            value: durationText,
                            label: "Duration",
                            icon: "clock.fill"
                        )
                    }
                    
                    // MARK: - Volume
                    summarySection {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(.blue)
                            
                            Text("Total Volume")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text(dataManager.formatVolume(session.totalVolume))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    // MARK: - Health Stats
                    if session.averageHeartRate != nil ||
                       session.activeCalories != nil {
                        
                        summarySection {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Workout Stats")
                                    .font(.headline)
                                
                                if let heartRate = session.averageHeartRate {
                                    SummaryRow(
                                        icon: "heart.fill",
                                        title: "Average Heart Rate",
                                        value: "\(Int(heartRate)) BPM"
                                    )
                                }
                                
                                if let calories = session.activeCalories {
                                    SummaryRow(
                                        icon: "flame.fill",
                                        title: "Active Calories",
                                        value: "\(Int(calories)) kcal"
                                    )
                                }
                            }
                        }
                    }
                    
                    // MARK: - Personal Records
                    if !personalRecords.isEmpty {
                        summarySection {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "trophy.fill")
                                        .foregroundStyle(.yellow)
                                    
                                    Text("Personal Records")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Text("\(personalRecords.count)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(6)
                                        .background(Color.orange.opacity(0.12))
                                        .foregroundStyle(.orange)
                                        .clipShape(Circle())
                                }
                                
                                ForEach(personalRecords) { record in
                                    PRSummaryRow(record: record)
                                }
                            }
                        }
                    }
                    
                    // MARK: - Exercise Breakdown
                    summarySection {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Exercise Breakdown")
                                .font(.headline)
                            
                            ForEach(session.exercises) { exercise in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(exercise.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        
                                        Text(
                                            "\(exercise.sets.count) sets"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(
                                        dataManager.formatVolume(exerciseVolume(exercise))
                                    )
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                    
                    // MARK: - Finish
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 5)
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Computed Properties
    
    private var displayTitle: String {
        if let title = session.workoutTitle, !title.isEmpty {
            return title
        }
        
        if !session.notes.isEmpty && session.notes.count < 30 {
            return session.notes
        }
        
        return session.type.rawValue.capitalized
    }
    
    private var totalSets: Int {
        session.exercises.reduce(0) {
            $0 + $1.sets.count
        }
    }
    
    private var durationText: String {
        guard let duration = session.duration else {
            return "--"
        }
        
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(
                format: "%d:%02d:%02d",
                hours,
                minutes,
                seconds
            )
        }
        
        return String(
            format: "%02d:%02d",
            minutes,
            seconds
        )
    }
    
    private func exerciseVolume(_ exercise: Exercise) -> Double {
        exercise.sets.reduce(0) { total, set in
            total + (set.weight * Double(set.reps))
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private func summarySection<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack {
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 1)
    }
}

struct SummaryStatCard: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 1)
    }
}

struct SummaryRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct PRSummaryRow: View {
    let record: PersonalRecord
    
    @EnvironmentObject var dataManager: DataManager
    
    var valueText: String {
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
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.exerciseName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(record.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(valueText)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 3)
    }
}
