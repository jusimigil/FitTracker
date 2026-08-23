import SwiftUI
import CoreLocation
import UserNotifications
import Combine

// MARK: - 1. ISOLATED HEADER

struct SessionHeaderView: View {
    
    let session: WorkoutSession
    let hasStarted: Bool
    @ObservedObject var healthManager = HealthManager.shared
    
    var body: some View {
        VStack(spacing: 15) {
            
            if !session.isCompleted && hasStarted {
                
                // TimelineView drives a reliable visual refresh
                // without storing elapsed time in @State.
                TimelineView(
                    .periodic(
                        from: .now,
                        by: 1.0
                    )
                ) { context in
                    
                    HStack {
                        Spacer()
                        
                        VStack {
                            Text("Duration")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(
                                formatDuration(
                                    max(
                                        0,
                                        context.date.timeIntervalSince(
                                            session.date
                                        )
                                    )
                                )
                            )
                            .font(.title2)
                            .bold()
                            .monospacedDigit()
                        }
                        
                        Spacer()
                    }
                }
                
            } else if !session.isCompleted {
                VStack(spacing: 6) {
                    Image(systemName: "play.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    Text("Ready to Start")
                        .font(.headline)
                    
                    Text("Log your first set to begin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {

                Text("Workout Completed")
                    .font(.headline)
                    .foregroundStyle(.green)
                
                if let fileName = session.imageID,
                   let uiImage = ImageManager.shared.loadImage(
                    fileName: fileName
                   ) {
                    
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 12
                            )
                        )
                        .padding(.horizontal)
                }
                
                HStack {
                    if let duration = session.duration {
                        
                        VStack {
                            Text("Total Time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(
                                formatDuration(duration)
                            )
                            .font(.title3)
                            .bold()
                            .monospacedDigit()
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            Color(.systemGroupedBackground)
        )
    }
    
    
    // MARK: - Duration Formatting
    
    private func formatDuration(
        _ totalSeconds: TimeInterval
    ) -> String {
        
        let seconds = max(
            0,
            Int(totalSeconds)
        )
        
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return String(
                format: "%d:%02d:%02d",
                hours,
                minutes,
                remainingSeconds
            )
        }
        
        return String(
            format: "%02d:%02d",
            minutes,
            remainingSeconds
        )
    }
}

// MARK: - 2. ISOLATED NOTES
struct NotesInputView: View {
    @Binding var text: String
    var isDisabled: Bool
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Section(header: Text("Notes")) {
            TextField("Session notes...", text: $text, axis: .vertical)
                .disabled(isDisabled)
                .focused($isFocused)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { isFocused = false }
                    }
                }
        }
    }
}

// MARK: - 3. MAIN SESSION VIEW
struct SessionDetailView: View {
    let workoutID: UUID
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject var healthManager = HealthManager.shared
    @StateObject private var locationManager = LocationManager()
    @ObservedObject var recompManager = RecompManager.shared
    
    @State private var showExercisePicker = false
    @State private var showFinishAlert = false
    
    @State private var showCamera = false
    @State private var showSongSearch = false
    @State private var capturedImage: UIImage?
    
    @State private var showWorkoutSummary = false
    @State private var summarySession: WorkoutSession?
    @State private var summaryPRs: [PersonalRecord] = []
    
    let inactivityThreshold: TimeInterval = 300 // 5 Minutes
    
    var workoutIndex: Int? {
        dataManager.workouts.firstIndex(where: { $0.id == workoutID })
    }
    
    var hasStartedWorkout: Bool {
        guard let index = workoutIndex else {
            return false
        }
        
        return dataManager.workouts[index].exercises.contains {
            !$0.sets.isEmpty
        }
    }
    
