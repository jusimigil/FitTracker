import SwiftUI
import Foundation

struct RecoveryEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var score: Double
}

struct RecoveryCheckInView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var recompManager = RecompManager.shared
    @ObservedObject var healthManager = HealthManager.shared
    
    // Binds directly to the phone's storage
    @AppStorage("dailyRecoveryScore") var recoveryScore: Double = 8.0
    @AppStorage("lastCheckInDate") var lastCheckInDate: String = ""

    
    var body: some View {
        VStack(spacing: 30) {
            
            // Icon
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 70))
                .foregroundStyle(.pink)
                .padding(.top, 40)
            
            VStack(spacing: 10) {
                Text("Daily Check-In")
                    .font(.largeTitle).bold()
                Text("How is your body feeling today?")
                    .foregroundStyle(.secondary)
            }
            
            Divider().padding(.horizontal)
            
            // Slider Section
            VStack(spacing: 20) {
                HStack {
                    Text("Sore / Tired")
                    Spacer()
                    Text("Fresh / Strong")
                }
                .font(.caption).bold().foregroundStyle(.secondary)
                
                // Big Score Display
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(Int(recoveryScore))")
                        .font(.system(size: 60, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreColor)
                    Text("/ 10")
                        .font(.title2).foregroundStyle(.secondary)
                }
                
                Slider(value: $recoveryScore, in: 1...10, step: 1)
                    .tint(scoreColor)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(20)
            .padding(.horizontal)
            
            // SMART INSIGHT (Live Feedback)
            // This applies the "Logic/ML" immediately so user sees the plan changing
            // MARK: - Sleep

            VStack(alignment: .leading, spacing: 10) {
                
                HStack {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundStyle(.indigo)
                    
                    Text("Sleep")
                        .font(.headline)
                    
                    Spacer()
                    
                    if healthManager.lastNightSleepHours > 0 {
                        Text(
                            "\(healthManager.lastNightSleepHours, specifier: "%.1f") h"
                        )
                        .font(.headline)
                        .fontWeight(.bold)
                    } else {
                        Text("No data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if healthManager.lastNightSleepHours > 0 {
                    HStack {
                        Text(
                            sleepSummary(
                                hours: healthManager.lastNightSleepHours
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("Apple Health")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(
                        "Wear your connected device overnight to track sleep."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(
                RoundedRectangle(cornerRadius: 16)
            )
            .padding(.horizontal)
            
            Spacer()
            
            // Save Button
            Button(action: saveCheckIn) {
                Text("Confirm Status")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(Color.blue)
                    .cornerRadius(15)
            }
            .padding()
        }
        .interactiveDismissDisabled() // Forces user to complete check-in
    }
    
    // Dynamic Color
    var scoreColor: Color {
        if recoveryScore < 4 { return .red }
        if recoveryScore < 7 { return .orange }
        return .green
    }
    
    
    private func sleepSummary(hours: Double) -> String {
        
        if hours < 6 {
            return "Short sleep"
        }
        
        if hours < 7 {
            return "Below your usual sleep range"
        }
        
        if hours < 9 {
            return "Good sleep duration"
        }
        
        return "Long sleep"
    }
    
    func saveCheckIn() {
        let now = Date()
        
        let calendar = Calendar.current
        
        // Check whether today's recovery entry already exists.
        if let index = dataManager.recoveryHistory.firstIndex(
            where: {
                calendar.isDate(
                    $0.date,
                    inSameDayAs: now
                )
            }
        ) {
            // Update today's existing score.
            dataManager.recoveryHistory[index].score = recoveryScore
        } else {
            // Create a new daily entry.
            let entry = RecoveryEntry(
                date: now,
                score: recoveryScore
            )
            
            dataManager.recoveryHistory.append(entry)
        }
        
        // Keep the existing daily-login system working.
        lastCheckInDate = now.formatted(
            date: .numeric,
            time: .omitted
        )
        
        dataManager.save()
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        dismiss()
    }}
