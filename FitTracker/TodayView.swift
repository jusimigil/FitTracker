import SwiftUI

struct TodayView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var recompManager = RecompManager.shared
    @ObservedObject var healthManager = HealthManager.shared
    
    @State private var showRoutineSelection = false
    @State private var dailyRecoveryScore: Double = 8.0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - 1. TRAINER BRIEFING
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trainer Briefing").font(.headline).foregroundStyle(.secondary)
                        
                        HStack(alignment: .top) {
                            Image(systemName: "quote.opening").foregroundStyle(.purple)
                            Text(recompManager.getFlexibleTarget(recoveryScore: Int(dailyRecoveryScore)))
                                .font(.body).italic()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Recovery Status")
                                Spacer()
                                Text("\(Int(dailyRecoveryScore))/10").bold().foregroundStyle(.purple)
                            }
                            .font(.caption)
                            Slider(value: $dailyRecoveryScore, in: 1...10, step: 1).tint(.purple)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // MARK: - 2. SMART INSIGHTS
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Smart Insights").font(.headline).foregroundStyle(.secondary)
                        
                        // 1. Progressive Overload
                        HStack {
                            Image(systemName: "arrow.up.right.circle.fill").foregroundStyle(.green).font(.title2)
                            VStack(alignment: .leading) {
                                Text("Progressive Overload (Bench)").font(.caption).bold()
                                Text(recompManager.suggestProgressiveOverload(for: "Bench", dataManager: dataManager))
                                    .font(.subheadline)
                            }
                        }
                        
                        Divider()
                        
                        // 2. Muscle Balance (Upper vs Lower)
                        HStack {
                            Image(systemName: "scalemass.fill").foregroundStyle(.blue).font(.title2)
                            VStack(alignment: .leading) {
                                Text("Muscle Balance").font(.caption).bold()
                                Text(recompManager.analyzeSymmetry(dataManager: dataManager))
                                    .font(.subheadline)
                            }
                        }
                        
                        Divider()
                        
                        // 3. Weak Link Detector (NEW)
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.title2)
                            VStack(alignment: .leading) {
                                Text("Weak Link Detector").font(.caption).bold()
                                Text(recompManager.findLaggingMuscle(dataManager: dataManager))
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // MARK: - 3. STATUS GRID
                    let status = recompManager.analyzeStatus(dataManager: dataManager)
                    HStack(spacing: 15) {
                        // Volume Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "dumbbell.fill").foregroundStyle(.blue)
                                Text("Volume").font(.caption).bold().foregroundStyle(.secondary)
                            }
                            Text(status.status.components(separatedBy: " (").first ?? "Analyzing")
                                .font(.headline).minimumScaleFactor(0.8).foregroundStyle(status.color)
                            Text("Goal: \(recompManager.weeklySetTarget) sets/muscle")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        // Activity Card
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
            .sheet(isPresented: $showRoutineSelection) { RoutineSelectionView() }
        }
    }
}
