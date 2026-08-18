import SwiftUI
import HealthKit

struct ContentView: View {
    
    @EnvironmentObject var dataManager: DataManager
    
    @State private var selectedTab: AppTab = .today
    
    enum AppTab: Hashable {
        case today
        case journal
        case progress
        case map
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // MARK: Today
            
            TodayView()
                .environmentObject(dataManager)
                .tabItem {
                    Label(
                        "Today",
                        systemImage: "sun.max.fill"
                    )
                }
                .tag(AppTab.today)
            
            // MARK: Journal
            
            HistoryView()
                .tabItem {
                    Label(
                        "Journal",
                        systemImage: "list.bullet.clipboard"
                    )
                }
                .tag(AppTab.journal)
            
            // MARK: Progress
            
            ChartsView()
                .tabItem {
                    Label(
                        "Progress",
                        systemImage: "chart.xyaxis.line"
                    )
                }
                .tag(AppTab.progress)
            
            // MARK: Map
            
            WorkoutMapView()
                .tabItem {
                    Label(
                        "Map",
                        systemImage: "map.fill"
                    )
                }
                .tag(AppTab.map)
            
            // MARK: Settings
            
            SettingsView()
                .tabItem {
                    Label(
                        "Settings",
                        systemImage: "gear"
                    )
                }
                .tag(AppTab.settings)
        }
        .tint(.blue)
        .onAppear {
            // Start HealthKit synchronization once
            // when the main application interface appears.
            HealthManager.shared.startAutoSync(
                dataManager: dataManager
            )
        }
    }
}
