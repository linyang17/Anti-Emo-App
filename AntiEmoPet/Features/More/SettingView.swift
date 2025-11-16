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
					.onChange(of: selectedLanguage) { newLang in
						appModel.setLanguage(newLang)
					}
					// TODO: complete language switch and support to 中文（zh）
					// TODO: add privacy
				}
			}
		}
		.navigationTitle("Settings")
		.alert("通知权限受限", isPresented: Binding(
			get: { appModel.shouldShowNotificationSettingsPrompt },
			set: { appModel.shouldShowNotificationSettingsPrompt = $0 }
		)) {
			Button("前往设置") { appModel.openNotificationSettings() }
			Button("稍后再说", role: .cancel) { }
		} message: {
			Text("请在系统设置中允许 Lumio 发送通知。")
		}
	}
}
