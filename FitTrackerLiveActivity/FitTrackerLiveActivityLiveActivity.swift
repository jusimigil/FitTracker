import ActivityKit
import WidgetKit
import SwiftUI

struct FitTrackerLiveActivityLiveActivity: Widget {

    var body: some WidgetConfiguration {

        ActivityConfiguration(
            for: WorkoutActivityAttributes.self
        ) { context in

            // MARK: - Lock Screen

            VStack(alignment: .leading, spacing: 8) {

                HStack {
                    Text("ACTIVE WORKOUT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(
                        context.attributes.startedAt,
                        style: .timer
                    )
                    .font(.headline)
                    .monospacedDigit()
                }

                Text(context.attributes.workoutName)
                    .font(.headline)

                Text(context.state.currentExercise)
                    .font(.subheadline)

                if context.state.isResting,
                   let restEndTime = context.state.restEndTime {

                    HStack {

                        Image(systemName: "timer")
                            .foregroundStyle(.orange)

                        Text("Rest")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Spacer()

                        Text(
                            restEndTime,
                            style: .timer
                        )
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                    }

                } else if context.state.totalSets > 0 {

                    Text(
                        "Set \(context.state.currentSet) of \(context.state.totalSets)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding()

        } dynamicIsland: { context in

            DynamicIsland {
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("ACTIVE WORKOUT")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Text(
                            context.attributes.startedAt,
                            style: .timer
                        )
                        .font(.title3)
                        .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        Text(context.attributes.workoutName)
                            .font(.headline)

                        Text(context.state.currentExercise)
                            .font(.subheadline)

                        if context.state.isResting,
                           let restEndTime = context.state.restEndTime {

                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .foregroundStyle(.orange)

                                Text("Rest")
                                    .foregroundStyle(.orange)

                                Text(
                                    restEndTime,
                                    style: .timer
                                )
                                .foregroundStyle(.orange)
                                .monospacedDigit()
                            }

                        } else if context.state.totalSets > 0 {

                            Text(
                                "Set \(context.state.currentSet) of \(context.state.totalSets)"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

            } compactTrailing: {
                if context.state.isResting,
                   let restEndTime = context.state.restEndTime {

                    Text(
                        restEndTime,
                        style: .timer
                    )
                    .font(.caption2)
                    .monospacedDigit()

                } else {

                    Text(
                        context.attributes.startedAt,
                        style: .timer
                    )
                    .font(.caption2)
                    .monospacedDigit()
                }

            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.caption2)
            }
        }
    }
}
