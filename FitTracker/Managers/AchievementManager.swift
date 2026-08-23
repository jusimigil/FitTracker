import Foundation
import SwiftUI

// MARK: - Achievement

struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let icon: String
    
    let isUnlocked: Bool
    let progress: Double
    let progressText: String
    let earnedDate: Date?
}

// MARK: - Achievement Manager

final class AchievementManager {
    
    static let shared = AchievementManager()
    
    private init() {}
    
    // MARK: - Public
    
    func allAchievements(
        dataManager: DataManager
    ) -> [Achievement] {
        
        return [
            firstWorkout(dataManager),
            firstPR(dataManager),
            workoutsMilestone(
                dataManager: dataManager,
                target: 10,
                id: "10_workouts",
                title: "10 Workouts"
            ),
            workoutsMilestone(
                dataManager: dataManager,
                target: 25,
                id: "25_workouts",
                title: "25 Workouts"
            ),
            sevenDayStreak(dataManager),
            firstProgression(dataManager),
            weeklyConsistency(dataManager),
            fivePRs(dataManager)
        ]
    }
    
    // MARK: - 1. First Workout
    
    private func firstWorkout(
        _ dataManager: DataManager
    ) -> Achievement {
        
        let completed = completedWorkouts(dataManager)
        let firstDate = completed.map(\.date).min()
        
        return Achievement(
            id: "first_workout",
            title: "First Workout",
            description: "Complete your first workout.",
            icon: "figure.strengthtraining.traditional",
            isUnlocked: !completed.isEmpty,
            progress: completed.isEmpty ? 0 : 1,
            progressText: completed.isEmpty
                ? "0 / 1 workout"
                : "Completed",
            earnedDate: firstDate
        )
    }
    
    // MARK: - 2. First PR
    
    private func firstPR(
        _ dataManager: DataManager
    ) -> Achievement {
        
        let firstPR = dataManager.personalRecords.min {
            $0.date < $1.date
        }
        
        return Achievement(
            id: "first_pr",
            title: "First PR",
            description: "Earn your first personal record.",
            icon: "trophy.fill",
            isUnlocked: firstPR != nil,
            progress: firstPR == nil ? 0 : 1,
            progressText: firstPR == nil
                ? "0 / 1 PR"
                : "Completed",
            earnedDate: firstPR?.date
        )
    }
    
    // MARK: - 3 & 4. Workout Milestones
    
    private func workoutsMilestone(
        dataManager: DataManager,
        target: Int,
        id: String,
        title: String
    ) -> Achievement {
        
        let completedCount =
            completedWorkouts(dataManager).count
        
        let progress = min(
            Double(completedCount) / Double(target),
            1.0
        )
        
        let earnedDate: Date?
        
        if completedCount >= target {
            let sortedDates =
                completedWorkouts(dataManager)
                    .sorted { $0.date < $1.date }
                    .map(\.date)
            
            earnedDate = sortedDates[target - 1]
        } else {
            earnedDate = nil
        }
        
        return Achievement(
            id: id,
            title: title,
            description: "Complete \(target) workouts.",
            icon: "figure.strengthtraining.traditional",
            isUnlocked: completedCount >= target,
            progress: progress,
            progressText: "\(min(completedCount, target)) / \(target) workouts",
            earnedDate: earnedDate
        )
    }
    
    // MARK: - 5. Seven-Day Streak
    
    private func sevenDayStreak(
        _ dataManager: DataManager
    ) -> Achievement {
        
        let workoutDays = Set(
            completedWorkouts(dataManager).map {
                Calendar.current.startOfDay(
                    for: $0.date
                )
            }
        )
        
        let bestStreak = longestStreak(
            workoutDays: workoutDays
        )
        
        let earnedDate = dateWhenStreakReached(
            workoutDays: workoutDays,
            target: 7
        )
        
        return Achievement(
            id: "seven_day_streak",
            title: "7-Day Streak",
            description: "Train on 7 consecutive days.",
            icon: "flame.fill",
            isUnlocked: bestStreak >= 7,
            progress: min(
                Double(bestStreak) / 7.0,
                1.0
            ),
            progressText: "\(min(bestStreak, 7)) / 7 days",
            earnedDate: earnedDate
        )
    }
    
    // MARK: - 6. First Progression
    
    private func firstProgression(
        _ dataManager: DataManager
    ) -> Achievement {
        
        let progressionDate =
            findFirstProgressionDate(
                dataManager: dataManager
            )
        
        return Achievement(
            id: "first_progression",
            title: "First Progression",
            description: "Improve an exercise's estimated 1RM.",
            icon: "chart.line.uptrend.xyaxis",
            isUnlocked: progressionDate != nil,
            progress: progressionDate == nil ? 0 : 1,
            progressText: progressionDate == nil
                ? "No progression yet"
                : "Completed",
            earnedDate: progressionDate
        )
    }
    
