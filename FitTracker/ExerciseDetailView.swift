import SwiftUI
import UserNotifications
import Combine

struct ExerciseDetailView: View {
    @Binding var exercise: Exercise
    var readOnly: Bool = false
    
    @EnvironmentObject var dataManager: DataManager
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
        // QoL FIX: ScrollViewReader allows us to scroll to the bottom automatically
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 25) {
                    
                    // MARK: - 1. MACHINE LEARNING INSIGHT
                    if !readOnly {
                        HStack(alignment: .top) {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(.purple)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Smart Recommendation")
                                    .font(.caption).bold().foregroundStyle(.purple)
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
                        }
                        .padding().background(Color(.secondarySystemBackground)).cornerRadius(15)
                        
                        // MARK: - Action Buttons
                        HStack(spacing: 15) {
                            Button(action: {
                                let newID = logSet()
                                // QoL FIX: Scroll to the new set
                                withAnimation { proxy.scrollTo(newID, anchor: .bottom) }
                            }) {
                                Text("Log Set")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(weight == 0 ? Color.gray : Color.blue) // Visual feedback
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .disabled(weight == 0) // QoL FIX: Prevent ghost sets
                            
                            // Rest Timer
                            if timerActive {
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.orange.opacity(0.1))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange, lineWidth: 2))
                                    GeometryReader { geo in
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.orange)
                                            .padding(4)
                                            .frame(width: max(0, (geo.size.width - 8) * (Double(timeRemaining) / totalRestTime)))
                                            .animation(.linear(duration: 1.0), value: timeRemaining)
                                    }
                                    Text("\(timeRemaining)s")
                                        .font(.headline).monospacedDigit().foregroundColor(.primary)
                                        .frame(maxWidth: .infinity)
                                        .animation(nil, value: timeRemaining)
                                }
                                .frame(height: 50).frame(maxWidth: .infinity)
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
                                if set.rpe > 0 {
                                    Text("RPE \(set.rpe)").font(.caption).padding(6).background(Color(.systemGray6)).cornerRadius(6)
                                }
                            }
                            .padding().background(Color(.systemBackground)).cornerRadius(10).shadow(radius: 1)
                            .id(set.id) // QoL FIX: ID needed for scrolling
                        }
                        .onDelete { indices in
                            exercise.sets.remove(atOffsets: indices)
                            dataManager.save()
                        }
                    }
                    // Spacer at the bottom to allow scrolling past the last element
                    Spacer().frame(height: 50).id("bottom")
                }
                .padding()
            }
        }
        .navigationTitle(exercise.name)
        // MARK: - SMART AUTOFILL LOGIC
        .onAppear {
            // 1. Same Session: Use the previous set's values
            if let lastSet = exercise.sets.last {
                reps = lastSet.reps
                weight = lastSet.weight
                rpe = Double(lastSet.rpe)
            }
            // 2. History: Find the last time this exercise was performed in a COMPLETED workout
            else {
                let history = dataManager.workouts
                    .filter { $0.isCompleted }
                    .sorted(by: { $0.date > $1.date })
                
                if let lastSession = history.first(where: { $0.exercises.contains(where: { $0.name == exercise.name }) }),
                   let lastExercise = lastSession.exercises.first(where: { $0.name == exercise.name }),
                   let lastSet = lastExercise.sets.last {
                    
                    reps = lastSet.reps
                    weight = lastSet.weight
                    rpe = Double(lastSet.rpe > 0 ? lastSet.rpe : 8)
                }
            }
        }
        .onDisappear { internalTimer?.invalidate() }
    }
    
    // MARK: - Logic Functions
    func startRest(seconds: Int) {
        totalRestTime = Double(seconds)
        timeRemaining = seconds
        timerActive = true
        internalTimer?.invalidate()
        internalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                withAnimation(.linear(duration: 1.0)) { timeRemaining -= 1 }
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
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "RestTimer", content: content, trigger: trigger))
    }
    
    func cancelTimer() {
        timerActive = false
        internalTimer?.invalidate()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["RestTimer"])
    }
    
    func logSet() -> UUID {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Create the set with a new ID
        let newSet = WorkoutSet(reps: reps, weight: weight, rpe: Int(rpe))
        exercise.sets.append(newSet)
        dataManager.save()
        return newSet.id
    }
    
    func rpeColor(rpe: Double) -> Color {
        switch rpe {
        case 1...4: return .green; case 5...7: return .orange; default: return .red
        }
    }
}
