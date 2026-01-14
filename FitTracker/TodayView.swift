import SwiftUI

struct TodayView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var recompManager = RecompManager.shared
    @ObservedObject var healthManager = HealthManager.shared
    
    // Auto-Navigation
    @State private var path = NavigationPath()
    
    // UI State
    @State private var showRoutineSelection = false
    
    // MARK: - PERSISTENT DATA
    @AppStorage("dailyRecoveryScore") var dailyRecoveryScore: Double = 8.0
    @AppStorage("lastCheckInDate") var lastCheckInDate: String = ""
    @State private var showDailyCheckIn = false
    
    // Performance Cache
    @State private var cachedStatus: (status: String, color: Color) = ("Loading...", .gray)
    @State private var cachedWeakLink: String = "Analyzing..."
    @State private var cachedOverload: String = "--"
    @State private var cachedSymmetry: String = "--"
    
    // Computed Date String
    var todaysDate: String {
        Date().formatted(.dateTime.weekday(.wide).month().day())
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - 0. DATE HEADER (New)
                    HStack {
                        Text(todaysDate.uppercased())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // MARK: - 1. TRAINER BRIEFING
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Trainer Briefing")
                                .font(.headline).foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill").foregroundStyle(.pink)
                                Text("Recovery: \(Int(dailyRecoveryScore))/10")
                                    .font(.caption).bold()
                            }
                            .padding(6)
                            .background(Color.pink.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        HStack(alignment: .top) {
                            Image(systemName: "quote.opening").foregroundStyle(.purple)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(recompManager.getFlexibleTarget(recoveryScore: Int(dailyRecoveryScore)))
                                    .font(.body).italic()
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                if cachedWeakLink.contains("⚠️") {
                                    Divider()
                                    Text(cachedWeakLink)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // MARK: - 2. SMART INSIGHTS
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Smart Insights").font(.headline).foregroundStyle(.secondary)
                        
                        HStack {
                            Image(systemName: "arrow.up.right.circle.fill").foregroundStyle(.green).font(.title2)
                            VStack(alignment: .leading) {
                                Text("Progressive Overload (Bench)").font(.caption).bold()
                                Text(cachedOverload).font(.subheadline)
                            }
                        }
                        Divider()
                        HStack {
                            Image(systemName: "scalemass.fill").foregroundStyle(.blue).font(.title2)
                            VStack(alignment: .leading) {
                                Text("Muscle Balance").font(.caption).bold()
                                Text(cachedSymmetry).font(.subheadline)
                            }
                        }
                        Divider()
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.title2)
                            VStack(alignment: .leading) {
                                Text("Weak Link Detector").font(.caption).bold()
                                Text(cachedWeakLink).font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // MARK: - 3. STATUS GRID
                    HStack(spacing: 15) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "dumbbell.fill").foregroundStyle(.blue)
                                Text("Volume").font(.caption).bold().foregroundStyle(.secondary)
                            }
                            Text(cachedStatus.status.components(separatedBy: " (").first ?? "Analyzing")
                                .font(.headline).minimumScaleFactor(0.8).foregroundStyle(cachedStatus.color)
                            
                            Text("Goal: \(recompManager.weeklySetTarget) sets/muscle")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "figure.walk").foregroundStyle(.green)
                                Text("Activity").font(.caption).bold().foregroundStyle(.secondary)
                            }
                            Text("Step Goal").font(.headline)
                            Text("Target: \(recompManager.stepTarget) steps")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    
                    // MARK: - 4. START BUTTON
                    Button(action: { showRoutineSelection = true }) {
                        Label("Start Today's Workout", systemImage: "play.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .navigationTitle("Today")
            
            // MARK: - LOGIC
            .onAppear {
                calculateStats()
                checkDailyLogin()
            }
            .onChange(of: dataManager.workouts) { _, _ in calculateStats() }
            .sheet(isPresented: $showDailyCheckIn) {
                RecoveryCheckInView()
            }
            .sheet(isPresented: $showRoutineSelection) {
                RoutineSelectionView { newID in
                    path.append(newID)
                }
            }
            .navigationDestination(for: UUID.self) { workoutID in
                SessionDetailView(workoutID: workoutID)
            }
        }
    }
    
    func checkDailyLogin() {
        let today = Date().formatted(date: .numeric, time: .omitted)
        if lastCheckInDate != today {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showDailyCheckIn = true
            }
        }
    }
    
    func calculateStats() {
        cachedStatus = recompManager.analyzeStatus(dataManager: dataManager)
        cachedWeakLink = recompManager.findLaggingMuscle(dataManager: dataManager)
        cachedOverload = recompManager.suggestProgressiveOverload(for: "Bench Press", dataManager: dataManager)
        cachedSymmetry = recompManager.analyzeSymmetry(dataManager: dataManager)
    }
}
