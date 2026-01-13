import SwiftUI

struct TodayView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var recompManager = RecompManager.shared
    @ObservedObject var healthManager = HealthManager.shared
    
    // NEW: Listen for when the app comes back from background
    @Environment(\.scenePhase) var scenePhase
    
    // Auto-Navigation
    @State private var path = NavigationPath()
    
    // UI State
    @State private var showRoutineSelection = false
    
    // MARK: - PERSISTENT DATA (Memory)
    @AppStorage("dailyRecoveryScore") var dailyRecoveryScore: Double = 8.0
    @AppStorage("lastCheckInDate") var lastCheckInDate: String = ""
    
    // Popup State
    @State private var showDailyCheckIn = false
    
    // Performance Cache
    @State private var cachedStatus: (status: String, color: Color) = ("Loading...", .gray)
    @State private var cachedWeakLink: String = "Analyzing..."
    @State private var cachedOverload: String = "--"
    @State private var cachedSymmetry: String = "--"
    @State private var cachedDensity: String = "--"
    
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - 1. TRAINER BRIEFING
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Trainer Briefing")
                                .font(.headline).foregroundStyle(.secondary)
                            Spacer()
                            // Small indicator of today's score
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill").foregroundStyle(.pink)
                                Text("Recovery: \(Int(dailyRecoveryScore))/10")
                                    .font(.caption).bold()
                            }
                            .padding(6)
                            .background(Color.pink.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Combined Advice based on the CHECK-IN score
                        HStack(alignment: .top) {
                            Image(systemName: "quote.opening").foregroundStyle(.purple)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                // 1. Smart Advice (Based on stored Daily Score)
                                Text(recompManager.getFlexibleTarget(recoveryScore: Int(dailyRecoveryScore)))
                                    .font(.body).italic()
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                // 2. Weak Link Alert (Only if urgent)
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
                    
                    // MARK: - 2. ADVANCED SMART INSIGHTS (ML Powered)
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Smart Insights (ML Powered)").font(.headline).foregroundStyle(.secondary)
                        
                        // Insight A: Strength Trend (Linear Regression)
                        HStack(alignment: .top) {
                            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill").foregroundStyle(.green).font(.title2)
                            VStack(alignment: .leading) {
                                Text("Strength Trend (Bench Press)").font(.caption).bold()
                                Text(cachedOverload)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        Divider()
                        
                        // Insight B: Training Density (Efficiency Analysis)
                        HStack(alignment: .top) {
                            Image(systemName: "timer.circle.fill").foregroundStyle(.blue).font(.title2)
                            VStack(alignment: .leading) {
                                Text("Training Density").font(.caption).bold()
                                Text(cachedDensity)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        Divider()
                        
                        // Insight C: Muscle Balance
                        HStack(alignment: .top) {
                            Image(systemName: "scalemass.fill").foregroundStyle(.indigo).font(.title2)
                            VStack(alignment: .leading) {
                                Text("Muscle Balance").font(.caption).bold()
                                Text(cachedSymmetry).font(.subheadline)
                            }
                        }
                        
                        Divider()
                        
                        // Insight D: Weak Link Detector
                        HStack(alignment: .top) {
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
                    
                    // MARK: - 3. RECOMP STATUS GRID
                    HStack(spacing: 15) {
                        // Card A: Volume
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
                        
                        // Card B: Activity
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
                    
                    // MARK: - 4. ACTION BUTTON
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
            
            // MARK: - LOGIC TRIGGERS
            .onAppear {
                calculateStats()
                checkDailyLogin()
            }
            // NEW: Also check when the app becomes active (from background)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    checkDailyLogin()
                    calculateStats() // Refresh stats in case data changed externally
                }
            }
            .onChange(of: dataManager.workouts) { _, _ in calculateStats() }
            
            // MARK: - NAVIGATION & SHEETS
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
    
    // MARK: - LOGIC
    func checkDailyLogin() {
        // Create a simple date string (e.g., "10/24/2025")
        let today = Date().formatted(date: .numeric, time: .omitted)
        
        // If the saved date is NOT today, show the popup
        if lastCheckInDate != today {
            // Add a slight delay so the UI loads first
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
        cachedDensity = recompManager.analyzeTrainingDensity(dataManager: dataManager)
    }
}
