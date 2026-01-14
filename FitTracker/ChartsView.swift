import SwiftUI
import Charts

struct ChartsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedChart: ChartType = .volume
    
    enum ChartType: String, CaseIterable, Identifiable {
        case volume = "Volume"
        case consistency = "Sets/Wk"
        case balance = "Balance"
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 15) {
                // 1. Segmented Control
                Picker("Chart Type", selection: $selectedChart) {
                    ForEach(ChartType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                
                // 2. Chart Container
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedChart {
                        case .volume:
                            VolumeTrendView()
                        case .consistency:
                            ConsistencyBarChart()
                        case .balance:
                            MuscleRadarChart()
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Analytics")
            .background(Color(.secondarySystemBackground))
        }
    }
}

// MARK: - 1. VOLUME CHART (Total Load)
struct VolumeTrendView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedExercise: String = "All Exercises"
    
    var availableExercises: [String] {
        let all = dataManager.workouts.flatMap { $0.exercises }.map { $0.name }
        let unique = Array(Set(all)).sorted()
        return ["All Exercises"] + unique
    }
    
    struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    var chartData: [DataPoint] {
        let history = dataManager.workouts.filter { $0.isCompleted }.sorted { $0.date < $1.date }
        var points: [DataPoint] = []
        
        for workout in history {
            var vol = 0.0
            if selectedExercise == "All Exercises" {
                // Sum of ALL exercises in the workout
                vol = Double(workout.totalVolume)
            } else {
                // Specific exercise volume
                if let exercise = workout.exercises.first(where: { $0.name == selectedExercise }) {
                    vol = exercise.sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
                }
            }
            
            if vol > 0 {
                points.append(DataPoint(date: workout.date, value: vol))
            }
        }
        return points
    }
    
    var body: some View {
        VStack(spacing: 15) {
            // Filter
            HStack {
                Text("Filter:")
                    .font(.caption).bold().foregroundStyle(.secondary)
                Picker("Exercise", selection: $selectedExercise) {
                    ForEach(availableExercises, id: \.self) { name in Text(name).tag(name) }
                }
                .pickerStyle(.menu)
                .tint(.green)
            }
            
            // Chart
            ChartCard(title: "Volume Load (lbs)", data: chartData, color: .green)
            
            // Stats
            if !chartData.isEmpty {
                let totalLife = chartData.reduce(0) { $0 + $1.value }
                let avg = totalLife / Double(chartData.count)
                
                HStack(spacing: 15) {
                    StatBox(title: "Avg per Session", value: formatNum(avg), color: .primary)
                    StatBox(title: "Lifetime Volume", value: formatNum(totalLife), color: .green)
                }
                .padding(.horizontal)
            }
        }
    }
    
    func formatNum(_ val: Double) -> String {
        if val >= 1_000_000 { return String(format: "%.1fM", val/1_000_000) }
        if val >= 1_000 { return String(format: "%.1fk", val/1_000) }
        return String(format: "%.0f", val)
    }
}

