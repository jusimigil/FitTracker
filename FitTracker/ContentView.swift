import SwiftUI
import HealthKit

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        // The red button is deleted from here
        
        TabView {
            
            TodayView()
                            .environmentObject(dataManager)
                            .tabItem {
                                Label("Today", systemImage: "sun.max.fill")
                            }
            
            HistoryView()
                .tabItem {
                    Label("Journal", systemImage: "list.bullet.clipboard")
                }
            
        
            ChartsView()
                .tabItem {
                    Label("Progress", systemImage: "chart.xyaxis.line")
                }
            
            WorkoutMapView() // Ensure you have this view, or remove this block if not
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
            
            SettingsView() // This is where your Sync button should live permanently
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .onAppear {
                    // Start syncing runs and swims every 5 minutes
                    HealthManager.shared.startAutoSync(dataManager: dataManager)
                }
        }
    }
}
