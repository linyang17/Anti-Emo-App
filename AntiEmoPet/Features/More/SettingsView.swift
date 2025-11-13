import SwiftUI

struct SettingsView: View {
	@EnvironmentObject private var appModel: AppViewModel

	var body: some View {
		List {
			Section(header: Text("User")) {
				NavigationLink(destination: ProfileView().environmentObject(appModel)) {
					Label("Profile", systemImage: "person")
				}
			}
		}
		.navigationTitle("Settings")
		.listStyle(.insetGrouped)
	}
}
