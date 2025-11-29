import SwiftUI

struct MoreView: View {
	@EnvironmentObject private var appModel: AppViewModel
	let energyHistory: [EnergyHistoryEntry]

	var body: some View {
		List {
			Section(header: Text("Chat")) {
				NavigationLink(destination: ChatView().environmentObject(appModel)) {
					Label("Chat", systemImage: "message")
				}
			}

			Section(header: Text("Statistics")) {
				NavigationLink(
					destination: StatisticsView()
						.environmentObject(appModel)
				) {
					Label("Statistics", systemImage: "chart.line.uptrend.xyaxis")
				}

				NavigationLink(destination: InsightsView().environmentObject(appModel)) {
					Label("Insights", systemImage: "lightbulb.max")
				}
			}
			Section(header: Text("User")) {
				NavigationLink(destination: ProfileView().environmentObject(appModel)) {
					Label("Profile", systemImage: "person")
				}
			}
			Section(header: Text("Settings")) {
				NavigationLink(destination: SettingView().environmentObject(appModel)) {
					Label("Settings", systemImage: "gearshape")
				}
				NavigationLink(destination: FeedbackView()) {
					Label("Feedback", systemImage: "envelope")
				}
			}
				
				// TODO: add more relevant settings
			
		}
		.navigationTitle("More")
		.listStyle(.insetGrouped)
	}
}
