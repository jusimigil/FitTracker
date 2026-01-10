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
                // MARK: - Header Area
                if !session.isCompleted {
                    // LIVE DASHBOARD
                    HStack {
                        DashboardItem(title: "Duration", value: elapsedTime, color: .primary)
                        Spacer()
                        DashboardItem(title: "Heart Rate", value: "\(Int(healthManager.currentHeartRate))", color: .red, icon: "heart.fill")
                        Spacer()
                        DashboardItem(title: "Calories", value: "\(Int(healthManager.activeCalories))", color: .orange)
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                } else {
                    // COMPLETED SUMMARY (Updated)
                    VStack(spacing: 15) {
                        HStack {
                            Text("Workout Completed")
                                .font(.headline)
                                .foregroundStyle(.green)
                            Spacer()
                            Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                        
                        // The New Stats Row
                        HStack {
                            // Duration
                            if let duration = session.duration {
                                VStack {
                                    Text("Duration")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(formatDuration(duration))
                                        .font(.title3).bold().monospacedDigit()
                                }
                                .frame(maxWidth: .infinity)
                            }
                            
                            // Avg Heart Rate
                            if let avgHR = session.averageHeartRate {
                                VStack {
                                    Text("Avg HR")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text("\(Int(avgHR)) bpm")
                                        .font(.title3).bold().foregroundStyle(.red)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            
                            // Volume (Optional extra)
                            VStack {
                                Text("Volume")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("\(Int(session.totalVolume)) lbs")
                                    .font(.title3).bold().foregroundStyle(.blue)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                }
                
                // MARK: - Exercise List
                List {
                    // Only show Add Button if NOT completed
                    if !session.isCompleted {
                        Button(action: { showExercisePicker = true }) {
                            Label("Add Exercise", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .padding(.vertical, 8)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    if session.exercises.isEmpty {
                        Text(session.isCompleted ? "No exercises recorded." : "No exercises yet. Tap above to add one!")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    
                    ForEach($dataManager.workouts[index].exercises) { $exercise in
                        NavigationLink(destination: ExerciseDetailView(exercise: $exercise, readOnly: session.isCompleted)) {
                            HStack {
                                Text(exercise.name).font(.headline)
                                Spacer()
                                Text("\(exercise.sets.count) sets").foregroundStyle(.secondary)
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
                            Button(action: { finishWorkout(index: index) }) {
                                Text("Finish Workout")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle(session.isCompleted ? "Summary" : "Session")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !dataManager.workouts[index].isCompleted {
                    healthManager.startMonitoring()
                }
            }
            .onReceive(timer) { _ in updateTimer() }
            
            // Add Exercise Alert
            .alert("Add Exercise", isPresented: $showExercisePicker) {
                TextField("Exercise Name (e.g. Bench Press)", text: $newExerciseName)
                Button("Add") {
                    if !newExerciseName.isEmpty {
                        let newEx = Exercise(name: newExerciseName)
                        dataManager.workouts[index].exercises.append(newEx)
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
    
    // UPDATED Finish Logic
    func finishWorkout(index: Int) {
        let endTime = Date()
        let startTime = healthManager.workoutStartDate ?? endTime.addingTimeInterval(-1) // Fallback
        
        // 1. Calculate Duration
        let duration = endTime.timeIntervalSince(startTime)
        dataManager.workouts[index].duration = duration
        
        // 2. Stop Monitoring
        healthManager.stopMonitoring()
        
        // 3. Fetch Average Heart Rate from HealthKit
        healthManager.fetchAverageHeartRate(start: startTime, end: endTime) { avgHeartRate in
            
            // Update Data on Main Thread
            if let hr = avgHeartRate {
                dataManager.workouts[index].averageHeartRate = hr
            }
            
            // 4. Mark Completed & Location
            dataManager.workouts[index].isCompleted = true
            
            if dataManager.workouts[index].latitude == nil, let loc = locationManager.userLocation {
                dataManager.workouts[index].latitude = loc.latitude
                dataManager.workouts[index].longitude = loc.longitude
            }
            
            dataManager.save()
            dismiss()
        }
    }
    
    func updateTimer() {
        guard let start = healthManager.workoutStartDate else { return }
        let diff = Date().timeIntervalSince(start)
        dataManager.workouts[workoutIndex!].duration = diff // Live update duration
        elapsedTime = formatDuration(diff)
    }
    
    // Helper to format 3605 seconds -> "01:00:05"
    func formatDuration(_ totalSeconds: TimeInterval) -> String {
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// Ensure DashboardItem exists at bottom
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
    }
}
