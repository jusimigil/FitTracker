import SwiftUI
import Combine

struct ExerciseDetailView: View {
    @Binding var exercise: Exercise
    @EnvironmentObject var dataManager: DataManager
    
    // Changed RPE to Double for the slider (we cast to Int later)
    @State private var reps = 10
    @State private var weight = 45.0
    @State private var rpe = 8.0
    
    // Rest Timer State
    @State private var timeRemaining = 0
    @State private var timerActive = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // MARK: - Input Controls
                VStack(spacing: 20) {
                    
                    // --- Weight Slider ---
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Weight")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(Int(weight)) lbs")
                                .font(.title3)
                                .bold()
                                .foregroundColor(.blue)
                        }
                        
                        Slider(value: $weight, in: 0...600, step: 5) {
                            Text("Weight")
                        } minimumValueLabel: {
                            Text("0").font(.caption).foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("600").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // --- RPE Slider ---
                    VStack(alignment: .leading) {
                        HStack {
                            Text("RPE (Difficulty)")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(Int(rpe)) / 10")
                                .font(.title3)
                                .bold()
                                .foregroundColor(rpeColor(rpe: rpe))
                        }
                        
                        Slider(value: $rpe, in: 1...10, step: 1) {
                            Text("RPE")
                        } minimumValueLabel: {
                            Text("Easy").font(.caption).foregroundColor(.green)
                        } maximumValueLabel: {
                            Text("Max").font(.caption).foregroundColor(.red)
                        }
                    }
                    
                    Divider()
                    
                    // --- Reps Stepper (Kept as buttons for precision) ---
                    HStack {
                        Text("Reps")
                            .fontWeight(.medium)
                        Spacer()
                        Stepper("\(reps)", value: $reps, in: 1...100)
                            .fixedSize()
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // MARK: - Action Buttons
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
                        Text("\(timeRemaining)s")
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                            .frame(width: 90)
                            .padding()
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(12)
                            .onTapGesture { timerActive = false } // Tap to cancel
                    } else {
                        Button(action: { startRest(seconds: 90) }) {
                            Text("Rest 90s")
                                .font(.subheadline)
                                .frame(width: 90)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                }
                
                // MARK: - Set History
                VStack(alignment: .leading, spacing: 12) {
                    Text("History").font(.headline).padding(.leading, 5)
                    
                    ForEach(exercise.sets) { set in
                        HStack {
                            Text("\(set.reps) reps")
                                .bold()
                            Text("×")
                                .foregroundStyle(.secondary)
                            Text("\(Int(set.weight)) lbs")
                                .bold()
                            
                            Spacer()
                            
                            Text("RPE \(set.rpe)")
                                .font(.caption)
                                .padding(6)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
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
            if timerActive && timeRemaining > 0 {
                timeRemaining -= 1
            } else if timeRemaining == 0 {
                timerActive = false
            }
        }
    }
    
    // Helper to color code the RPE number
    func rpeColor(rpe: Double) -> Color {
        switch rpe {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return .primary
        }
    }
    
    func logSet() {
            // 1. Trigger Haptics
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // 2. Save Data
            let newSet = WorkoutSet(reps: reps, weight: weight, rpe: Int(rpe))
            exercise.sets.append(newSet)
            dataManager.save()
        }
    
    func startRest(seconds: Int) {
        timeRemaining = seconds
        timerActive = true
    }
}
