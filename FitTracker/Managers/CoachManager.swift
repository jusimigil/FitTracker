import Foundation

struct CoachRecommendation {
    let headline: String
    let message: String
    let focus: String
}

final class CoachManager {
    
    static let shared = CoachManager()
    
    private init() {}
    
    func recommendation(
        from context: CoachContext
    ) -> CoachRecommendation {
        
        // MARK: - 1. Recovery is the highest priority
        
        if context.recoveryScore < 4 {
            return CoachRecommendation(
                headline: "Recovery comes first today.",
                message: "Your recovery is low. Keep training light or take a rest day.",
                focus: "Recovery"
            )
        }
        
        // MARK: - 2. Poor sleep
        
        if let sleep = context.sleepHours,
           sleep < 5.5 {
            
            if context.recoveryScore < 7 {
                return CoachRecommendation(
                    headline: "Keep today's training light.",
                    message: "Your sleep was short and recovery is moderate. Avoid pushing intensity or adding extra volume.",
                    focus: "Recovery"
                )
            }
            
            return CoachRecommendation(
                headline: "Train, but keep it controlled.",
                message: "Your recovery looks good, but you only got \(formatSleep(sleep)) of sleep. Stick to your normal plan without adding unnecessary fatigue.",
                focus: "Manage fatigue"
            )
        }
        
        // MARK: - 3. High training load + moderate recovery
        
        if context.trainingLoad == .high &&
            context.recoveryScore < 7 {
            
            return CoachRecommendation(
                headline: "Keep today's session controlled.",
                message: "Your recent training load is high and recovery is only moderate. Avoid adding extra volume today.",
                focus: "Manage fatigue"
            )
        }
        
        // MARK: - 4. Declining recovery
        
        if context.recoveryTrend == "Declining" &&
            context.recoveryScore < 7 {
            
            return CoachRecommendation(
                headline: "Ease off today.",
                message: "Your recovery has been trending down. Keep effort controlled and avoid unnecessary volume.",
                focus: "Recovery"
            )
        }
        
        // MARK: - 5. Weak muscle + good recovery
        
        if let muscle = context.weakestMuscle,
           let sets = context.weakestMuscleSets,
           let target = context.weakestMuscleTarget,
           sets < target {
            
            if context.recoveryScore >= 8 &&
                context.trainingLoad != .high {
                
                return CoachRecommendation(
                    headline: "Prioritize \(muscle.rawValue) today.",
                    message: buildMuscleMessage(
                        muscle: muscle,
                        sleepHours: context.sleepHours,
                        goodRecovery: true
                    ),
                    focus: muscle.rawValue
                )
            }
            
            if context.recoveryScore >= 6 {
                return CoachRecommendation(
                    headline: "Prioritize \(muscle.rawValue), but keep it controlled.",
                    message: buildMuscleMessage(
                        muscle: muscle,
                        sleepHours: context.sleepHours,
                        goodRecovery: false
                    ),
                    focus: muscle.rawValue
                )
            }
        }
        
        // MARK: - 6. Strong recovery
        
        if context.recoveryScore >= 8 &&
            context.recoveryTrend != "Declining" {
            
            return CoachRecommendation(
                headline: "You're ready to train.",
                message: "Recovery looks strong. Follow your progression plan and focus on high-quality sets.",
                focus: "Progress"
            )
        }
        
        // MARK: - 7. Moderate recovery
        
        if context.recoveryScore >= 6 {
            return CoachRecommendation(
                headline: "Stay on plan.",
                message: "Recovery looks manageable. Follow your normal workout and let RPE guide your intensity.",
                focus: "Consistency"
            )
        }
        
        // MARK: - 8. Default
        
        return CoachRecommendation(
            headline: "Keep today's training simple.",
            message: "Use RPE to guide your intensity and avoid unnecessary fatigue.",
            focus: "Consistency"
        )
    }
    
    private func buildMuscleMessage(
        muscle: MuscleGroup,
        sleepHours: Double?,
        goodRecovery: Bool
    ) -> String {
        
        if let sleep = sleepHours {
            
            if sleep >= 7 {
                return "\(muscle.rawValue) is behind your weekly target and your recovery looks strong. You also got \(formatSleep(sleep)) of sleep, so this is a good opportunity to bring it up."
            }
            
            if sleep < 6 {
                return "\(muscle.rawValue) is behind your weekly target, but your sleep was short. Bring it up without adding unnecessary fatigue."
            }
            
            return "\(muscle.rawValue) is behind your weekly target. Your recovery is sufficient, so bring it up while keeping effort controlled."
        }
        
        if goodRecovery {
            return "\(muscle.rawValue) is behind your weekly target and your recovery looks strong. This is a good opportunity to bring it up."
        }
        
        return "\(muscle.rawValue) is behind your weekly target, but your current recovery suggests you should avoid pushing extra volume."
    }

    private func formatSleep(
        _ hours: Double
    ) -> String {
        
        let wholeHours = Int(hours)
        let minutes = Int(
            (hours - Double(wholeHours)) * 60
        )
        
        return "\(wholeHours)h \(minutes)m"
    }
}