    // MARK: - 7. Weekly Consistency
    
    private func weeklyConsistency(
        _ dataManager: DataManager
    ) -> Achievement {
        
        let calendar = Calendar.current
        let now = Date()
        
        let weekStart =
            calendar.date(
                from: calendar.dateComponents(
                    [.yearForWeekOfYear, .weekOfYear],
                    from: now
                )
            ) ?? now
        
        let thisWeekCount =
            Set(
                completedWorkouts(dataManager)
                    .filter { $0.date >= weekStart }
                    .map {
                        calendar.startOfDay(for: $0.date)
                    }
            ).count
        
        let progress = min(
            Double(thisWeekCount) / 4.0,
            1.0
        )
        
        return Achievement(
            id: "weekly_consistency",
            title: "Weekly Consistency",
            description: "Train on 4 different days in one week.",
            icon: "calendar.badge.checkmark",
            isUnlocked: thisWeekCount >= 4,
            progress: progress,
            progressText: "\(min(thisWeekCount, 4)) / 4 days this week",
            earnedDate: thisWeekCount >= 4
                ? Date()
                : nil
        )
    }
    
    // MARK: - 8. Five PRs
    
    private func fivePRs(
        _ dataManager: DataManager
    ) -> Achievement {
        
        let count =
            dataManager.personalRecords.count
        
        let progress = min(
            Double(count) / 5.0,
            1.0
        )
        
        let earnedDate: Date?
        
        if count >= 5 {
            earnedDate =
                dataManager.personalRecords
                    .sorted { $0.date < $1.date }[4]
                    .date
        } else {
            earnedDate = nil
        }
        
        return Achievement(
            id: "five_prs",
            title: "5 PRs",
            description: "Earn 5 personal records.",
            icon: "trophy.circle.fill",
            isUnlocked: count >= 5,
            progress: progress,
            progressText: "\(min(count, 5)) / 5 PRs",
            earnedDate: earnedDate
        )
    }
    
    // MARK: - Helpers
    
    private func completedWorkouts(
        _ dataManager: DataManager
    ) -> [WorkoutSession] {
        dataManager.completedWorkouts
    }
    
    private func longestStreak(
        workoutDays: Set<Date>
    ) -> Int {
        
        guard !workoutDays.isEmpty else {
            return 0
        }
        
        let calendar = Calendar.current
        let sortedDays = workoutDays.sorted()
        
        var longest = 1
        var current = 1
        
        for index in 1..<sortedDays.count {
            guard let expectedNext =
                    calendar.date(
                        byAdding: .day,
                        value: 1,
                        to: sortedDays[index - 1]
                    )
            else {
                continue
            }
            
            if calendar.isDate(
                expectedNext,
                inSameDayAs: sortedDays[index]
            ) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        
        return longest
    }
    
    private func dateWhenStreakReached(
        workoutDays: Set<Date>,
        target: Int
    ) -> Date? {
        
        guard !workoutDays.isEmpty else {
            return nil
        }
        
        let calendar = Calendar.current
        let sortedDays = workoutDays.sorted()
        
        var current = 1
        
        for index in 1..<sortedDays.count {
            guard let expectedNext =
                    calendar.date(
                        byAdding: .day,
                        value: 1,
                        to: sortedDays[index - 1]
                    )
            else {
                continue
            }
            
            if calendar.isDate(
                expectedNext,
                inSameDayAs: sortedDays[index]
            ) {
                current += 1
                
                if current >= target {
                    return sortedDays[index]
                }
            } else {
                current = 1
            }
        }
        
        return nil
    }
    
    private func findFirstProgressionDate(
        dataManager: DataManager
    ) -> Date? {
        
        let workouts = completedWorkouts(dataManager)
            .sorted { $0.date < $1.date }
        
        // Group historical exercise performance.
        var best1RMByExercise: [String: Double] = [:]
        
        for workout in workouts {
            for exercise in workout.exercises {
                
                guard let bestSet =
                        exercise.sets.max(
                            by: {
                                estimatedOneRepMax(for: $0)
                                <
                                estimatedOneRepMax(for: $1)
                            }
                        )
                else {
                    continue
                }
                
                let current1RM =
                    estimatedOneRepMax(
                        for: bestSet
                    )
                
                let previousBest =
                    best1RMByExercise[
                        exercise.name
                    ] ?? 0
                
                if current1RM > previousBest {
                    if previousBest > 0 {
                        return workout.date
                    }
                    
                    best1RMByExercise[
                        exercise.name
                    ] = current1RM
                }
            }
        }
        
        return nil
    }
    
    private func estimatedOneRepMax(
        for set: WorkoutSet
    ) -> Double {
        
        guard set.weight > 0,
              set.reps > 0
        else {
            return 0
        }
        
        return set.weight *
            (1.0 + Double(set.reps) / 30.0)
    }
}
