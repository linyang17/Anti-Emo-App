import SwiftUI

struct OnboardingCelebrationView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            
            Text("Congratulations!")
				.appFont(FontTheme.title2)
            
            Text("You've completed all the initial tasks! \n Ready to start your journey with Lumio?")
				.appFont(FontTheme.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Button {
                onDismiss()
            } label: {
                Text("Gooooooo!")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.pink, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

