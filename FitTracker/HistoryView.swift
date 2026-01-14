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
    
    // Flashback State
    @State private var throwbackSession: WorkoutSession?
    
    var lifetimeVolume: Int {
        Int(dataManager.workouts.reduce(0) { $0 + $1.totalVolume })
    }
    
    var filteredWorkouts: [WorkoutSession] {
        let sortedList = dataManager.workouts.sorted(by: { $0.date > $1.date })
        switch selectedFilter {
        case .all: return sortedList
        case .strength: return sortedList.filter { $0.type == .strength }
        case .cardio: return sortedList.filter { $0.type != .strength }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - 1. CONSISTENCY HEAT MAP
                    VStack(alignment: .leading) {
                        Text("Consistency").font(.headline).padding(.horizontal)
                        CalendarGridView(workouts: dataManager.workouts)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(radius: 1)
                    }
                    .padding(.horizontal)
                    
                    // MARK: - 2. TIME CAPSULE (Flashback)
                    if let memory = throwbackSession {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Memory Lane")
                            }
                            .font(.caption).bold().textCase(.uppercase).foregroundStyle(.white.opacity(0.8))
                            
                            Text(memory.date.formatted(date: .long, time: .omitted))
                                .font(.title2).bold().foregroundStyle(.white)
                            
                            if !memory.notes.isEmpty {
                                Text("\"\(memory.notes)\"")
                                    .font(.system(.body, design: .serif))
                                    .italic().foregroundStyle(.white.opacity(0.9))
                            }
                            
                            NavigationLink(destination: destinationView(for: memory)) {
                                Text("View Session").bold()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .foregroundStyle(.purple)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // MARK: - 3. SUMMARY STATS
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(dataManager.workouts.count)")
                                .font(.title).bold().foregroundStyle(.blue)
                            Text("Workouts").font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        
                        VStack {
                            Text(formatVolume(lifetimeVolume))
                                .font(.title).bold().foregroundStyle(.blue)
                            Text("Lbs Lifted").font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // MARK: - 4. HISTORY LOG
                    VStack(alignment: .leading) {
                        Text("Log").font(.headline).padding(.horizontal)
                        
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(WorkoutFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        if filteredWorkouts.isEmpty {
                            Text("No workouts found")
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredWorkouts) { session in
                                    NavigationLink(destination: destinationView(for: session)) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(session.type.rawValue.capitalized)
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if session.type == .strength {
                                                Text("\(Int(session.totalVolume)) lbs")
                                                    .font(.caption).bold()
                                                    .padding(6).background(Color.blue.opacity(0.1)).foregroundStyle(.blue).cornerRadius(6)
                                            }
                                        }
                                        .padding()
                                        .background(Color(.systemBackground))
                                        .cornerRadius(12)
                                        .shadow(radius: 1)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.secondarySystemBackground))
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showSettings = true }) { Image(systemName: "gear") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showRoutineSelection = true }) { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showRoutineSelection) { RoutineSelectionView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onAppear {
                if throwbackSession == nil { throwbackSession = getThrowbackWorkout() }
            }
        }
    }
    
    // MARK: - CALENDAR GRID (Fixed Headers)
    struct CalendarGridView: View {
        let workouts: [WorkoutSession]
        
        // Generate last 28 days
        let days: [Date] = (-27...0).map { Calendar.current.date(byAdding: .day, value: $0, to: Date())! }
        
        // Offset for the first day (align to Sunday start)
        var offset: Int {
            let firstDay = days.first ?? Date()
            let weekday = Calendar.current.component(.weekday, from: firstDay)
            return weekday - 1 // Sunday=1 -> 0
        }
        
        let headerSymbols = ["S", "M", "T", "W", "T", "F", "S"]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Last 4 Weeks").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "flame.fill").font(.caption).foregroundStyle(.orange)
                    Text("Streak Active").font(.caption).bold()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    // FIX: Use indices to force every letter to render
                    ForEach(0..<7, id: \.self) { index in
                        Text(headerSymbols[index])
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(.secondary)
                    }
                    
                    // Spacers for alignment
                    ForEach(0..<offset, id: \.self) { _ in
                        Color.clear.frame(height: 30)
                    }
                    
                    // Days
                    ForEach(days, id: \.self) { date in
                        let isWorkout = workouts.contains { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.isCompleted }
                        let isToday = Calendar.current.isDateInToday(date)
                        
                        ZStack {
                            Circle()
                                .fill(isWorkout ? Color.blue : Color.gray.opacity(0.1))
                            
                            if isToday {
                                Circle().stroke(Color.blue, lineWidth: 2)
                            }
                            
                            Text(date.formatted(.dateTime.day()))
                                .font(.caption2)
                                .foregroundStyle(isWorkout ? .white : .primary)
                        }
                        .frame(height: 30)
                    }
                }
            }
        }
    }

    // MARK: - HELPERS
    func getThrowbackWorkout() -> WorkoutSession? {
        dataManager.workouts.filter { $0.isCompleted && !$0.notes.isEmpty }.randomElement() ?? dataManager.workouts.filter{$0.isCompleted}.randomElement()
    }
    
    @ViewBuilder
    func destinationView(for session: WorkoutSession) -> some View {
        if session.type == .strength { SessionDetailView(workoutID: session.id) }
        else { Text("Cardio Details") }
    }
    
    func formatVolume(_ volume: Int) -> String {
        if volume >= 1_000_000 { return String(format: "%.1fM", Double(volume)/1_000_000) }
        return volume >= 1_000 ? String(format: "%.1fk", Double(volume)/1_000) : "\(volume)"
    }
}
