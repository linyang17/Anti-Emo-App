import SwiftUI


struct SettingView: View {
	@EnvironmentObject private var appModel: AppViewModel
	@AppStorage("selectedLanguage") var selectedLanguage: String = "en"
	
	var body: some View {
		List {
			if let stats = appModel.userStats {
				
				Section("Notifications") {
					// TODO: add more detailed notification categories
					Toggle("All", isOn: Binding(
						get: { stats.notificationsEnabled },
						set: { newValue in
						stats.notificationsEnabled = newValue
					if newValue {
						appModel.requestNotifications()
					} else {
						appModel.persistState()
				}
				}
				))
				}
				
				Section("Language") {
					Picker("Language", selection: $selectedLanguage) {
						Text("English").tag("en")
						Text("中文").tag("zh")
					}
					// TODO: complete language switch and support to 中文（zh）
					// TODO: add privacy note
				}
			}
		}
		.navigationTitle("Settings")
		.alert("Permission denied.", isPresented: Binding(
			get: { appModel.shouldShowNotificationSettingsPrompt },
			set: { appModel.shouldShowNotificationSettingsPrompt = $0 }
		)) {
			Button("Go to settings") { appModel.openNotificationSettings() }
			Button("Later", role: .cancel) { }
		} message: {
			Text("Please allow notifications in settings.")
		}
	}
}