// MARK: - 2. CONSISTENCY CHART (Sets per Week)
struct ConsistencyBarChart: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var recompManager = RecompManager.shared
    
    struct WeeklyData: Identifiable {
        let id = UUID()
        let weekLabel: String
        let totalSets: Int
    }
    
    var barData: [WeeklyData] {
        // Group last 4 weeks
        let cal = Calendar.current
        let today = Date()
        var data: [WeeklyData] = []
        
        for i in (0..<4).reversed() {
            if let weekStart = cal.date(byAdding: .day, value: -(i * 7), to: today) {
                let weekNum = cal.component(.weekOfYear, from: weekStart)
                
                // Find workouts in this week
                let workouts = dataManager.workouts.filter {
                    cal.isDate($0.date, equalTo: weekStart, toGranularity: .weekOfYear) && $0.isCompleted
                }
                
                var sets = 0
                for w in workouts {
                    for e in w.exercises { sets += e.sets.count }
                }
                
                data.append(WeeklyData(weekLabel: "W\(weekNum)", totalSets: sets))
            }
        }
        return data
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Weekly Set Volume").font(.caption).foregroundStyle(.secondary).padding(.leading)
            
            Chart {
                ForEach(barData) { week in
                    BarMark(
                        x: .value("Week", week.weekLabel),
                        y: .value("Sets", week.totalSets)
                    )
                    .foregroundStyle(week.totalSets >= (recompManager.weeklySetTarget * 2) ? Color.green : Color.blue) // *2 roughly for full body
                    
                    RuleMark(y: .value("Target", recompManager.weeklySetTarget * 3)) // Approx target line
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }
            .frame(height: 250)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding()
            .shadow(radius: 2)
            
            HStack {
                StatBox(title: "This Week", value: "\(barData.last?.totalSets ?? 0) Sets", color: .primary)
                StatBox(title: "Weekly Target", value: "Keep it up!", color: .blue)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - 3. MUSCLE RADAR CHART (Safe Math)
struct MuscleRadarChart: View {
    @EnvironmentObject var dataManager: DataManager
    
    struct MuscleData { let muscle: String; let sets: Int }
    
    var radarData: [MuscleData] {
        var map = ["Chest":0,"Back":0,"Legs":0,"Shoulders":0,"Arms":0,"Core":0]
        dataManager.workouts.filter{$0.isCompleted}.forEach { w in
            w.exercises.forEach { e in map[e.muscleGroup.rawValue, default:0] += e.sets.count }
        }
        let order = ["Chest","Back","Legs","Shoulders","Arms","Core"]
        return order.map { MuscleData(muscle: $0, sets: map[$0] ?? 0) }
    }
    
    var maxVol: Double { Double(radarData.map{$0.sets}.max() ?? 10) }
    
    var body: some View {
        VStack {
            Text("Weekly Balance").font(.headline)
            RadarChartView(data: radarData, maxVolume: maxVol)
                .frame(height: 300)
                .padding()
                .background(Color(.systemBackground)).cornerRadius(12)
        }
        .padding()
        .shadow(radius: 2)
    }
}

// MARK: - HELPERS (Shared)
struct ChartCard: View {
    let title: String
    let data: [VolumeTrendView.DataPoint] // Shared DataPoint struct
    let color: Color
    
    var body: some View {
        if data.isEmpty {
            VStack(spacing: 15) {
                Image(systemName: "chart.xyaxis.line").font(.largeTitle).foregroundStyle(.gray)
                Text("No data yet").foregroundStyle(.secondary)
            }
            .frame(height: 250).frame(maxWidth: .infinity)
            .background(Color(.systemBackground)).cornerRadius(12).padding()
        } else {
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundStyle(.secondary).padding(.leading)
                Chart {
                    ForEach(data) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Val", point.value))
                            .foregroundStyle(color)
                            .interpolationMethod(.catmullRom)
                        AreaMark(x: .value("Date", point.date), y: .value("Val", point.value))
                            .foregroundStyle(LinearGradient(colors: [color.opacity(0.3), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                        PointMark(x: .value("Date", point.date), y: .value("Val", point.value))
                            .foregroundStyle(color)
                    }
                }
                .frame(height: 250)
                .padding()
            }
            .background(Color(.systemBackground)).cornerRadius(12).padding().shadow(radius: 2)
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).bold().foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

// Radar Chart Shapes (Safe Math)
struct RadarChartView: View {
    let data: [MuscleRadarChart.MuscleData]; let maxVolume: Double
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
            let radius = min(geo.size.width, geo.size.height)/2 * 0.8
            ZStack {
                ForEach(1...4, id: \.self) { i in
                    RadarWebShape(sides: data.count, value: Double(i)/4.0)
                        .stroke(Color.gray.opacity(0.3))
                }
                RadarDataShape(data: data, maxVolume: maxVolume).fill(Color.purple.opacity(0.3))
                RadarDataShape(data: data, maxVolume: maxVolume).stroke(Color.purple, lineWidth: 2)
                ForEach(0..<data.count, id:\.self) { i in
                    RadarLabel(i: i, count: data.count, radius: radius, center: center, text: data[i].muscle)
                }
            }
        }
    }
}

struct RadarLabel: View {
    let i: Int; let count: Int; let radius: CGFloat; let center: CGPoint; let text: String
    var body: some View {
        let angleDeg = Double(i) * (360.0/Double(count)) - 90.0
        let angleRad = angleDeg * .pi/180.0
        let x = center.x + (radius + 20) * cos(angleRad)
        let y = center.y + (radius + 20) * sin(angleRad)
        return Text(text).font(.caption2).position(x: x, y: y)
    }
}

struct RadarWebShape: Shape {
    let sides: Int; let value: Double
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height)/2 * value
        for i in 0..<sides {
            let angleDeg = Double(i) * (360.0/Double(sides)) - 90.0
            let angleRad = angleDeg * .pi/180.0
            let pt = CGPoint(x: center.x + radius * cos(angleRad), y: center.y + radius * sin(angleRad))
            if i==0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath(); return path
    }
}

struct RadarDataShape: Shape {
    let data: [MuscleRadarChart.MuscleData]; let maxVolume: Double
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxR = min(rect.width, rect.height)/2
        for (i, entry) in data.enumerated() {
            let r = maxR * (Double(entry.sets)/maxVolume)
            let angleDeg = Double(i) * (360.0/Double(data.count)) - 90.0
            let angleRad = angleDeg * .pi/180.0
            let pt = CGPoint(x: center.x + r * cos(angleRad), y: center.y + r * sin(angleRad))
            if i==0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath(); return path
    }
}
