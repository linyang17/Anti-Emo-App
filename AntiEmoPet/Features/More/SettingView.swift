import SwiftUI
import OSLog


struct SettingView: View {
	@EnvironmentObject private var appModel: AppViewModel
	@AppStorage("selectedLanguage") var selectedLanguage: String = "en"
	private let logger = Logger(subsystem: "com.Lumio.pet", category: "Settings")
	
	var body: some View {
		List {
			if let stats = appModel.userStats {
				
				Section("Notifications") {
					// TODO: add more detailed notification categories
					Toggle("All", isOn: Binding(
						get: { stats.notificationsEnabled },
						set: { newValue in
							logger.info("[Settings] Notifications toggled to: \(newValue, privacy: .public)")
							stats.notificationsEnabled = newValue
							if newValue { appModel.requestNotifications() }
									else { appModel.persistState() }
							}
				))
				}
				
				Section("Language") {
					Picker("Language", selection: $selectedLanguage) {
						Text("English").tag("en")
						Text("中文").tag("zh")
					}
					// TODO: complete language switch and support to 中文（zh）
				}
				
				Section("Task Generation") {
					VStack(alignment: .leading, spacing: 12) {
						Toggle(
							"Random Time",
							isOn: Binding(
								get: { stats.randomizeTaskTime },
								set: { newValue in
									logger.info("[Settings] Random Task Generation Time toggled to: \(newValue, privacy: .public)")
									stats.randomizeTaskTime = newValue
									appModel.persistState()
									appModel.applyTaskGenerationSettingsChanged()
								}
							)
						)
						Text("Applicable from next timeslot.")
							.appFont(FontTheme.footnote)
							.foregroundColor(Color.gray.opacity(0.8))
						
					}
				}
				
				// TODO: add privacy note
			}
		}
		.onChange(of: selectedLanguage) { newValue in
			logger.info("[Settings] Language changed to: \(newValue, privacy: .public)")
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

