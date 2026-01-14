import SwiftUI
import CoreLocation
import UserNotifications // Added for notifications
import Combine

// MARK: - 1. ISOLATED HEADER
struct SessionHeaderView: View {
    let session: WorkoutSession
    @ObservedObject var healthManager = HealthManager.shared
    
    // Timer state
    @State private var elapsedTime = "00:00"
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 15) {
            if !session.isCompleted {
                HStack {
                    Spacer()
                    VStack {
                        Text("Duration").font(.caption).foregroundStyle(.secondary)
                        Text(elapsedTime).font(.title2).bold().monospacedDigit()
                    }
                    Spacer()
                }
            } else {
                Text("Workout Completed").font(.headline).foregroundStyle(.green)
                if let fileName = session.imageID, let uiImage = ImageManager.shared.loadImage(fileName: fileName) {
                    Image(uiImage: uiImage)
                        .resizable().scaledToFill()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }
                HStack {
                    if let duration = session.duration {
                        VStack {
                            Text("Total Time").font(.caption).foregroundStyle(.secondary)
                            Text(formatDuration(duration)).font(.title3).bold().monospacedDigit()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .onAppear { updateTimer() }
        .onReceive(timer) { _ in updateTimer() }
    }
    
    func updateTimer() {
        let diff = Date().timeIntervalSince(session.date)
        elapsedTime = formatDuration(diff)
    }
    
    func formatDuration(_ totalSeconds: TimeInterval) -> String {
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%02d:%02d", minutes, seconds)
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
    
    @State private var showExercisePicker = false
    @State private var newExerciseName = ""
    @State private var showFinishAlert = false
    
    // Sheets
    @State private var showCamera = false
    @State private var showSongSearch = false
    @State private var capturedImage: UIImage?
    
    // MARK: - INACTIVITY MONITOR STATE
    @State private var lastActivityTime = Date()
    @State private var hasNudged = false
    let inactivityThreshold: TimeInterval = 300 // 5 Minutes
    let activityTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect() // Checks every minute
    
    var workoutIndex: Int? {
        dataManager.workouts.firstIndex(where: { $0.id == workoutID })
    }

    var body: some View {
        if let index = workoutIndex {
            let session = dataManager.workouts[index]
            
            VStack(spacing: 0) {
                SessionHeaderView(session: session)
                
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
                    
                    // MARK: FINISH BUTTON
                    if !session.isCompleted {
                        Section {
                            Button("Finish Workout", role: .destructive) {
                                showFinishAlert = true
                            }
                        }
                    }
                }
            }
            .navigationTitle(session.type.rawValue.capitalized)
            .toolbar {
                if !session.isCompleted {
                    ToolbarItem(placement: .bottomBar) {
                        Button(action: { showCamera = true }) { Label("Add Photo", systemImage: "camera.fill") }
                    }
                }
            }
            // MARK: - LOGIC TRIGGERS
            .onAppear {
                if !session.isCompleted {
                    healthManager.startMonitoring(startTime: session.date)
                    requestNotificationPermissions()
                }
            }
            // Monitor Activity: If data changes (e.g. set logged), reset inactivity timer
            .onChange(of: dataManager.workouts) { _, _ in
                resetActivity()
            }
            // Check for Inactivity every minute
            .onReceive(activityTimer) { _ in
                checkInactivity(isCompleted: session.isCompleted)
            }
            .alert("Finish Workout?", isPresented: $showFinishAlert) {
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
            .onChange(of: capturedImage) { _, newImage in
                if let img = newImage, let fileName = ImageManager.shared.saveImage(img) {
                    if let oldFile = dataManager.workouts[index].imageID { ImageManager.shared.deleteImage(fileName: oldFile) }
                    dataManager.workouts[index].imageID = fileName
                    dataManager.save()
                }
            }
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
    
    // MARK: - INACTIVITY LOGIC
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    func resetActivity() {
        lastActivityTime = Date()
        hasNudged = false
    }
    
    func checkInactivity(isCompleted: Bool) {
        guard !isCompleted else { return }
        
        // If 5 minutes passed since last action AND we haven't nudged yet
        if Date().timeIntervalSince(lastActivityTime) > inactivityThreshold && !hasNudged {
            sendNudge()
            hasNudged = true
        }
    }
    
    func sendNudge() {
        let content = UNMutableNotificationContent()
        content.title = "Still working out?"
        content.body = "You haven't logged a set in 5 minutes. Keep the momentum going! 💪"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "inactivity_nudge", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - FINISH LOGIC
    func finishWorkout(index: Int) {
        let end = Date()
        let start = dataManager.workouts[index].date
        healthManager.fetchAverageHeartRate(start: start, end: end) { avg in
            if let hr = avg { dataManager.workouts[index].averageHeartRate = hr }
            dataManager.workouts[index].isCompleted = true
            dataManager.workouts[index].duration = end.timeIntervalSince(start)
            dataManager.workouts[index].activeCalories = healthManager.activeCalories
            if let loc = locationManager.userLocation {
                dataManager.workouts[index].latitude = loc.latitude
                dataManager.workouts[index].longitude = loc.longitude
            }
            dataManager.save()
            healthManager.stopMonitoring()
            dismiss()
        }
    }
}

// MARK: - HELPER VIEW
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
