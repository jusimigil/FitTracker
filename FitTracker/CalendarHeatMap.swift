import SwiftUI

struct CalendarHeatmap: View {
    @EnvironmentObject var dataManager: DataManager
    
    // Config: Show last 15 weeks
    let weeks = 15
    let daysInWeek = 7
    
    // Helper: Get today's date stripped of time
    var today: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    // Helper: Get the start date (15 weeks ago)
    var startDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: -(weeks - 1), to: today)!
        // Align to previous Sunday so the grid looks square
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Consistency Streak")
                .font(.headline)
                .padding(.bottom, 5)
            
            // The Grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(0..<weeks, id: \.self) { weekIndex in
                        VStack(spacing: 4) {
                            ForEach(0..<daysInWeek, id: \.self) { dayIndex in
                                let date = getDate(week: weekIndex, day: dayIndex)
                                let volume = getVolume(for: date)
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(getColor(volume: volume))
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                }
            }
            // Add a legend at the bottom
            HStack {
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                ForEach([0, 1000, 5000, 10000], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(getColor(volume: Double(level) + 1))
                        .frame(width: 10, height: 10)
                }
                
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 5)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // --- Helpers ---
    
    // Calculate the exact date for a specific square in the grid
    func getDate(week: Int, day: Int) -> Date {
        let startOfWeek = Calendar.current.date(byAdding: .day, value: -Int(Calendar.current.component(.weekday, from: startDate)) + 1, to: startDate)!
        let offset = (week * 7) + day
        return Calendar.current.date(byAdding: .day, value: offset, to: startOfWeek)!
    }
    
    // Check if we worked out on this date and return the total volume
    func getVolume(for date: Date) -> Double {
        let workoutsOnDay = dataManager.workouts.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
        return workoutsOnDay.reduce(0) { $0 + $1.totalVolume }
    }
    
    // Determine color intensity based on volume
    func getColor(volume: Double) -> Color {
        if volume == 0 { return Color.gray.opacity(0.2) } // Empty
        if volume < 2000 { return Color.green.opacity(0.3) }
        if volume < 5000 { return Color.green.opacity(0.5) }
        if volume < 10000 { return Color.green.opacity(0.7) }
        return Color.green // Beast mode
    }
}
