import SwiftUI
import MapKit

// MARK: - Workout Filter

enum WorkoutFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case strength = "Strength"
    case cardio = "Cardio"
    
    var id: String {
        rawValue
    }
}

// MARK: - History View

struct HistoryView: View {
    
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var healthManager = HealthManager.shared
    
    @State private var showRoutineSelection = false
    @State private var showSettings = false
    
    @State private var selectedFilter: WorkoutFilter = .all
    @State private var throwbackSession: WorkoutSession?
    
    @State private var selectedDate: Date?
    @State private var showDaySheet = false
    
    // MARK: - Basic Statistics
    
    var lifetimeVolume: Double {
        dataManager.completedWorkouts.reduce(0) {
            $0 + $1.totalVolume
        }
    }
    var completedWorkouts: [WorkoutSession] {
        dataManager.completedWorkouts
    }
    
    var filteredWorkouts: [WorkoutSession] {
        let sortedList = dataManager.workouts
            .filter { session in
                session.isCompleted ||
                session.exercises.contains {
                    !$0.sets.isEmpty
                }
            }
            .sorted {
                $0.date > $1.date
            }

        switch selectedFilter {
        case .all:
            return sortedList

        case .strength:
            return sortedList.filter {
                $0.type == .strength
            }

        case .cardio:
            return sortedList.filter {
                $0.type != .strength
            }
        }
    }
    // MARK: - Training Consistency
    
    var currentStreak: Int {
        let calendar = Calendar.current
        
        let workoutDays = Set(
            completedWorkouts.map {
                calendar.startOfDay(for: $0.date)
            }
        )
        
        var streak = 0
        var date = calendar.startOfDay(for: Date())
        
        // If there was no workout today,
        // start checking from yesterday.
        if !workoutDays.contains(date) {
            guard let yesterday = calendar.date(
                byAdding: .day,
                value: -1,
                to: date
            ) else {
                return 0
            }
            
            date = yesterday
        }
        
        while workoutDays.contains(date) {
            streak += 1
            
            guard let previousDay = calendar.date(
                byAdding: .day,
                value: -1,
                to: date
            ) else {
                break
            }
            
            date = previousDay
        }
        
        return streak
    }
    
    var longestStreak: Int {
        let calendar = Calendar.current
        
        let workoutDays = Set(
            completedWorkouts.map {
                calendar.startOfDay(for: $0.date)
            }
        )
        
        guard !workoutDays.isEmpty else {
            return 0
        }
        
        let sortedDays = workoutDays.sorted()
        
        var longest = 1
        var current = 1
        
        if sortedDays.count > 1 {
            for index in 1..<sortedDays.count {
                let difference = calendar.dateComponents(
                    [.day],
                    from: sortedDays[index - 1],
                    to: sortedDays[index]
                ).day ?? 0
                
                if difference == 1 {
                    current += 1
                    longest = max(longest, current)
                } else {
                    current = 1
                }
            }
        }
        
        return longest
    }
    
    var workoutsThisWeek: Int {
        let calendar = Calendar.current
        
        guard let interval = calendar.dateInterval(
            of: .weekOfYear,
            for: Date()
        ) else {
            return 0
        }
        
        return completedWorkouts.filter {
            interval.contains($0.date)
        }.count
    }
    
    var workoutsThisMonth: Int {
        let calendar = Calendar.current
        
        guard let interval = calendar.dateInterval(
            of: .month,
            for: Date()
        ) else {
            return 0
        }
        
        return completedWorkouts.filter {
            interval.contains($0.date)
        }.count
    }
    
    var weeklyConsistency: Double {
        let calendar = Calendar.current
        
        guard let interval = calendar.dateInterval(
            of: .weekOfYear,
            for: Date()
        ) else {
            return 0
        }
        
        let daysElapsed = max(
            1,
            calendar.dateComponents(
                [.day],
                from: interval.start,
                to: Date()
            ).day! + 1
        )
        
        let activeDays = Set(
            completedWorkouts
                .filter {
                    interval.contains($0.date)
                }
                .map {
                    calendar.startOfDay(for: $0.date)
                }
        ).count
        
        return min(
            1.0,
            Double(activeDays) / Double(daysElapsed)
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    lifetimeStatsSection
                    
                    consistencySection
                    
                    memoryLaneSection
                    
                    workoutLogSection
                }
                .padding(.vertical)
            }
            .background(
                Color(.secondarySystemBackground)
            )
            .navigationTitle("History")
            .toolbar {
                
                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button {
                        showRoutineSelection = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(
                isPresented: $showRoutineSelection
            ) {
                RoutineSelectionView()
            }
            .sheet(
                isPresented: $showSettings
            ) {
                SettingsView()
            }
            .sheet(
                isPresented: $showDaySheet
            ) {
                if let date = selectedDate {
                    DayWorkoutSheet(date: date)
                }
            }
            .onAppear {
                if throwbackSession == nil {
                    throwbackSession = getThrowbackWorkout()
                }
            }
        }
    }
    
