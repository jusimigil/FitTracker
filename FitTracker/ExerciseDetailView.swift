import SwiftUI
import UserNotifications
import Combine

struct ExerciseDetailView: View {
    @Binding var exercise: Exercise
    var readOnly: Bool = false
    
    @EnvironmentObject var dataManager: DataManager
    
    // 1. ADD: The Manager for ML Insights
    @ObservedObject var recompManager = RecompManager.shared
    
    @State private var reps = 10
    @State private var weight = 45.0
    @State private var rpe = 8.0
    
    // Timer State
    @State private var timeRemaining = 0
    @State private var totalRestTime: Double = 90.0
    @State private var timerActive = false
    @State private var internalTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                
                // MARK: - 1. NEW: MACHINE LEARNING INSIGHT
                // I added this at the top so you see it before you log
                if !readOnly {
                    HStack(alignment: .top) {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(.purple)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Smart Recommendation")
                                .font(.caption).bold().foregroundStyle(.purple)
                            
                            // This pulls the prediction from your manager
                            Text(recompManager.suggestProgressiveOverload(for: exercise.name, dataManager: dataManager))
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                }
                
                if !readOnly {
                    HStack(spacing: 15) {
                        // Stat A: Heaviest Lift Ever
                        VStack(alignment: .leading) {
                            Text("Best Lift").font(.caption).foregroundStyle(.secondary)
                            Text("\(Int(getPersonalBest(exerciseName: exercise.name))) lbs")
                                .font(.title2).bold().foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        // Stat B: Estimated 1RM (Based on current input)
                        VStack(alignment: .leading) {
                            Text("Est. 1 Rep Max").font(.caption).foregroundStyle(.secondary)
                            // Live calculation based on slider
                            let estMax = weight * (1 + (Double(reps) / 30.0))
                            Text("\(Int(estMax)) lbs")
                                .font(.title2).bold().foregroundStyle(.blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    // We don't want padding here because the parent VStack has it,
                    // but check your layout spacing.
                }
                
                // MARK: - Input Controls
                if !readOnly {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            HStack { Text("Weight").fontWeight(.medium); Spacer(); Text("\(Int(weight)) lbs").bold().foregroundStyle(.blue) }
                            Slider(value: $weight, in: 0...600, step: 5)
                        }
                        Divider()
                        VStack(alignment: .leading) {
                            HStack { Text("RPE").fontWeight(.medium); Spacer(); Text("\(Int(rpe)) / 10").bold().foregroundStyle(rpeColor(rpe: rpe)) }
                            Slider(value: $rpe, in: 1...10, step: 1)
                        }
                        Divider()
                        HStack { Text("Reps").fontWeight(.medium); Spacer(); Stepper("\(reps)", value: $reps, in: 1...100).fixedSize() }
                        
                        // REMOVED: Muscle Picker (As you requested)
                    }
                    .padding().background(Color(.secondarySystemBackground)).cornerRadius(15)
                    
                    // MARK: - Action Buttons
                    HStack(spacing: 15) {
                        Button(action: logSet) {
                            Text("Log Set")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        // MARK: - Rest Timer Logic
                        if timerActive {
                            ZStack(alignment: .leading) {
                                // 1. Background
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.1))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange, lineWidth: 2))
                                
                                // 2. Animated Bar
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.orange)
                                        .padding(4)
                                        .frame(width: max(0, (geo.size.width - 8) * (Double(timeRemaining) / totalRestTime)))
                                        .animation(.linear(duration: 1.0), value: timeRemaining)
                                }
                                
                                // 3. Text
                                Text("\(timeRemaining)s")
                                    .font(.headline)
                                    .monospacedDigit()
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .animation(nil, value: timeRemaining)
                            }
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .onTapGesture { cancelTimer() }
                        } else {
                            Button(action: { startRest(seconds: 90) }) {
                                Text("Rest 90s")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.primary)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // MARK: - History List
                VStack(alignment: .leading, spacing: 12) {
                    if !exercise.sets.isEmpty {
                        Text("Sets Completed").font(.headline).padding(.leading, 5)
                    }
                    
                    ForEach(exercise.sets) { set in
                        HStack {
                            Text("\(set.reps) reps").bold()
                            Text("×").foregroundStyle(.secondary)
                            Text("\(Int(set.weight)) lbs").bold()
                            Spacer()
                            // Handle optional RPE safely
                            // FIX: Just check if it's greater than 0
                            if set.rpe > 0 {
                                Text("RPE \(set.rpe)")
                                    .font(.caption)
                                    .padding(6)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(6)
                            }
                        }
                        .padding().background(Color(.systemBackground)).cornerRadius(10).shadow(radius: 1)
                    }
                    // Add Delete capability
                    .onDelete { indices in
                        exercise.sets.remove(atOffsets: indices)
                        dataManager.save()
                    }
                }
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .onDisappear {
            internalTimer?.invalidate()
        }
    }
    
    // MARK: - Logic Functions
    func startRest(seconds: Int) {
        totalRestTime = Double(seconds)
        timeRemaining = seconds
        timerActive = true
        
        internalTimer?.invalidate()
        internalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                withAnimation(.linear(duration: 1.0)) {
                    timeRemaining -= 1
                }
            } else {
                cancelTimer()
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Rest Finished!"
        content.body = "Time for the next set."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: "RestTimer", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelTimer() {
        timerActive = false
        internalTimer?.invalidate()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["RestTimer"])
    }
    
    func logSet() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Ensure your WorkoutSet struct supports RPE!
        // If your WorkoutSet struct doesn't have RPE, remove the `rpe: Int(rpe)` part.
        let newSet = WorkoutSet(reps: reps, weight: weight, rpe: Int(rpe))
        
        exercise.sets.append(newSet)
        dataManager.save()
    }
    
    func rpeColor(rpe: Double) -> Color {
        switch rpe {
        case 1...4: return .green; case 5...7: return .orange; default: return .red
        }
    }
    
    // ... at the bottom of the struct ...

    func getPersonalBest(exerciseName: String) -> Double {
        // 1. Flatten all workouts into a list of sets for this exercise
        let allSets = dataManager.workouts
            .filter { $0.isCompleted }
            .flatMap { $0.exercises }
            .filter { $0.name == exerciseName }
            .flatMap { $0.sets }
        
        // 2. Find max weight
        return allSets.map { $0.weight }.max() ?? 0.0
    }
}


