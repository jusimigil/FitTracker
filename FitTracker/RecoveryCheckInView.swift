import SwiftUI

struct RecoveryCheckInView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var recompManager = RecompManager.shared
    
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
            VStack(spacing: 8) {
                Text("Trainer's Plan for Today:")
                    .font(.caption).bold().foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Text(recompManager.getFlexibleTarget(recoveryScore: Int(recoveryScore)))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding(.horizontal)
                    .transition(.opacity) // Smooth animation
                    .id(recoveryScore) // Forces refresh on change
            }
            
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
    
    func saveCheckIn() {
        // 1. Save Today's Date String (e.g., "10/24/2025")
        let today = Date().formatted(date: .numeric, time: .omitted)
        lastCheckInDate = today
        
        // 2. Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        dismiss()
    }
}
