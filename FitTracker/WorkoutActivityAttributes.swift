import Foundation
import ActivityKit

struct WorkoutActivityAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable {
        var currentExercise: String
        var currentSet: Int
        var totalSets: Int
        var isResting: Bool
        var restEndTime: Date?
    }

    var workoutName: String
    var startedAt: Date
}
