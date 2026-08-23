import SwiftUI

struct ExercisePickerView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let onSelect: (ExerciseDefinition) -> Void
    
    @State private var searchText = ""
    
    private var filteredExercises: [ExerciseDefinition] {
        let exercises = ExerciseCatalog.all
        
        guard !searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            return exercises
        }
        
        return exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.primaryMuscle.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var groupedExercises: [(MuscleGroup, [ExerciseDefinition])] {
        
        MuscleGroup.allCases.compactMap { muscle in
            
            let exercises = filteredExercises.filter {
                $0.primaryMuscle == muscle
            }
            
            guard !exercises.isEmpty else {
                return nil
            }
            
            return (muscle, exercises)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(
                    groupedExercises,
                    id: \.0
                ) { muscle, exercises in
                    
                    Section {
                        ForEach(exercises) { exercise in
                            
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    
                                    Image(
                                        systemName: icon(
                                            for: muscle
                                        )
                                    )
                                    .foregroundStyle(.blue)
                                    .frame(width: 28)
                                    
                                    VStack(
                                        alignment: .leading,
                                        spacing: 3
                                    ) {
                                        Text(exercise.name)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        
                                        Text(muscle.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(
                                        systemName: "plus"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text(muscle.rawValue)
                    }
                }
                
                if groupedExercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises Found",
                        systemImage: "magnifyingglass",
                        description: Text(
                            "Try a different exercise or muscle."
                        )
                    )
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                prompt: "Search exercises"
            )
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func icon(
        for muscle: MuscleGroup
    ) -> String {
        switch muscle {
        case .chest:
            return "figure.strengthtraining.traditional"
        case .back:
            return "figure.climbing"
        case .legs:
            return "figure.run"
        case .shoulders:
            return "figure.arms.open"
        case .arms:
            return "figure.strengthtraining.functional"
        case .core:
            return "figure.core.training"
        }
    }
}
