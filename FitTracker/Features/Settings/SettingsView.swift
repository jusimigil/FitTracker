import SwiftUI
import UserNotifications
internal import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var recompManager = RecompManager.shared
    
    // Notification State
    @AppStorage("dailyReminderEnabled") var dailyReminderEnabled = false
    
    // File Importer State
    @State private var showingImporter = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // 1. PREFERENCES (NEW)
                Section(header: Text("Preferences")) {
                    Picker("Weight Unit", selection: $dataManager.weightUnit) {
                        Text("Pounds (lbs)").tag(WeightUnit.lbs)
                        Text("Kilograms (kg)").tag(WeightUnit.kg)
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Daily Reminder (8 AM)", isOn: $dailyReminderEnabled)
                        .onChange(of: dailyReminderEnabled) { _, isEnabled in
                            if isEnabled {
                                scheduleDailyNotification()
                            } else {
                                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyCheckIn"])
                            }
                        }
                }
                
                // 2. RECOMP STRATEGY
                Section(header: Text("Recomp Strategy"), footer: Text(recompManager.currentFocus.description)) {
                    Picker("Current Focus", selection: $recompManager.currentFocus) {
                        ForEach(RecompFocus.allCases) { focus in
                            Text(focus.rawValue).tag(focus)
                        }
                    }
                }
                
                // 3. DATA
                Section(header: Text("Data")) {
                    ShareLink(item: generateExportURL()) {
                        Label("Backup Data (Export JSON)", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { showingImporter = true }) {
                        Label("Restore Data (Import JSON)", systemImage: "square.and.arrow.down")
                            .foregroundStyle(.red)
                    }
                }
                
                // 4. INTEGRATIONS
                Section {
                    Button("Sync Apple Watch Runs") {
                        HealthManager.shared.syncWorkouts(into: dataManager)
                    }
                }
            }
            .navigationTitle("Settings")
            
            // Logic to handle importing JSON files
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    if dataManager.restoreData(from: url) {
                        alertMessage = "Data restored successfully!"
                    } else {
                        alertMessage = "Failed to restore data."
                    }
                case .failure(let error):
                    alertMessage = "Import failed: \(error.localizedDescription)"
                }
                showAlert = true
            }
            .alert("Restore", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Notification Logic
    func scheduleDailyNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Time to Check In!"
        content.body = "Log your recovery and crush your workout today."
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        // This trigger works even if the app is closed
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyCheckIn", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Daily notification scheduled for 8 AM.")
            }
        }
    }
    
    // Helper to create the backup file
    func generateExportURL() -> URL {
        let fileName = "FitTracker_Backup.json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let backupData = BackupData(workouts: dataManager.workouts, bodyMetrics: dataManager.bodyMetrics)
        try? JSONEncoder().encode(backupData).write(to: url)
        return url
    }
}
