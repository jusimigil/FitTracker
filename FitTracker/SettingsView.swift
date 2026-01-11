import SwiftUI
internal import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var recompManager = RecompManager.shared
    
    // State for File Importer/Alerts
    @State private var showingImporter = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - 1. RECOMP STRATEGY
                Section(header: Text("Recomp Strategy"), footer: Text(recompManager.currentFocus.description)) {
                    Picker("Current Focus", selection: $recompManager.currentFocus) {
                        ForEach(RecompFocus.allCases) { focus in
                            Text(focus.rawValue).tag(focus)
                        }
                    }
                }
                
                // MARK: - 2. DATA MANAGEMENT
                Section(header: Text("Data")) {
                    ShareLink(item: generateExportURL()) {
                        Label("Backup Data (Export JSON)", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { showingImporter = true }) {
                        Label("Restore Data (Import JSON)", systemImage: "square.and.arrow.down")
                            .foregroundStyle(.red)
                    }
                }
                
                // MARK: - 3. INTEGRATIONS
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
    
    // Helper to create the backup file
    func generateExportURL() -> URL {
        let fileName = "FitTracker_Backup.json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let backupData = BackupData(workouts: dataManager.workouts, bodyMetrics: dataManager.bodyMetrics)
        try? JSONEncoder().encode(backupData).write(to: url)
        return url
    }
}
