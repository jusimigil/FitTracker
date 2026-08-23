import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {

    static let shared = LiveActivityManager()

    private var activity: Activity<WorkoutActivityAttributes>?

    private init() {}

    // MARK: - Start

    func startWorkout(
        workoutName: String,
        startedAt: Date,
        currentExercise: String,
        currentSet: Int,
        totalSets: Int
    ) {

        print("🟣 LIVE ACTIVITY: startWorkout() called")
        print("🟣 Workout: \(workoutName)")
        print("🟣 Exercise: \(currentExercise)")
        print("🟣 Set: \(currentSet)/\(totalSets)")

        let authorization = ActivityAuthorizationInfo()

        print(
            "🟣 Live Activities enabled: \(authorization.areActivitiesEnabled)"
        )

        guard authorization.areActivitiesEnabled else {
            print(
                "🔴 LIVE ACTIVITY: areActivitiesEnabled == false"
            )
            return
        }

        // Check what ActivityKit thinks is already active.
        let existingActivities = Activity<WorkoutActivityAttributes>.activities

        print(
            "🟣 Existing activities: \(existingActivities.count)"
        )

        for existing in existingActivities {
            print(
                "🟣 Existing activity ID: \(existing.id)"
            )
        }

        // Don't start another workout activity.
        if let activity {
            print(
                "🟡 LIVE ACTIVITY: manager already has an active activity: \(activity.id)"
            )
            return
        }

        let attributes = WorkoutActivityAttributes(
            workoutName: workoutName,
            startedAt: startedAt
        )

        let state = WorkoutActivityAttributes.ContentState(
            currentExercise: currentExercise,
            currentSet: currentSet,
            totalSets: totalSets,
            isResting: false,
            restEndTime: nil
        )

        let content = ActivityContent(
            state: state,
            staleDate: nil
        )

        do {

            print(
                "🟣 LIVE ACTIVITY: calling Activity.request()"
            )

            let newActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )

            activity = newActivity

            print(
                "🟢 LIVE ACTIVITY STARTED: \(newActivity.id)"
            )

        } catch {

            print(
                "🔴 LIVE ACTIVITY FAILED TO START"
            )

            print(
                "🔴 Error: \(error)"
            )

            print(
                "🔴 Localized: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Update

    func updateWorkout(
        currentExercise: String,
        currentSet: Int,
        totalSets: Int
    ) {

        guard let activity else {
            print(
                "🟡 LIVE ACTIVITY: updateWorkout() called but no activity exists"
            )
            return
        }

        let state = WorkoutActivityAttributes.ContentState(
            currentExercise: currentExercise,
            currentSet: currentSet,
            totalSets: totalSets,
            isResting: false,
            restEndTime: nil
        )

        let content = ActivityContent(
            state: state,
            staleDate: nil
        )

        Task {
            await activity.update(content)

            print(
                "🟢 LIVE ACTIVITY UPDATED: \(activity.id)"
            )
        }
    }

    // MARK: - Rest

    func startRest(
        until endTime: Date,
        currentExercise: String,
        currentSet: Int,
        totalSets: Int
    ) {

        guard let activity else {
            print(
                "🟡 LIVE ACTIVITY: startRest() called but no activity exists"
            )
            return
        }

        let state = WorkoutActivityAttributes.ContentState(
            currentExercise: currentExercise,
            currentSet: currentSet,
            totalSets: totalSets,
            isResting: true,
            restEndTime: endTime
        )

        let content = ActivityContent(
            state: state,
            staleDate: endTime
        )

        Task {
            await activity.update(content)

            print(
                "🟢 LIVE ACTIVITY REST STARTED: \(activity.id)"
            )
        }
    }

    func endRest(
        currentExercise: String,
        currentSet: Int,
        totalSets: Int
    ) {

        updateWorkout(
            currentExercise: currentExercise,
            currentSet: currentSet,
            totalSets: totalSets
        )
    }

    // MARK: - End

    func endWorkout() {

        guard let activity else {
            print(
                "🟡 LIVE ACTIVITY: endWorkout() called but no activity exists"
            )
            return
        }

        let finalState = WorkoutActivityAttributes.ContentState(
            currentExercise: "",
            currentSet: 0,
            totalSets: 0,
            isResting: false,
            restEndTime: nil
        )

        let content = ActivityContent(
            state: finalState,
            staleDate: nil
        )

        Task {

            await activity.end(
                content,
                dismissalPolicy: .immediate
            )

            print(
                "🟢 LIVE ACTIVITY ENDED: \(activity.id)"
            )

            self.activity = nil
        }
    }
}
