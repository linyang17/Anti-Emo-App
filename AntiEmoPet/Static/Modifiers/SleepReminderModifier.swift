import SwiftUI

/// A reusable ViewModifier for displaying sleep reminder alerts
struct SleepReminderModifier: ViewModifier {
	@Binding var isPresented: Bool
	let onDismiss: () -> Void
	
	func body(content: Content) -> some View {
		content
			.alert("Time for bed...",
				   isPresented: $isPresented) {
				Button("Okay", role: .cancel) {
					onDismiss()
				}
			} message: {
				Text("It seems quite late for you, Lumio is also going to take some rest - we shall catch up tomorrow!")
			}
	}
}

extension View {
	/// Applies a sleep reminder alert modifier
	func sleepReminder(isPresented: Binding<Bool>, onDismiss: @escaping () -> Void) -> some View {
		modifier(SleepReminderModifier(isPresented: isPresented, onDismiss: onDismiss))
	}
}

