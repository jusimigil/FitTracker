import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        TabView {
            HistoryView()
                .tabItem {
                    Label("Journal", systemImage: "list.bullet.clipboard")
                }
            
            ChartsView()
                .tabItem {
                    Label("Progress", systemImage: "chart.xyaxis.line")
                }
            
            // New Map Tab
            WorkoutMapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
        }
        .tint(.blue)
    }
}
