import SwiftUI
import UserNotifications
import Combine

struct ExerciseDetailView: View {
    @Binding var exercise: Exercise
    var readOnly: Bool = false
    
    @EnvironmentObject var dataManager: DataManager
    
    @State private var reps = 10
    @State private var weight = 45.0
    @State private var rpe = 8.0
    
    // Timer State
    @State private var timeRemaining = 0
    @State private var totalRestTime: Double = 90.0
    @State private var timerActive = false
    
    // We use a simpler timer approach here
    @State private var internalTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
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
                        Divider()
                                                HStack {
                                                    Text("Muscle").fontWeight(.medium); Spacer()
                                                    Picker("Muscle", selection: $exercise.muscleGroup) {
                                                        ForEach(MuscleGroup.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                                    }.pickerStyle(.menu)
                                                }
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
                        
                        // Replace the "if timerActive" ZStack block with this:

                        if timerActive {
                            ZStack(alignment: .leading) {
                                // 1. Background Container
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.1))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange, lineWidth: 2))
                                
                                // 2. The Draining Bar (Animated)
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.orange)
                                        .padding(4)
                                        .frame(width: max(0, (geo.size.width - 8) * (Double(timeRemaining) / totalRestTime)))
                                        // We keep the animation ONLY on the bar's width
                                        .animation(.linear(duration: 1.0), value: timeRemaining)
                                }
                                
                                // 3. Text Overlay (Non-Animated / Static)
                                Text("\(timeRemaining)s")
                                    .font(.headline)
                                    .monospacedDigit()
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    // This prevents the "dizzying" fade/blur effect on the numbers
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
                    Text("Sets Completed").font(.headline).padding(.leading, 5)
                    ForEach(exercise.sets) { set in
                        HStack {
                            Text("\(set.reps) reps").bold()
                            Text("×").foregroundStyle(.secondary)
                            Text("\(Int(set.weight)) lbs").bold()
                            Spacer()
                            Text("RPE \(set.rpe)").font(.caption).padding(6).background(Color(.systemGray6)).cornerRadius(6)
                        }
                        .padding().background(Color(.systemBackground)).cornerRadius(10).shadow(radius: 1)
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
    
    func startRest(seconds: Int) {
        // Reset state
        totalRestTime = Double(seconds)
        timeRemaining = seconds
        timerActive = true
        
        // 1. Start the visual countdown
        internalTimer?.invalidate() // Clear any existing timer
        internalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                // withAnimation makes the bar move smoothly
                withAnimation(.linear(duration: 1.0)) {
                    timeRemaining -= 1
                }
            } else {
                cancelTimer()
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
        
        // 2. Schedule Notification (Already working)
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
        let newSet = WorkoutSet(reps: reps, weight: weight, rpe: Int(rpe))
        exercise.sets.append(newSet)
        dataManager.save()
    }
    
    func rpeColor(rpe: Double) -> Color {
        switch rpe {
        case 1...4: return .green; case 5...7: return .orange; default: return .red
        }
    }
}