    // MARK: - Lifetime Stats
    
    private var lifetimeStatsSection: some View {
        HStack(spacing: 15) {
            
            StatsCard(
                title: "Total Workouts",
                value: "\(completedWorkouts.count)",
                icon: "figure.strengthtraining.traditional",
                color: .blue
            )
            
            StatsCard(
                title: "Lifetime Volume",
                value: dataManager.formatVolume(
                    lifetimeVolume
                ),
                icon: "dumbbell.fill",
                color: .purple
            )
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    private var emptyWorkoutTitle: String {
        switch selectedFilter {
        case .all:
            return "No Workouts Yet"
            
        case .strength:
            return "No Strength Workouts"
            
        case .cardio:
            return "No Cardio Workouts"
        }
    }

    private var emptyWorkoutMessage: String {
        switch selectedFilter {
        case .all:
            return "Your completed workouts will appear here. Start your first session and begin building your training history."
            
        case .strength:
            return "No completed strength workouts match this filter yet."
            
        case .cardio:
            return "No completed cardio workouts match this filter yet."
        }
    }
    
    // MARK: - Consistency Section
    
    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text("Training Consistency")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 10) {
                
                ConsistencyStat(
                    title: "Current",
                    value: "\(currentStreak)",
                    subtitle: "day streak",
                    icon: "flame.fill"
                )
                
                ConsistencyStat(
                    title: "Longest",
                    value: "\(longestStreak)",
                    subtitle: "day streak",
                    icon: "trophy.fill"
                )
                
                ConsistencyStat(
                    title: "This Week",
                    value: "\(workoutsThisWeek)",
                    subtitle: "workouts",
                    icon: "calendar"
                )
                
                ConsistencyStat(
                    title: "This Month",
                    value: "\(workoutsThisMonth)",
                    subtitle: "workouts",
                    icon: "calendar.badge.clock"
                )
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                
                HStack {
                    Text("Weekly Consistency")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(
                        "\(Int(weeklyConsistency * 100))%"
                    )
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
                }
                
                ProgressView(
                    value: weeklyConsistency
                )
                .tint(.blue)
            }
            .padding()
            .background(
                Color(.systemBackground)
            )
            .cornerRadius(12)
            .shadow(radius: 1)
            .padding(.horizontal)
            
            CalendarGridView(
                workouts: dataManager.workouts,
                currentStreak: currentStreak
            ) { date in
                selectedDate = date
                showDaySheet = true
            }
            .padding()
            .background(
                Color(.systemBackground)
            )
            .cornerRadius(12)
            .shadow(radius: 1)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Memory Lane
    
    @ViewBuilder
    private var memoryLaneSection: some View {
        
        if let memory = throwbackSession {
            
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                
                HStack {
                    Image(
                        systemName: "clock.arrow.circlepath"
                    )
                    
                    Text("Memory Lane")
                }
                .font(.caption)
                .bold()
                .textCase(.uppercase)
                .foregroundStyle(
                    .white.opacity(0.8)
                )
                
                Text(
                    memory.date.formatted(
                        date: .long,
                        time: .omitted
                    )
                )
                .font(.title2)
                .bold()
                .foregroundStyle(.white)
                
                Text(
                    "\"\(displayTitle(for: memory))\""
                )
                .font(.headline)
                .italic()
                .foregroundStyle(
                    .white.opacity(0.9)
                )
                
                NavigationLink(
                    destination: destinationView(
                        for: memory
                    )
                ) {
                    Text("View Session")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .foregroundStyle(.purple)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Workout Log
    
    private var workoutLogSection: some View {
        VStack(alignment: .leading) {
            
            Text("Log")
                .font(.headline)
                .padding(.horizontal)
            
            Picker(
                "Filter",
                selection: $selectedFilter
            ) {
                ForEach(
                    WorkoutFilter.allCases
                ) { filter in
                    Text(filter.rawValue)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            if filteredWorkouts.isEmpty {
                
                EmptyStateView(
                    icon: "figure.strengthtraining.traditional",
                    title: emptyWorkoutTitle,
                    message: emptyWorkoutMessage,
                    actionTitle: "Start a Workout",
                    action: {
                        showRoutineSelection = true
                    }
                )
                .frame(minHeight: 260)
                
            } else {
                
                LazyVStack(spacing: 12) {
                    
                    ForEach(
                        filteredWorkouts
                    ) { session in
                        
                        NavigationLink(
                            destination: destinationView(
                                for: session
                            )
                        ) {
                            
                            WorkoutHistoryCard(
                                session: session,
                                dataManager: dataManager,
                                displayTitle: displayTitle(
                                    for: session
                                ),
                                personalRecords: prs(
                                    for: session
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Helpers
    
    func displayTitle(
        for session: WorkoutSession
    ) -> String {
        
        if let title = session.workoutTitle,
           !title.isEmpty {
            return title
        }
        
        if !session.notes.isEmpty &&
            session.notes.count < 30 {
            return session.notes
        }
        
        return session.type.rawValue.capitalized
    }
    
    func prs(for session: WorkoutSession) -> [PersonalRecord] {
        dataManager.personalRecords.filter {
            $0.workoutID == session.id &&
            $0.type != .estimatedOneRepMax
        }
    }
    
    func groupedPRs(
        for session: WorkoutSession
    ) -> [(exerciseName: String, records: [PersonalRecord])] {
        
        let grouped = Dictionary(
            grouping: prs(for: session),
            by: { $0.exerciseName }
        )
        
        return grouped
            .map {
                (
                    exerciseName: $0.key,
                    records: $0.value.sorted {
                        $0.type.rawValue < $1.type.rawValue
                    }
                )
            }
            .sorted {
                $0.exerciseName < $1.exerciseName
            }
    }
    
    func shortPRType(_ type: PRType) -> String {
        switch type {
        case .heaviestWeight:
            return "Weight"
            
        case .repRecord:
            return "Reps"
            
        case .estimatedOneRepMax:
            return "1RM"
        }
    }
    
    func getThrowbackWorkout() -> WorkoutSession? {
        dataManager.completedWorkouts
            .filter {
                !$0.notes.isEmpty
            }
            .randomElement()
        ??
        dataManager.completedWorkouts.randomElement()
    }
    
    @ViewBuilder
    func destinationView(
        for session: WorkoutSession
    ) -> some View {
        
        if session.type == .strength {
            SessionDetailView(
                workoutID: session.id
            )
        } else {
            Text("Cardio Details")
        }
    }
}

// MARK: - Calendar Grid

struct CalendarGridView: View {
    
    let workouts: [WorkoutSession]
    let currentStreak: Int
    var onDateSelected: (Date) -> Void
    
    let days: [Date] = (-27...0).map {
        Calendar.current.date(
            byAdding: .day,
            value: $0,
            to: Date()
        )!
    }
    
    var offset: Int {
        let firstDay = days.first ?? Date()
        
        let weekday = Calendar.current.component(
            .weekday,
            from: firstDay
        )
        
        return weekday - 1
    }
    
    let headerSymbols = [
        "S", "M", "T", "W", "T", "F", "S"
    ]
    
    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            
            HStack {
                
                Text("Last 4 Weeks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Image(
                    systemName: "flame.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                
                Text(
                    "\(currentStreak) day streak"
                )
                .font(.caption)
                .bold()
            }
            
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible()),
                    count: 7
                ),
                spacing: 8
            ) {
                
                ForEach(
                    0..<7,
                    id: \.self
                ) { index in
                    
                    Text(
                        headerSymbols[index]
                    )
                    .font(.caption2)
                    .bold()
                    .foregroundStyle(.secondary)
                }
                
                ForEach(
                    0..<offset,
                    id: \.self
                ) { _ in
                    
                    Color.clear
                        .frame(height: 30)
                }
                
                ForEach(
                    days,
                    id: \.self
                ) { date in
                    
                    let isWorkout = workouts.contains {
                        Calendar.current.isDate(
                            $0.date,
                            inSameDayAs: date
                        ) && $0.isCompleted
                    }
                    
                    let isToday =
                        Calendar.current.isDateInToday(
                            date
                        )
                    
                    ZStack {
                        
                        Circle()
                            .fill(
                                isWorkout
                                ? Color.blue
                                : Color.gray.opacity(0.1)
                            )
                        
                        if isToday {
                            Circle()
                                .stroke(
                                    Color.blue,
                                    lineWidth: 2
                                )
                        }
                        
                        Text(
                            date.formatted(
                                .dateTime.day()
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(
                            isWorkout
                            ? .white
                            : .primary
                        )
                    }
                    .frame(height: 30)
                    .onTapGesture {
                        if isWorkout {
                            onDateSelected(date)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Stats Card

struct StatsCard: View {
    
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            
            HStack {
                
                Image(systemName: icon)
                    .foregroundStyle(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .bold()
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            Color(.systemBackground)
        )
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

// MARK: - Consistency Stat

struct ConsistencyStat: View {
    
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 5) {
            
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            Color(.systemBackground)
        )
        .cornerRadius(10)
        .shadow(radius: 1)
    }
}

// MARK: - Day Workout Sheet

struct DayWorkoutSheet: View {
    let date: Date
    
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var position: MapCameraPosition = .automatic
    
    private var workoutsOnDay: [WorkoutSession] {
        dataManager.workouts
            .filter {
                Calendar.current.isDate(
                    $0.date,
                    inSameDayAs: date
                )
            }
            .sorted {
                $0.date < $1.date
            }
    }
    
    private var completedWorkoutsOnDay: [WorkoutSession] {
        workoutsOnDay.filter { $0.isCompleted }
    }
    
    private var locations: [WorkoutSession] {
        completedWorkoutsOnDay.filter {
            $0.latitude != nil &&
            $0.longitude != nil
        }
    }
    
    func displayTitle(
        for session: WorkoutSession
    ) -> String {
        
        if let title = session.workoutTitle,
           !title.isEmpty {
            return title
        }
        
        if !session.notes.isEmpty &&
           session.notes.count < 30 {
            return session.notes
        }
        
        return session.type.rawValue.capitalized
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // MARK: - Date Header
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            date.formatted(
                                .dateTime.weekday(.wide)
                                    .month(.wide)
                                    .day()
                            )
                        )
                        .font(.title2)
                        .fontWeight(.bold)
                        
                        Text(
                            completedWorkoutsOnDay.isEmpty
                            ? "Rest Day"
                            : "\(completedWorkoutsOnDay.count) workout"
                            + (completedWorkoutsOnDay.count == 1 ? "" : "s")
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    
                    // MARK: - Map
                    
                    if !locations.isEmpty {
                        Map(position: $position) {
                            ForEach(locations) { session in
                                if let latitude = session.latitude,
                                   let longitude = session.longitude {
                                    
                                    Marker(
                                        displayTitle(for: session),
                                        coordinate: CLLocationCoordinate2D(
                                            latitude: latitude,
                                            longitude: longitude
                                        )
                                    )
                                    .tint(.blue)
                                }
                            }
                        }
                        .frame(height: 220)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 14)
                        )
                        .padding(.horizontal)
                        .onAppear {
                            if let first = locations.first,
                               let latitude = first.latitude,
                               let longitude = first.longitude {
                                
                                position = .region(
                                    MKCoordinateRegion(
                                        center: CLLocationCoordinate2D(
                                            latitude: latitude,
                                            longitude: longitude
                                        ),
                                        span: MKCoordinateSpan(
                                            latitudeDelta: 0.02,
                                            longitudeDelta: 0.02
                                        )
                                    )
                                )
                            }
                        }
                    }
                    
                    
                    // MARK: - Workouts
                    
                    if completedWorkoutsOnDay.isEmpty {
                        
                        ContentUnavailableView(
                            "Rest Day",
                            systemImage: "bed.double.fill",
                            description: Text(
                                "No completed workouts were logged on this day."
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        
                    } else {
                        
                        VStack(alignment: .leading, spacing: 10) {
                            
                            Text("Workouts")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(completedWorkoutsOnDay) { session in
                                
                                NavigationLink(
                                    destination: SessionDetailView(
                                        workoutID: session.id
                                    )
                                ) {
                                    HStack(spacing: 14) {
                                        
                                        Image(
                                            systemName:
                                                session.type == .strength
                                                ? "dumbbell.fill"
                                                : "figure.run"
                                        )
                                        .foregroundStyle(.blue)
                                        .frame(width: 30)
                                        
                                        VStack(
                                            alignment: .leading,
                                            spacing: 4
                                        ) {
                                            
                                            Text(
                                                displayTitle(
                                                    for: session
                                                )
                                            )
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            
                                            Text(
                                                session.date.formatted(
                                                    date: .omitted,
                                                    time: .shortened
                                                )
                                            )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            
                                            if session.type == .strength {
                                                Text(
                                                    "\(session.exercises.count) exercises • " +
                                                    "\(session.exercises.reduce(0) { $0 + $1.sets.count }) sets • " +
                                                    "\(dataManager.formatVolume(session.totalVolume))"
                                                )
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(
                                            systemName: "chevron.right"
                                        )
                                        .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(
                                        Color(.secondarySystemBackground)
                                    )
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 12
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom)
            }
            .background(
                Color(.systemBackground)
            )
            .navigationTitle(
                date.formatted(
                    date: .abbreviated,
                    time: .omitted
                )
            )
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Workout Stat

struct WorkoutStat: View {
    
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
