import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        // ⚠️ IMPORTANT: No NavigationStack here!
        // The TabView must be the "Boss" (Top Level).
        TabView {
            // Tab 1: The Home Page
            HistoryView()
                .tabItem {
                    Label("Journal", systemImage: "list.bullet.clipboard")
                }
            
            // Tab 2: The Graphs Page
            ChartsView()
                .tabItem {
                    Label("Progress", systemImage: "chart.xyaxis.line")
                }
        }
        .tint(.blue) // This forces the active tab to be blue
    }
}
