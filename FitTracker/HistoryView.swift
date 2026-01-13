import SwiftUI

// 1. Define the Filter Categories
enum WorkoutFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case strength = "Strength"
    case cardio = "Cardio"
    var id: String { self.rawValue }
}

struct HistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var healthManager = HealthManager.shared
    
    // Sheets
    @State private var showRoutineSelection = false
    @State private var showSettings = false
    
    // Filter State
    @State private var selectedFilter: WorkoutFilter = .all
    
    // MARK: - FEATURE 1: TIME CAPSULE STATE
    @State private var throwbackSession: WorkoutSession?
    
    var lifetimeVolume: Int {
        Int(dataManager.workouts.reduce(0) { $0 + $1.totalVolume })
    }
    
    var filteredWorkouts: [WorkoutSession] {
        let sortedList = dataManager.workouts.sorted(by: { $0.date > $1.date })
        
        switch selectedFilter {
        case .all:
            return sortedList
        case .strength:
            return sortedList.filter { $0.type == .strength }
        case .cardio:
            return sortedList.filter { $0.type != .strength }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - FEATURE 1: THE TIME CAPSULE (Flashback)
                // Surfaces a random past workout to relive the memory
                if let memory = throwbackSession {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Memory Lane")
                            }
                            .font(.caption).bold().textCase(.uppercase).foregroundStyle(.white.opacity(0.8))
                            
                            // Date
                            Text(memory.date.formatted(date: .long, time: .omitted))
                                .font(.title2).bold().foregroundStyle(.white)
                            
                            // The "Vibe" (Notes)
                            if !memory.notes.isEmpty {
                                Text("\"\(memory.notes)\"")
                                    .font(.system(.body, design: .serif))
                                    .italic()
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.vertical, 4)
                            }
                            
                            // The Photo (If exists)
                            // The Photo (If exists)
                            // We request a downsampled version roughly the size of the view (e.g., 300x200 points)
                            if let fileName = memory.imageID,
                               let image = ImageManager.shared.loadImage(fileName: fileName, pointSize: CGSize(width: 300, height: 200)) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 180) // This frame is visual, the load above is memory
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(radius: 5)
                            }
                            
                            // Navigation to full details
                            // We use your existing helper function for the destination
                            NavigationLink(destination: destinationView(for: memory)) {
                                Text("View Session")
                                    .font(.headline)
                                    .foregroundStyle(.black)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(
                            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)) // Makes it stand out
                    .listRowBackground(Color.clear)
                }
                
                // MARK: - Summary Stats
                Section {
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(dataManager.workouts.count)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)
                            Text("Workouts").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        }
                        .frame(maxWidth: .infinity)
                        Divider()
                        VStack {
                            Text(formatVolume(lifetimeVolume))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)
                            Text("Lbs Lifted").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 10)
                    .listRowBackground(Color(.secondarySystemBackground))
                }
                
                // MARK: - Actions (Start Button Only)
                Section {
                    Button(action: { showRoutineSelection = true }) {
                        Label("Start Workout", systemImage: "plus")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.blue)
                    .foregroundStyle(.white)
                }
                
                // MARK: - Filter & History
                Section(header: Text("History")) {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(WorkoutFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 5)
                    
                    if filteredWorkouts.isEmpty {
                        Text("No workouts found").foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredWorkouts) { session in
                            NavigationLink(destination: destinationView(for: session)) {
                                HStack {
                                    Image(systemName: getIcon(for: session.type))
                                        .foregroundStyle(.white)
                                        .padding(8)
                                        .background(getColor(for: session.type))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading) {
                                        Text(session.type.rawValue.capitalized).font(.headline)
                                        Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    
                                    if session.type == .strength {
                                        Text("\(Int(session.totalVolume)) lbs")
                                            .font(.caption).bold().padding(6)
                                            .background(Color.blue.opacity(0.1)).foregroundStyle(.blue).cornerRadius(8)
                                    } else {
                                        let miles = (session.distance ?? 0) * 0.000621371
                                        Text(String(format: "%.2f mi", miles))
                                            .font(.caption).bold().padding(6)
                                            .background(Color.green.opacity(0.1)).foregroundStyle(.green).cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteWorkout)
                    }
                }
            }
            .navigationTitle("FitTracker")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showRoutineSelection) { RoutineSelectionView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            // Logic to pick a random memory when the view appears
            .onAppear {
                if throwbackSession == nil {
                    throwbackSession = getThrowbackWorkout()
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    // Logic to find a "worthy" memory
    func getThrowbackWorkout() -> WorkoutSession? {
        let completed = dataManager.workouts.filter { $0.isCompleted }
        
        // 1. Prioritize workouts with Photos
        if let withPhoto = completed.filter({ $0.imageID != nil }).randomElement() {
            return withPhoto
        }
        
        // 2. Prioritize workouts with Notes
        if let withNotes = completed.filter({ !$0.notes.isEmpty }).randomElement() {
            return withNotes
        }
        
        // 3. Fallback to any random workout
        return completed.randomElement()
    }
    
    @ViewBuilder
    func destinationView(for session: WorkoutSession) -> some View {
        if session.type == .strength {
            SessionDetailView(workoutID: session.id)
        } else {
            VStack {
                Text(session.type.rawValue.capitalized).font(.largeTitle).bold()
                Text(session.date.formatted())
                Divider().padding()
                Text("Distance: \(String(format: "%.2f", (session.distance ?? 0) * 0.000621371)) mi")
                Text("Duration: \(String(format: "%.0f", (session.duration ?? 0) / 60)) min")
                if let cals = session.activeCalories {
                    Text("Calories: \(Int(cals))").foregroundStyle(.orange)
                }
            }
        }
    }
    
    func getIcon(for type: WorkoutType) -> String {
        switch type {
        case .strength: return "dumbbell.fill"
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .cycle: return "bicycle"
        case .swim: return "figure.pool.swim"
        }
    }
    
    func getColor(for type: WorkoutType) -> Color {
        switch type {
        case .strength: return .blue
        default: return .green
        }
    }
    
    func deleteWorkout(at offsets: IndexSet) {
        offsets.forEach { index in
            let sessionToDelete = filteredWorkouts[index]
            if let indexInMain = dataManager.workouts.firstIndex(where: { $0.id == sessionToDelete.id }) {
                dataManager.workouts.remove(at: indexInMain)
            }
        }
        dataManager.save()
    }
    
    func formatVolume(_ volume: Int) -> String {
        if volume >= 1_000_000 { return String(format: "%.1fM", Double(volume) / 1_000_000) }
        else if volume >= 1_000 { return String(format: "%.1fk", Double(volume) / 1_000) }
        else { return "\(volume)" }
    }
}
