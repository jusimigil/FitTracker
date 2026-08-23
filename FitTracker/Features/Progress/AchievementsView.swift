import SwiftUI

struct AchievementsView: View {
    
    @EnvironmentObject var dataManager: DataManager
    
    private var achievements: [Achievement] {
        AchievementManager.shared.allAchievements(
            dataManager: dataManager
        )
    }
    
    private var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // MARK: - Header
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Achievements")
                            .font(.headline)
                        
                        Text(
                            "\(unlockedCount) / \(achievements.count) unlocked"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.orange)
                        .font(.title2)
                }
                
                // MARK: - Progress
                
                ProgressView(
                    value: Double(unlockedCount),
                    total: Double(achievements.count)
                )
                .tint(.orange)
                
                // MARK: - Achievement List
                
                VStack(spacing: 10) {
                    ForEach(achievements) { achievement in
                        AchievementRow(
                            achievement: achievement
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Achievement Row

struct AchievementRow: View {
    
    let achievement: Achievement
    
    var body: some View {
        HStack(spacing: 12) {
            
            // MARK: Icon
            
            ZStack {
                Circle()
                    .fill(
                        achievement.isUnlocked
                        ? Color.orange.opacity(0.15)
                        : Color.gray.opacity(0.12)
                    )
                    .frame(width: 46, height: 46)
                
                Image(systemName: achievement.icon)
                    .foregroundStyle(
                        achievement.isUnlocked
                        ? .orange
                        : .secondary
                    )
            }
            
            // MARK: Text
            
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                
                HStack {
                    Text(achievement.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if achievement.isUnlocked {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                
                if !achievement.isUnlocked {
                    ProgressView(
                        value: achievement.progress
                    )
                    .tint(.orange)
                    .padding(.top, 2)
                    
                    Text(achievement.progressText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                } else {
                    Text(
                        achievement.earnedDate.map {
                            "Earned " +
                            $0.formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                        } ?? achievement.progressText
                    )
                    .font(.caption2)
                    .foregroundStyle(.green)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            Color(.secondarySystemBackground)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
        .opacity(
            achievement.isUnlocked ? 1.0 : 0.75
        )
    }
}
