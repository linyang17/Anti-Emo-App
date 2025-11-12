import SwiftUI

struct MoreView: View {
	@EnvironmentObject private var appModel: AppViewModel

	var body: some View {
		List {
			Section(header: Text("聊天")) {
				NavigationLink(destination: ChatView().environmentObject(appModel)) {
					Label("Chat", systemImage: "message")
				}
			}

			Section(header: Text("统计")) {
				NavigationLink(destination: StatisticsView().environmentObject(appModel)) {
					Label("Statistics", systemImage: "chart.line.uptrend.xyaxis")
				}

				NavigationLink(destination: InsightsView().environmentObject(appModel)) {
					Label("Insights", systemImage: "lightbulb.max")
				}
			}
		}
		.navigationTitle("More")
		.listStyle(.insetGrouped)
	}
}
