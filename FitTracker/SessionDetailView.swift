import SwiftUI
import Combine

struct SessionDetailView: View {
    let workoutID: UUID
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject var healthManager = HealthManager.shared
    
    @State private var showExercisePicker = false
    @State private var elapsedTime = "00:00"
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var workoutIndex: Int? {
        dataManager.workouts.firstIndex(where: { $0.id == workoutID })
    }

    var body: some View {
        if let index = workoutIndex {
            VStack(spacing: 0) {
                // MARK: - Live Dashboard
                HStack {
                    // Duration
                    VStack {
                        Text("Duration")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(elapsedTime)
                            .font(.title2).bold().monospacedDigit()
                    }
                    Spacer()
                    // Heart Rate
                    VStack {
                        Text("Heart Rate")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill").foregroundStyle(.red)
                            Text("\(Int(healthManager.currentHeartRate))")
                                .font(.title2).bold()
                        }
                    }
                    Spacer()
                    // Calories
                    VStack {
                        Text("Calories")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("\(Int(healthManager.activeCalories))")
                            .font(.title2).bold().foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                // MARK: - Exercise List
                List {
                    ForEach($dataManager.workouts[index].exercises) { $exercise in
                        NavigationLink(destination: ExerciseDetailView(exercise: $exercise)) {
                            HStack {
                                Text(exercise.name)
                                Spacer()
                                Text("\(exercise.sets.count) sets")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        dataManager.workouts[index].exercises.remove(atOffsets: offsets)
                        dataManager.save()
                    }
                    
                    Button("Finish Workout") {
                        healthManager.stopMonitoring()
                        dismiss()
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // Add Button
                Button("Add Exercise") { showExercisePicker = true }
                    .padding()
            }
            .navigationTitle("Session")
            .onAppear { healthManager.startMonitoring() }
            .onReceive(timer) { _ in updateTimer() }
            .sheet(isPresented: $showExercisePicker) {
                List(["Squats", "Bench Press", "Deadlift", "Overhead Press", "Pull Ups", "Dumbbell Rows"], id: \.self) { name in
                    Button(name) {
                        let newEx = Exercise(name: name)
                        dataManager.workouts[index].exercises.append(newEx)
                        dataManager.save()
                        showExercisePicker = false
                    }
                }
            }
        } else {
            Text("Workout not found")
        }
    }
    
    func updateTimer() {
        guard let start = healthManager.workoutStartDate else { return }
        let diff = Date().timeIntervalSince(start)
        let minutes = Int(diff) / 60
        let seconds = Int(diff) % 60
        elapsedTime = String(format: "%02d:%02d", minutes, seconds)
    }
}
