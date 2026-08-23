import SwiftUI

struct CalendarHeatmap: View {
    @EnvironmentObject var dataManager: DataManager
    
    // Callback for interactivity
    var onDateSelected: ((Date) -> Void)?
    
    // Config
    let weeks = 15
    let daysInWeek = 7
    var today: Date { Calendar.current.startOfDay(for: Date()) }
    var startDate: Date { Calendar.current.date(byAdding: .weekOfYear, value: -(weeks - 1), to: today)! }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Consistency Streak")
                .font(.headline)
                .padding(.bottom, 5)
            
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
                                    .onTapGesture {
                                        // Tap logic: Only act if there's volume or if user wants to see empty days
                                        onDateSelected?(date)
                                    }
                            }
                        }
                    }
                }
            }
            
            HStack {
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                ForEach([0, 1000, 5000, 10000], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            getColor(
                                volume: dataManager.kilograms(
                                    fromDisplayedWeight: Double(level) + 1
                                )
                            )
                        )
                        .frame(width: 10, height: 10)
                };                Text("More").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.top, 5)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    func getDate(week: Int, day: Int) -> Date {
        let startOfWeek = Calendar.current.date(byAdding: .day, value: -Int(Calendar.current.component(.weekday, from: startDate)) + 1, to: startDate)!
        let offset = (week * 7) + day
        return Calendar.current.date(byAdding: .day, value: offset, to: startOfWeek)!
    }
    
    func getVolume(for date: Date) -> Double {
        let workoutsOnDay = dataManager.completedWorkouts.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }

        return workoutsOnDay.reduce(0) {
            $0 + $1.totalVolume
        }
    }
    
    func getColor(volume: Double) -> Color {
        let displayedVolume =
            dataManager.displayedWeight(
                fromKilograms: volume
            )

        if volume == 0 {
            return Color.gray.opacity(0.2)
        }

        if displayedVolume < 2000 {
            return Color.green.opacity(0.3)
        }

        if displayedVolume < 5000 {
            return Color.green.opacity(0.5)
        }

        if displayedVolume < 10000 {
            return Color.green.opacity(0.7)
        }

        return Color.green
    }}
