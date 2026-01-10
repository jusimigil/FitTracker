import SwiftUI
import CoreLocation
import Combine

struct SessionDetailView: View {
    let workoutID: UUID
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject var healthManager = HealthManager.shared
    @StateObject private var locationManager = LocationManager()
    
    @State private var showExercisePicker = false
    @State private var newExerciseName = ""
    @State private var elapsedTime = "00:00"
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var workoutIndex: Int? {
        dataManager.workouts.firstIndex(where: { $0.id == workoutID })
    }

    var body: some View {
        if let index = workoutIndex {
            let session = dataManager.workouts[index]
            
            VStack(spacing: 0) {
                // MARK: - Header Dashboard
                if !session.isCompleted {
                    HStack {
                        DashboardItem(title: "Duration", value: elapsedTime, color: .primary)
                        Spacer()
                        DashboardItem(title: "Calories", value: "\(Int(healthManager.activeCalories))", color: .orange)
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                } else {
                    // MARK: - COMPLETED HEADER (With Calories)
                    VStack(spacing: 15) {
                        Text("Workout Completed").font(.headline).foregroundStyle(.green)
                        HStack(spacing: 40) {
                            if let duration = session.duration {
                                VStack {
                                    Text("Time").font(.caption).foregroundStyle(.secondary)
                                    Text(formatDuration(duration)).font(.title3).bold().monospacedDigit()
                                }
                            }
                            // Displays final saved calories
                            if let cals = session.activeCalories {
                                VStack {
                                    Text("Calories").font(.caption).foregroundStyle(.secondary)
                                    Text("\(Int(cals))").font(.title3).bold().foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGroupedBackground))
                }
                
                // MARK: - Exercise List
                List {
                    Section(header: Text("Notes")) {
                        TextField("Session notes...", text: $dataManager.workouts[index].notes, axis: .vertical)
                            .disabled(session.isCompleted)
                    }
                    
                    if !session.isCompleted {
                        Button(action: { showExercisePicker = true }) {
                            Label("Add Exercise", systemImage: "plus.circle.fill").foregroundColor(.blue)
                        }
                    }
                    
                    ForEach($dataManager.workouts[index].exercises) { $ex in
                        NavigationLink(destination: ExerciseDetailView(exercise: $ex, readOnly: session.isCompleted)) {
                            HStack {
                                Text(ex.name).font(.headline)
                                Spacer()
                                Text("\(ex.sets.count) sets").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        if !session.isCompleted {
                            dataManager.workouts[index].exercises.remove(atOffsets: offsets)
                            dataManager.save()
                        }
                    }
                    
                    if !session.isCompleted {
                        Section {
                            Button("Finish Workout", role: .destructive) { finishWorkout(index: index) }
                        }
                    }
                }
            }
            .navigationTitle(session.type.rawValue.capitalized)
            .onAppear {
                if !session.isCompleted {
                    healthManager.startMonitoring(startTime: session.date)
                    updateTimer()
                }
            }
            .onReceive(timer) { _ in updateTimer() }
            .alert("Add Exercise", isPresented: $showExercisePicker) {
                TextField("Name", text: $newExerciseName)
                Button("Add") {
                    if !newExerciseName.isEmpty {
                        dataManager.workouts[index].exercises.append(Exercise(name: newExerciseName))
                        dataManager.save()
                        newExerciseName = ""
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        } else {
            Text("Workout not found")
        }
    }
    
    // MARK: - Functions
    func finishWorkout(index: Int) {
        let end = Date()
        let start = dataManager.workouts[index].date
        
        // SAVE FINAL CALORIES
        let finalCalories = healthManager.activeCalories
        dataManager.workouts[index].activeCalories = finalCalories
        
        healthManager.fetchAverageHeartRate(start: start, end: end) { avg in
            if let hr = avg {
                dataManager.workouts[index].averageHeartRate = hr
            }
            
            dataManager.workouts[index].isCompleted = true
            dataManager.workouts[index].duration = end.timeIntervalSince(start)
            
            if let loc = locationManager.userLocation {
                dataManager.workouts[index].latitude = loc.latitude
                dataManager.workouts[index].longitude = loc.longitude
            }
            
            dataManager.save()
            healthManager.stopMonitoring()
            dismiss()
        }
    }
    
    func updateTimer() {
        guard let index = workoutIndex else { return }
        let startTime = dataManager.workouts[index].date
        let diff = Date().timeIntervalSince(startTime)
        elapsedTime = formatDuration(diff)
    }
    
    func formatDuration(_ totalSeconds: TimeInterval) -> String {
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - MISSING COMPONENT (This fixes the error)
struct DashboardItem: View {
    let title: String
    let value: String
    let color: Color
    var icon: String? = nil
    
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 2) {
                if let icon = icon { Image(systemName: icon).foregroundStyle(color) }
                Text(value).font(.title2).bold().foregroundStyle(color).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
    }
}
