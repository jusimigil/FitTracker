import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var actionTitle: String?
    var action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
            
            if let actionTitle,
               let action {
                
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(30)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }
}
