import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    
    // Calculate total volume across all workouts
    var lifetimeVolume: Int {
        Int(dataManager.workouts.reduce(0) { $0 + $1.totalVolume })
    }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Summary Stats Card
                Section {
                    HStack(spacing: 20) {
                        // Card 1: Workouts Count
                        VStack {
                            Text("\(dataManager.workouts.count)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)
                            Text("Workouts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider()
                        
                        // Card 2: Total Volume
                        VStack {
                            Text(formatVolume(lifetimeVolume))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)
                            Text("Lbs Lifted")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 10)
                    .listRowBackground(Color(.secondarySystemBackground))
                }
                
                // MARK: - Start Button
                Button(action: startNewSession) {
                    Label("Start Workout", systemImage: "plus")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.blue)
                .foregroundStyle(.white)
                
                // MARK: - History List
                Section(header: Text("History")) {
                    if dataManager.workouts.isEmpty {
                        Text("No workouts yet")
                            .foregroundStyle(.secondary)
                    } else {
                        // Sort by date (newest first)
                        ForEach(dataManager.workouts.sorted(by: { $0.date > $1.date })) { session in
                            NavigationLink(destination: SessionDetailView(workoutID: session.id)) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.headline)
                                        Text("\(session.exercises.count) exercises")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    // Volume Badge
                                    Text("\(Int(session.totalVolume)) lbs")
                                        .font(.caption)
                                        .bold()
                                        .padding(6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .onDelete(perform: deleteWorkout)
                    }
                }
            }
            .navigationTitle("FitTracker")
        }
    }
    
    // Helper: Turn 12500 into 12.5k
    func formatVolume(_ volume: Int) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM", Double(volume) / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.1fk", Double(volume) / 1_000)
        } else {
            return "\(volume)"
        }
    }
    
    func startNewSession() {
        let newSession = WorkoutSession(date: Date())
        dataManager.addWorkout(newSession)
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
}