    var priorityMuscle: MuscleGroup? {
        let weeklySets = recompManager.weeklySetsByMuscle(
            dataManager: dataManager
        )

        let target = recompManager.weeklySetTarget

        let selectedMuscle = MuscleGroup.allCases.min { lhs, rhs in
            let lhsSets = weeklySets[lhs] ?? 0
            let rhsSets = weeklySets[rhs] ?? 0

            let lhsDeficit = max(target - lhsSets, 0)
            let rhsDeficit = max(target - rhsSets, 0)

            if lhsDeficit != rhsDeficit {
                return lhsDeficit > rhsDeficit
            }

            // Tie-breaker: prioritize lower-body training.
            if lhs == .legs && rhs != .legs {
                return true
            }

            if rhs == .legs && lhs != .legs {
                return false
            }

            return lhs.rawValue < rhs.rawValue
        }

        guard let selectedMuscle = selectedMuscle else {
            return nil
        }

        guard (weeklySets[selectedMuscle] ?? 0) < target else {
            return nil
        }

        return selectedMuscle
    }
    
    // Display Logic Helper
    func displayTitle(for session: WorkoutSession) -> String {
        if let title = session.workoutTitle, !title.isEmpty { return title }
        if !session.notes.isEmpty && session.notes.count < 30 { return session.notes }
        return session.type.rawValue.capitalized
    }

