import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingImporter = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - 1. Health Sync Section
                Section(header: Text("Health Integrations"), footer: Text("Import runs & swims from Apple Health.")) {
                    Button(action: {
                        // 1. Trigger permissions
                        HealthManager.shared.requestAuthorization()
                        // 2. Run the NEW sync function (renamed from syncRuns)
                        HealthManager.shared.syncWorkouts(into: dataManager)
                        
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }) {
                        HStack {
                            Image(systemName: "applewatch")
                                .foregroundStyle(.blue)
                            Text("Sync Workouts (Runs/Swims)")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                // MARK: - 2. Data Management
                Section(header: Text("Data Management")) {
                    // Export
                    ShareLink(item: generateExportURL()) {
                        Label("Backup Data (Export JSON)", systemImage: "square.and.arrow.up")
                    }
                    
                    // Import
                    Button(action: { showingImporter = true }) {
                        Label("Restore Data (Import JSON)", systemImage: "square.and.arrow.down")
                            .foregroundStyle(.red)
                    }
                }
                
                Section(footer: Text("Importing a backup will REPLACE all current data.")) { }
            }
            .navigationTitle("Settings")
            
            // MARK: - File Importer
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    if dataManager.restoreData(from: url) {
                        alertMessage = "Data restored successfully!"
                    } else {
                        alertMessage = "Failed to restore data. Check file format."
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
    
    func generateExportURL() -> URL {
        let fileName = "FitTracker_Backup_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // This will now work because we restored BackupData in Step 1
        let backupData = BackupData(workouts: dataManager.workouts, bodyMetrics: dataManager.bodyMetrics)
        
        if let data = try? JSONEncoder().encode(backupData) {
            try? data.write(to: url)
        }
        return url
    }
}
