import SwiftUI
import Charts

// MARK: - 1. MAIN ANALYTICS VIEW
struct ChartsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showInput = false
    @State private var inputBodyFat = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    
                    // 1. Consistency Heatmap
                    CalendarHeatmap()
                    
                    // 2. Muscle Balance Spider Graph (Restored & Fixed)
                    MuscleRadarChart()
                    
                    // 3. Body Fat % Chart (Restored)
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Body Fat %").font(.headline)
                            Spacer()
                            if let last = dataManager.bodyMetrics.last, let bf = last.bodyFat {
                                Text("\(String(format: "%.1f", bf))%").font(.caption).bold().padding(6)
                                    .background(Color.orange.opacity(0.1)).foregroundStyle(.orange).cornerRadius(8)
                            }
                        }
                        if dataManager.bodyMetrics.filter({ $0.bodyFat != nil }).isEmpty {
                            ContentUnavailableView("No Data", systemImage: "percent", description: Text("Log body fat to see trends"))
                                .frame(height: 150)
                        } else {
                            Chart {
                                ForEach(dataManager.bodyMetrics.filter { $0.bodyFat != nil }) { metric in
                                    LineMark(x: .value("Date", metric.date), y: .value("BF%", metric.bodyFat!))
                                        .interpolationMethod(.catmullRom).foregroundStyle(.orange).symbol(by: .value("Date", metric.date))
                                }
                            }
                            .frame(height: 180).chartYScale(domain: .automatic(includesZero: false))
                        }
                    }
                    .padding().background(Color(.secondarySystemBackground)).cornerRadius(12)
                    
                    // 4. Volume Progression Chart (Restored)
                    VStack(alignment: .leading) {
                        Text("Volume Progression").font(.headline)
                        if dataManager.workouts.isEmpty {
                            ContentUnavailableView("No Data", systemImage: "chart.xyaxis.line", description: Text("Log a workout to see volume"))
                                .frame(height: 150)
                        } else {
                            Chart {
                                ForEach(dataManager.workouts.sorted(by: { $0.date < $1.date })) { session in
                                    LineMark(x: .value("Date", session.date), y: .value("Volume", session.totalVolume))
                                        .interpolationMethod(.catmullRom).foregroundStyle(.blue)
                                }
                            }
                            .frame(height: 180)
                        }
                    }
                    .padding().background(Color(.secondarySystemBackground)).cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showInput = true }) { Image(systemName: "plus.circle") }
                }
            }
            .alert("Log Body Fat", isPresented: $showInput) {
                TextField("Body Fat %", text: $inputBodyFat).keyboardType(.decimalPad)
                Button("Save") {
                    if let bf = Double(inputBodyFat) {
                        dataManager.addMetric(weight: nil, bodyFat: bf)
                        inputBodyFat = ""
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
}

// MARK: - 2. MUSCLE RADAR LOGIC
struct MuscleRadarChart: View {
    @EnvironmentObject var dataManager: DataManager
    
    var radarData: [MuscleVolumeData] {
        var totals: [MuscleGroup: Double] = [:]
        MuscleGroup.allCases.forEach { totals[$0] = 0 }
        let recent = dataManager.workouts.filter { $0.date >= Calendar.current.date(byAdding: .day, value: -30, to: Date())! }
        
        for w in recent {
            for e in w.exercises {
                let vol = e.sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
                totals[e.muscleGroup, default: 0] += vol
            }
        }
        return MuscleGroup.allCases.map { MuscleVolumeData(muscle: $0.rawValue, volume: totals[$0] ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Muscle Balance (Spider Graph)").font(.headline)
            let maxVol = radarData.map { $0.volume }.max() ?? 1.0
            
            RadarChart(data: radarData, maxVolume: maxVol)
                .frame(height: 220)
                .padding(.vertical, 25)
        }
        .padding().background(Color(.secondarySystemBackground)).cornerRadius(12)
    }
}

// MARK: - 3. REFACTORED RADAR CHART (Fixed Compiler Crash)
struct RadarChart: View {
    let data: [MuscleVolumeData]
    let maxVolume: Double
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 * 0.8
            let sideCount = data.count
            
            ZStack {
                // Background Rings
                ForEach(1...4, id: \.self) { i in
                    RadarWebShape(sides: sideCount, radius: radius * (Double(i) / 4))
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }
                
                // Data Shape
                RadarDataShape(data: data, maxVolume: maxVolume, radius: radius)
                    .fill(Color.blue.opacity(0.3))
                RadarDataShape(data: data, maxVolume: maxVolume, radius: radius)
                    .stroke(Color.blue, lineWidth: 2)
                
                // Labels - Simplified math to prevent timeout
                ForEach(0..<sideCount, id: \.self) { i in
                    let angle = (Double(i) * (360 / Double(sideCount)) - 90) * .pi / 180
                    let xPos = center.x + (radius + 28) * cos(angle)
                    let yPos = center.y + (radius + 28) * sin(angle)
                    
                    Text(data[i].muscle)
                        .font(.caption2).bold()
                        .position(x: xPos, y: yPos)
                }
            }
        }
    }
}

// Keep RadarWebShape and RadarDataShape below as they were...
struct RadarWebShape: Shape {
    let sides: Int; let radius: Double
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for i in 0..<sides {
            let angle = (Double(i) * (360 / Double(sides)) - 90) * .pi / 180
            let pt = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

struct RadarDataShape: Shape {
    let data: [MuscleVolumeData]; let maxVolume: Double; let radius: Double
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for i in 0..<data.count {
            let val = maxVolume == 0 ? 0 : (data[i].volume / maxVolume)
            let angle = (Double(i) * (360 / Double(data.count)) - 90) * .pi / 180
            let pt = CGPoint(x: center.x + (radius * val) * cos(angle), y: center.y + (radius * val) * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

struct MuscleVolumeData: Identifiable {
    let muscle: String; let volume: Double; var id: String { muscle }
}
