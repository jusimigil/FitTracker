import SwiftUI
import Combine

struct ExerciseDetailView: View {
    @Binding var exercise: Exercise
    var readOnly: Bool = false // <--- New Flag
    
    @EnvironmentObject var dataManager: DataManager
    
    @State private var reps = 10
    @State private var weight = 45.0
    @State private var rpe = 8.0
    
    @State private var timeRemaining = 0
    @State private var timerActive = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                
                // MARK: - Input Controls (Hidden if Read-Only)
                if !readOnly {
                    VStack(spacing: 20) {
                        // Weight Slider
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Weight").fontWeight(.medium)
                                Spacer()
                                Text("\(Int(weight)) lbs").font(.title3).bold().foregroundColor(.blue)
                            }
                            Slider(value: $weight, in: 0...600, step: 5)
                        }
                        Divider()
                        // RPE Slider
                        VStack(alignment: .leading) {
                            HStack {
                                Text("RPE").fontWeight(.medium)
                                Spacer()
                                Text("\(Int(rpe)) / 10").font(.title3).bold().foregroundColor(rpeColor(rpe: rpe))
                            }
                            Slider(value: $rpe, in: 1...10, step: 1)
                        }
                        Divider()
                        // Reps
                        HStack {
                            Text("Reps").fontWeight(.medium)
                            Spacer()
                            Stepper("\(reps)", value: $reps, in: 1...100).fixedSize()
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(15)
                    
                    // Action Buttons
                    HStack(spacing: 15) {
                        Button(action: logSet) {
                            Text("Log Set")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        if timerActive {
                            Text("\(timeRemaining)s").font(.headline).monospacedDigit().foregroundStyle(.orange).frame(width: 90).padding().background(Color.orange.opacity(0.15)).cornerRadius(12).onTapGesture { timerActive = false }
                        } else {
                            Button(action: { startRest(seconds: 90) }) {
                                Text("Rest 90s").font(.subheadline).frame(width: 90).padding().background(Color(.systemGray5)).foregroundColor(.primary).cornerRadius(12)
                            }
                        }
                    }
                }
                
                // MARK: - History (Always Visible)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sets Completed").font(.headline).padding(.leading, 5)
                    
                    if exercise.sets.isEmpty {
                        Text("No sets recorded").foregroundStyle(.secondary).padding()
                    }
                    
                    ForEach(exercise.sets) { set in
                        HStack {
                            Text("\(set.reps) reps").bold()
                            Text("×").foregroundStyle(.secondary)
                            Text("\(Int(set.weight)) lbs").bold()
                            Spacer()
                            Text("RPE \(set.rpe)").font(.caption).padding(6).background(Color(.systemGray6)).cornerRadius(6)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .onReceive(timer) { _ in
            if timerActive && timeRemaining > 0 { timeRemaining -= 1 }
            else if timeRemaining == 0 { timerActive = false }
        }
    }
    
    func rpeColor(rpe: Double) -> Color {
        switch rpe {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return .primary
        }
    }
    
    func logSet() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        let newSet = WorkoutSet(reps: reps, weight: weight, rpe: Int(rpe))
        exercise.sets.append(newSet)
        dataManager.save()
    }
    
    func startRest(seconds: Int) {
        timeRemaining = seconds
        timerActive = true
    }
}
