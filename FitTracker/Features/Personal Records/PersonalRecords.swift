import SwiftUI

struct PersonalRecordsView: View {
    
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationStack {
            Group {
                if dataManager.personalRecords.isEmpty {
                    emptyState
                } else {
                    recordsList
                }
            }
            .navigationTitle("Personal Records")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        EmptyStateView(
            icon: "trophy.fill",
            title: "No Personal Records Yet",
            message: "Your PRs will appear here when you beat a previous best. Keep training and your next milestone will be waiting for you."
        )
    }
    
    // MARK: - Records List
    
    private var recordsList: some View {
        List {
            ForEach(
                groupedRecords.keys.sorted(),
                id: \.self
            ) { exerciseName in
                
                Section {
                    let records =
                        groupedRecords[exerciseName] ?? []
                    
                    ForEach(records) { record in
                        recordRow(record)
                    }
                } header: {
                    Text(exerciseName)
                }
            }
        }
    }
    
    // MARK: - Group Records
    
    private var groupedRecords:
        [String: [PersonalRecord]] {
        
        Dictionary(
            grouping: dataManager.personalRecords,
            by: {
                $0.exerciseName
            }
        )
    }
    
    // MARK: - Record Row
    
    private func recordRow(
        _ record: PersonalRecord
    ) -> some View {
        
        HStack(spacing: 12) {
            
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
            
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                
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
                        time: .omitted
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Weight Formatting
    
    private func formattedWeight(
        _ kilograms: Double
    ) -> String {
        
        let displayedWeight =
            dataManager.displayedWeight(
                fromKilograms: kilograms
            )
        
        return String(
            format: "%.1f",
            displayedWeight
        )
    }
}

#Preview {
    PersonalRecordsView()
        .environmentObject(DataManager())
}
