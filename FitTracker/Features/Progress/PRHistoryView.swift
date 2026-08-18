import SwiftUI

struct PRHistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    
    @State private var selectedExercise: String?
    
    private var exerciseNames: [String] {
        Array(
            Set(
                dataManager.personalRecords.map {
                    $0.exerciseName
                }
            )
        )
        .sorted()
    }
    
    private var selectedRecords: [PersonalRecord] {
        guard let selectedExercise else {
            return []
        }
        
        return dataManager.personalRecords
            .filter {
                $0.exerciseName == selectedExercise
            }
            .sorted {
                $0.date > $1.date
            }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Exercise Selector
            
            if !exerciseNames.isEmpty {
                Picker(
                    "Exercise",
                    selection: Binding(
                        get: {
                            selectedExercise ?? exerciseNames.first ?? ""
                        },
                        set: {
                            selectedExercise = $0
                        }
                    )
                ) {
                    ForEach(exerciseNames, id: \.self) { exercise in
                        Text(exercise)
                            .tag(exercise)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            // MARK: - Records
            
            if selectedRecords.isEmpty {
                ContentUnavailableView(
                    "No PR History",
                    systemImage: "trophy",
                    description: Text(
                        "Personal records for this exercise will appear here."
                    )
                )
            } else {
                List {
                    
                    // MARK: Summary
                    
                    Section {
                        summaryView
                    }
                    
                    // MARK: Timeline
                    
                    Section("History") {
                        ForEach(selectedRecords) { record in
                            recordRow(record)
                        }
                    }
                }
            }
        }
        .navigationTitle("PR History")
        .onAppear {
            if selectedExercise == nil {
                selectedExercise = exerciseNames.first
            }
        }
    }
    
    // MARK: - Summary
    
    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            if let bestWeight = selectedRecords
                .filter({ $0.type == .heaviestWeight })
                .max(by: { $0.weight < $1.weight }) {
                
                PRSummaryMetric(
                    title: "Heaviest",
                    value: formattedWeight(bestWeight.weight),
                    icon: "scalemass.fill"
                )
            }
            
            if let bestReps = selectedRecords
                .filter({ $0.type == .repRecord })
                .max(by: { $0.reps < $1.reps }) {
                
                PRSummaryMetric(
                    title: "Best Reps",
                    value: "\(bestReps.reps)",
                    icon: "repeat"
                )
            }
            
            if let best1RM = selectedRecords
                .filter({ $0.type == .estimatedOneRepMax })
                .max(by: {
                    $0.estimatedOneRepMax <
                    $1.estimatedOneRepMax
                }) {
                
                PRSummaryMetric(
                    title: "Best Estimated 1RM",
                    value: formattedWeight(
                        best1RM.estimatedOneRepMax
                    ),
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Record Row
    
    private func recordRow(
        _ record: PersonalRecord
    ) -> some View {
        HStack(spacing: 12) {
            
            Image(systemName: icon(for: record.type))
                .foregroundStyle(.orange)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.type.rawValue)
                    .font(.headline)
                
                Text(
                    "\(formattedWeight(record.weight)) × \(record.reps)"
                )
                .font(.subheadline)
                
                Text(
                    "Estimated 1RM: \(formattedWeight(record.estimatedOneRepMax))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                
                Text(
                    record.date.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helpers
    
    private func formattedWeight(
        _ kilograms: Double
    ) -> String {
        let displayedWeight =
            dataManager.displayedWeight(
                fromKilograms: kilograms
            )
        
        return String(
            format: "%.1f %@",
            displayedWeight,
            dataManager.weightUnit.rawValue
        )
    }
    
    private func icon(
        for type: PRType
    ) -> String {
        switch type {
        case .heaviestWeight:
            return "scalemass.fill"
            
        case .repRecord:
            return "repeat"
            
        case .estimatedOneRepMax:
            return "chart.line.uptrend.xyaxis"
        }
    }
}

struct PRSummaryMetric: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 28)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
        }
    }
}