    var body: some View {
        if let index = workoutIndex {
            let session = dataManager.workouts[index]
            
            VStack(spacing: 0) {
                SessionHeaderView(
                    session: session,
                    hasStarted: hasStartedWorkout
                )
                
                List {
                    // MARK: MUSIC JOURNAL
                    Section {
                        if let songTitle = session.workoutSongTitle {
                            HStack(spacing: 15) {
                                if let urlStr = session.workoutSongCoverURL, let url = URL(string: urlStr) {
                                    AsyncImage(url: url) { img in img.resizable() } placeholder: { Color.purple.opacity(0.2) }
                                        .scaledToFill().frame(width: 50, height: 50).cornerRadius(8)
                                } else {
                                    Image(systemName: "music.note").frame(width: 50, height: 50).background(Color.gray.opacity(0.1)).cornerRadius(8)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("Workout Anthem").font(.caption).foregroundStyle(.secondary)
                                    Text(songTitle).font(.headline).lineLimit(1)
                                    Text(session.workoutSongArtist ?? "").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(action: { showSongSearch = true }) {
                                    Image(systemName: "pencil.circle").foregroundStyle(.blue)
                                }
                            }
                        } else {
                            Button(action: { showSongSearch = true }) {
                                Label("Add Workout Anthem", systemImage: "music.note.list").foregroundStyle(.purple)
                            }
                        }
                    } header: { Text("Music Journal") }
                    
                    // MARK: NOTES
                    NotesInputView(text: $dataManager.workouts[index].notes, isDisabled: session.isCompleted)
                    
                    // MARK: EXERCISES
                    if !session.isCompleted {
                        Button(action: { showExercisePicker = true }) {
                            Label("Add Exercise", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .padding(.vertical, 4)
                        }
                    }
                    
                    ForEach($dataManager.workouts[index].exercises) { $ex in
                        NavigationLink(
                            destination: ExerciseDetailView(
                                exercise: $ex,
                                readOnly: session.isCompleted,
                                workoutID: workoutID
                            )
                        ) {
                            HStack(spacing: 8) {
                                
                                if ex.resolvedMuscleGroup == priorityMuscle {
                                    Image(systemName: "target")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                                
                                Text(ex.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                
                                Spacer()
                                
                                Text("\(ex.sets.count) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }                    .onDelete { offsets in
                        if !session.isCompleted {
                            dataManager.workouts[index].exercises.remove(atOffsets: offsets)
                            dataManager.save()
                        }
                    }
                    
                    if !session.isCompleted && hasStartedWorkout{
                        Section {
                            Button("Finish Workout", role: .destructive) {
                                showFinishAlert = true
                            }
                        }
                    }
                }
            }
            // NEW: Use the smart display title
            .navigationTitle(displayTitle(for: session))
            .toolbar {
                if !session.isCompleted {
                    ToolbarItem(placement: .bottomBar) {
                        Button(action: { showCamera = true }) { Label("Add Photo", systemImage: "camera.fill") }
                    }
                }
            }
            .onAppear {
                if !session.isCompleted && hasStartedWorkout {
                    healthManager.startMonitoring(
                        startTime: session.date
                    )
                    requestNotificationPermissions()
                    resetInactivityTimer()
                }
            }
            .onChange(of: dataManager.workouts) { _, _ in
                guard !session.isCompleted else {
                    return
                }
                
                if hasStartedWorkout {
                    healthManager.startMonitoring(
                        startTime: session.date
                    )
                    
                    requestNotificationPermissions()
                    resetInactivityTimer()
                }
            } .alert("Finish Workout?", isPresented: $showFinishAlert) {
                Button("Finish", role: .destructive) { finishWorkout(index: index) }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Great job! Ready to log this session?")
            }
            .sheet(isPresented: $showCamera) { ImagePicker(image: $capturedImage) }
            .sheet(isPresented: $showSongSearch) {
                SongSelectionView { selectedSong in
                    dataManager.workouts[index].workoutSongTitle = selectedSong.trackName
                    dataManager.workouts[index].workoutSongArtist = selectedSong.artistName
                    dataManager.workouts[index].workoutSongCoverURL = selectedSong.artworkUrl100
                    dataManager.save()
                }
            }
            .sheet(
                isPresented: $showWorkoutSummary,
                onDismiss: {
                    
                    dismiss()
                }
            ) {
                if let summarySession {
                    WorkoutSummaryView(
                        session: summarySession,
                        personalRecords: summaryPRs
                    )
                    .environmentObject(dataManager)
                }
            }            .onChange(of: capturedImage) { _, newImage in
                if let img = newImage, let fileName = ImageManager.shared.saveImage(img) {
                    if let oldFile = dataManager.workouts[index].imageID { ImageManager.shared.deleteImage(fileName: oldFile) }
                    dataManager.workouts[index].imageID = fileName
                    dataManager.save()
                }
            } .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { definition in
                    
                    dataManager.workouts[index].exercises.append(
                        Exercise(
                            name: definition.name,
                            muscleGroup: definition.primaryMuscle
                        )
                    )
                    
                    dataManager.save()
                }
            }
        } else {
            Text("Workout not found")
        }
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    func resetInactivityTimer() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["inactivity_nudge"])
        
        let content = UNMutableNotificationContent()
        content.title = "Still working out?"
        content.body = "You haven't logged a set in 5 minutes. Keep the momentum going! 💪"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: inactivityThreshold, repeats: false)
        let request = UNNotificationRequest(identifier: "inactivity_nudge", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling nudge: \(error)")
            }
        }
    }
    
    func cancelInactivityNudge() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["inactivity_nudge"])
    }
    
    func finishWorkout(index: Int) {
        cancelInactivityNudge()
        
        let end = Date()
        let start = dataManager.workouts[index].date
        let finishedWorkoutID = dataManager.workouts[index].id
        
        healthManager.fetchAverageHeartRate(start: start, end: end) { avg in
            
            // Update workout information.
            if let hr = avg {
                dataManager.workouts[index].averageHeartRate = hr
            }
            
            dataManager.workouts[index].isCompleted = true
            dataManager.workouts[index].duration =
                end.timeIntervalSince(start)
            
            dataManager.workouts[index].activeCalories =
                healthManager.activeCalories
            
            if let loc = locationManager.userLocation {
                dataManager.workouts[index].latitude = loc.latitude
                dataManager.workouts[index].longitude = loc.longitude
            }
            
            // Capture the completed workout before presenting
            // the summary.
            let completedSession = dataManager.workouts[index]
            
            // Get only the PRs earned during THIS workout.
            let earnedPRs = dataManager.personalRecords.filter {
                $0.workoutID == finishedWorkoutID
            }
            
            // Save everything before showing the summary.
            dataManager.save()
            healthManager.stopMonitoring()
            
            LiveActivityManager.shared.endWorkout()
            
            dismiss()

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            DispatchQueue.main.async {
                summarySession = completedSession
                summaryPRs = earnedPRs
                showWorkoutSummary = true
            }
        }
    }}
