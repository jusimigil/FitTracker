import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    
    // Use ObservedObject for the shared instance
    @ObservedObject var healthManager = HealthManager.shared
    
    // Sheets
    @State private var showRoutineSelection = false
    @State private var showSettings = false
    
    var lifetimeVolume: Int {
        Int(dataManager.workouts.reduce(0) { $0 + $1.totalVolume })
    }
    
    var body: some View {
        NavigationStack {
            List {
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
                
                // MARK: - Start Button
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
                
                // MARK: - Import Button
                Section {
                    Button(action: importWorkouts) {
                        Label("Sync Apple Watch Runs", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                
                // MARK: - History List
                Section(header: Text("History")) {
                    if dataManager.workouts.isEmpty {
                        Text("No workouts yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(dataManager.workouts.sorted(by: { $0.date > $1.date })) { session in
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
            // MARK: - Toolbar (Gear Icon)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            // MARK: - Sheets
            // FIX: Ensure this matches the struct name (RoutineSelectionView)
            .sheet(isPresented: $showRoutineSelection) { RoutineSelection() }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }
    
    // MARK: - Helper Functions
    
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

    func importWorkouts() {
        // FIX: Use the new robust sync function from HealthManager
        // This handles Runs AND Swims automatically
        healthManager.syncWorkouts(into: dataManager)
    }
    
    func deleteWorkout(at offsets: IndexSet) {
        let sortedList = dataManager.workouts.sorted(by: { $0.date > $1.date })
        offsets.forEach { index in
            let sessionToDelete = sortedList[index]
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
