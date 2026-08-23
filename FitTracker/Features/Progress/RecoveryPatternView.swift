import SwiftUI

struct RecoveryPatternView: View {
    @EnvironmentObject var dataManager: DataManager
    
    private var patternMessage: String {
        let calendar = Calendar.current
        
        // Only use recent recovery data.
        let cutoff = calendar.date(
            byAdding: .day,
            value: -30,
            to: Date()
        ) ?? Date()
        
        let recentRecovery = dataManager.recoveryHistory
            .filter { $0.date >= cutoff }
        
        guard recentRecovery.count >= 6 else {
            return "Keep logging recovery to reveal your personal patterns."
        }
        
        var trainingDayScores: [Double] = []
        var restDayScores: [Double] = []
        
        for entry in recentRecovery {
            let trainedThatDay = dataManager.completedWorkouts.contains { workout in
                calendar.isDate(
                    workout.date,
                    inSameDayAs: entry.date
                )
            }
            
            if trainedThatDay {
                trainingDayScores.append(entry.score)
            } else {
                restDayScores.append(entry.score)
            }
        }
        
        guard trainingDayScores.count >= 3,
              restDayScores.count >= 3 else {
            return "Keep logging recovery and workouts to reveal your personal patterns."
        }
        
        let trainingAverage =
            trainingDayScores.reduce(0, +)
            / Double(trainingDayScores.count)
        
        let restAverage =
            restDayScores.reduce(0, +)
            / Double(restDayScores.count)
        
        let difference = trainingAverage - restAverage
        
        if difference <= -0.75 {
            return "Your recovery scores tend to be lower on training days than rest days."
        }
        
        if difference >= 0.75 {
            return "Your recovery scores tend to be higher on training days than rest days."
        }
        
        return "Your recovery looks fairly consistent between training and rest days."
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .foregroundStyle(.pink)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Recovery Pattern")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(patternMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
            
            Spacer()
        }
        .padding()
        .background(
            Color(.secondarySystemBackground)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
    }
}
