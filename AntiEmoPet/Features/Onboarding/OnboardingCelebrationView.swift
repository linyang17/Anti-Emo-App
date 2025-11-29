import SwiftUI

struct OnboardingCelebrationView: View {
	let onDismiss: () -> Void
	
	var body: some View {
		ZStack(alignment: .top) {
			Color.clear.ignoresSafeArea()
			
			VStack(spacing: 20) {
				
				LumioSay(text: "Congratulations!", style: FontTheme.title3)
				
				LumioSay(
					text: "You've completed all the initial tasks! \n Ready to start your journey with Lumio?",
					style: FontTheme.body
				)
				
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
		}
	}
}

